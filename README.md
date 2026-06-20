## ⚙️ Configuration

Open the script and adjust the following variables to match your environment:

```batch
set SQL_SERVER=localhost
set SQL_USER=sa
set SQL_PASS=myPassword
set BACKUP_DIR=D:\Temp
set NETWORK_DIR=\\192.168.100.5\web-database\sql
set RAR_EXE="C:\Program Files\WinRAR\rar.exe"
set DATABASES=databaseName1 databaseName2 databaseName3 databaseName4 databaseName5
set MAX_BACKUPS_TO_KEEP=10
```

### Professional Usage

For professional use, run the following command:

```batch
SQL_Backup_Full.bat "Database1 Database2 Database3" [NumberOfBackupsToKeep]
```

Example:

```batch
SQL_Backup_Full.bat "databaseName1 databaseName2 databaseName3 databaseName4 databaseName5" 10
```
