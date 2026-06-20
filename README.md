# msSqlBackupCMD
Backs up one or more MS SQL databases using Windows CMD, compresses the backup file with RAR, and transfers it to a shared folder.

# MS SQL Full Backup Script with RAR Compression & Network Transfer

This project is a flexible **Windows Batch Script** that automates the backup process for one or multiple Microsoft SQL Server databases. It creates uncompressed native `.bak` files, compresses them using WinRAR (BEST level), transfers them to a network shared folder, rotates old backups, and logs every action with a timestamp.

## 🚀 Motivation

I was always looking for a **simple, free, and unrestricted** backup solution. Many free tools either crashed intermittently or imposed frustrating limitations—such as restricting you to backing up only 2 databases or limiting you to a single job. I also didn't want to rely on VEEAM for this specific use case.

So, I decided to build my own script with the help of AI (Claude). The beauty of this approach is that I can set up multiple scheduled tasks (daily, hourly, weekly) for different groups of databases. Plus, it's completely customizable—I can easily extend it later to support **DIFF** backups, turn it into a Windows service, or even build a web application around it via a REST API.

## ✨ Features

- **Full (FULL) Backup**: Creates a native SQL backup of one or multiple databases.
- **No SQL Compression**: The `.bak` file is created *without* SQL Server's native compression.
- **RAR Compression**: Compresses the backup file using WinRAR with the **BEST** compression level.
- **Network Transfer**: Automatically copies the compressed archive to any network shared folder.
- **Retention Policy**: Keeps only the `N` newest backup archives and automatically deletes older ones (tested and verified).
- **Detailed Logging**: Writes a separate log entry per execution, including the full date and time, into a `.txt` file.
- **Backup Verification**: Includes native SQL `VERIFYONLY` to ensure the backup integrity immediately after creation.

## ⚙️ Configuration

Open the script and adjust the following variables to match your environment for classic:

```batch
set SQL_SERVER=localhost
set SQL_USER=sa
set SQL_PASS=myPassword
set BACKUP_DIR=D:\Temp
set BACKUP_DIR=D:\Temp
set NETWORK_DIR=\\192.168.100.5\web-database\sql
set RAR_EXE="C:\Program Files\WinRAR\rar.exe"
set DATABASES=databaseName1 databaseName2 databaseName3 databaseName4 databaseName5
set MAX_BACKUPS_TO_KEEP=10

For proffestional use below command:

```batch
SQL_Backup_Full.bat "Database1 Database2 Database3" [NumberOfBackupsToKeep]

Example:
```batch
SQL_Backup_Full.bat "databaseName1 databaseName2 databaseName3 databaseName4 databaseName5" 10
