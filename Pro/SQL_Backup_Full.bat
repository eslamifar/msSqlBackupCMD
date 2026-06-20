@echo off
setlocal EnableDelayedExpansion

REM =====================================================================
REM  SQL Server Full Backup Script
REM  - Full backup databases to local temp folder
REM  - Verify backup integrity with RESTORE VERIFYONLY
REM  - Compress each .bak with RAR (best compression)
REM  - Move .rar files to network destination
REM  - Delete local .bak and .rar files after successful transfer
REM  - Keep only newest MAX_BACKUPS_TO_KEEP backups per database
REM =====================================================================

REM ----------------------- CONFIGURATION --------------------------------

REM =====================================================================
REM  Backup Configuration File
REM  - This file is loaded by SQL_Backup_Full.bat at runtime
REM  - Keep this file secure (contains SQL credentials)
REM  - Format: set VARIABLE=VALUE  (standard batch syntax)
REM =====================================================================

REM SQL Server connection settings
set SQL_SERVER=localhost
set SQL_USER=sa
set SQL_PASS=myPassword

REM Local backup folder (temp location for .bak files before compression)
set BACKUP_DIR=D:\Temp

REM Temp working folder for RAR compression
set RAR_TEMP_DIR=D:\Temp

REM Network destination folder
set NETWORK_DIR=\\192.168.100.5\web-database\sql

REM Path to rar.exe
set RAR_EXE="C:\Program Files\WinRAR\rar.exe"

REM ----------------------- ARGUMENT VALIDATION -------------------------
REM Both arguments are required when not running in __LOGGED__ mode.
REM Usage: SQL_Backup_Full.bat "DB1 DB2 DB3" 5
 
if /I "%~1"=="__LOGGED__" goto :SKIP_VALIDATION
 
if "%~1"=="" (
    echo [ERROR] Missing argument 1: database list.
    echo Usage: SQL_Backup_Full.bat "DB1 DB2 DB3" 5
    pause
    goto :EOF
)
 
if "%~2"=="" (
    echo [ERROR] Missing argument 2: max backups to keep.
    echo Usage: SQL_Backup_Full.bat "DB1 DB2 DB3" 5
    pause
    goto :EOF
)
 
:SKIP_VALIDATION
 
REM List of databases to back up (space separated, passed as argument 1)
set DATABASES=%~1
 
REM Maximum number of Full backups to keep per database in NETWORK_DIR
set /A MAX_BACKUPS_TO_KEEP=%~2



REM ----------------------- TIMESTAMP & LOG ------------------------------

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set LOG_TIMESTAMP=%%i
set LOGFILE=%~dp0SQL_Backup_Full_Log_%LOG_TIMESTAMP%.txt

REM ----------------------- LOGGING WRAPPER --------------------------------
REM On first run (no args), relaunch self with output redirected to log file.
REM On second run (__LOGGED__), do the actual work.
if /I "%~1"=="__LOGGED__" goto :MAIN

call "%~f0" __LOGGED__ %LOG_TIMESTAMP% > "%LOGFILE%" 2>&1
echo.
echo ============== Backup run finished ==============
echo Full log saved to: %LOGFILE%
echo.

goto :EOF

REM =====================================================================
REM  MAIN
REM =====================================================================
:MAIN

set TIMESTAMP=%~2
if "%TIMESTAMP%"=="" set TIMESTAMP=%LOG_TIMESTAMP%

if not exist "%BACKUP_DIR%"     mkdir "%BACKUP_DIR%"
if not exist "%RAR_TEMP_DIR%"   mkdir "%RAR_TEMP_DIR%"

if not exist "%NETWORK_DIR%" (
    echo [ERROR] Network path "%NETWORK_DIR%" is not accessible. Aborting.
    goto :EOF
)

echo =========================================================
echo  SQL Full Backup started at %DATE% %TIME%
echo =========================================================

for %%D in (%DATABASES%) do (
    call :ProcessDB "%%D"
)

echo.
echo =========================================================
echo  SQL Full Backup finished at %DATE% %TIME%
echo =========================================================

goto :EOF

REM =====================================================================
REM  SUBROUTINE: ProcessDB
REM  %1 = database name
REM =====================================================================
:ProcessDB
set DBNAME=%~1
set BAKFILE=%BACKUP_DIR%\%DBNAME%_FULL_%TIMESTAMP%.bak
set RARFILE=%BACKUP_DIR%\%DBNAME%_FULL_%TIMESTAMP%.rar

echo.
echo ---------------------------------------------------------
echo Full backup of database: %DBNAME%
echo Target file            : %BAKFILE%
echo ---------------------------------------------------------

sqlcmd -S %SQL_SERVER% -U %SQL_USER% -P %SQL_PASS% -Q "BACKUP DATABASE [%DBNAME%] TO DISK = N'%BAKFILE%' WITH NOFORMAT, INIT, NAME = N'%DBNAME%-Full Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

if errorlevel 1 (
    echo [ERROR] Backup FAILED for database %DBNAME%. Skipping compression/transfer.
    goto :EOF
)

if not exist "%BAKFILE%" (
    echo [ERROR] Backup file not found: %BAKFILE%
    goto :EOF
)

echo Verifying backup integrity: %BAKFILE% ...
sqlcmd -S %SQL_SERVER% -U %SQL_USER% -P %SQL_PASS% -Q "RESTORE VERIFYONLY FROM DISK = N'%BAKFILE%'"

if errorlevel 1 (
    echo [ERROR] Backup verification FAILED for %DBNAME%. File may be corrupt. Skipping.
    del /F /Q "%BAKFILE%" 2>nul
    goto :EOF
)

echo Backup verification passed for %DBNAME%.

echo Compressing %BAKFILE% ...
%RAR_EXE% a -m5 -ep1 -w"%RAR_TEMP_DIR%" "%RARFILE%" "%BAKFILE%"

if errorlevel 1 (
    echo [ERROR] RAR compression FAILED for %DBNAME%. Keeping .bak file, skipping transfer.
    goto :EOF
)

if not exist "%RARFILE%" (
    echo [ERROR] RAR file not found after compression: %RARFILE%
    goto :EOF
)

echo Moving %RARFILE% to %NETWORK_DIR% ...
move /Y "%RARFILE%" "%NETWORK_DIR%\" >nul

if errorlevel 1 (
    echo [ERROR] Failed to move %RARFILE% to network path. Keeping local files.
    goto :EOF
)

echo Transfer successful. Cleaning up local files for %DBNAME% ...
del /F /Q "%BAKFILE%" 2>nul
del /F /Q "%RARFILE%" 2>nul

call :CleanupOldBackups "%DBNAME%"

echo Database %DBNAME% completed successfully.
goto :EOF

REM =====================================================================
REM  SUBROUTINE: CleanupOldBackups
REM  Keeps only newest MAX_BACKUPS_TO_KEEP _FULL_ .rar files per database.
REM  Does NOT touch _DIFF_ files.
REM  %1 = database name
REM =====================================================================
:CleanupOldBackups
set CLEAN_DBNAME=%~1

echo Checking backup retention for %CLEAN_DBNAME% in %NETWORK_DIR% (keep newest %MAX_BACKUPS_TO_KEEP%) ...

set TMPLIST=%TEMP%\bak_list_%CLEAN_DBNAME%.tmp
dir /B /O-D "%NETWORK_DIR%\%CLEAN_DBNAME%_FULL_*.rar" 2>nul > "%TMPLIST%"

powershell -NoProfile -Command ^
    "$f='%TMPLIST%'; $net='%NETWORK_DIR%'; $keep=%MAX_BACKUPS_TO_KEEP%; $db='%CLEAN_DBNAME%';" ^
    "if (-not (Test-Path $f)) { Write-Host 'No backups found for' $db; exit };" ^
    "$files = @(Get-Content $f | Where-Object { $_ -ne '' });" ^
    "if ($files.Count -le $keep) { Write-Host 'No old backups to delete for' $db '[' $files.Count 'file(s) found, limit is' $keep ']'; exit };" ^
    "$del = $files | Select-Object -Skip $keep;" ^
    "foreach ($x in $del) { Write-Host 'Deleting old backup:' $x; Remove-Item (Join-Path $net $x) -Force -ErrorAction SilentlyContinue };" ^
    "Write-Host 'Deleted' ($files.Count - $keep) 'old backup(s) for' $db"

del /F /Q "%TMPLIST%" 2>nul
goto :EOF
