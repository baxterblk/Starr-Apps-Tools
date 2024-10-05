# ARR Applications Backup Script

## Repository

The official repository for this script is located at:
https://git.blakbox.vip/baxterblk/arr-postgres-backup-script

## Overview

This project provides bash scripts to automate the backup process for all ARR applications:
- Sonarr
- Radarr
- Lidarr
- Readarr
- Prowlarr
- Bazarr

It creates backups of each application's databases and configuration files, storing them in timestamped zip archives.

## Getting Started

To use these scripts, you first need to clone the repository to your local machine:

1. Open a terminal on your system.
2. Navigate to the directory where you want to clone the repository.
3. Run the following command:

   ```
   git clone https://git.blakbox.vip/baxterblk/arr-postgres-backup-script.git
   ```

4. Once the cloning is complete, navigate into the newly created directory:

   ```
   cd arr-postgres-backup-script
   ```

## Repository Structure

The repository contains two main types of scripts:

1. Individual backup scripts for each application:
   - Located in the `individual` directory
   - Format: `<app_name>-backup.sh`
   - Replace <app_name> with sonarr, radarr, lidarr, readarr, prowlarr, or bazarr

2. Combined scheduled backup script:
   - Located in the `scheduled` directory
   - Filename: `combined_backup.sh`

## Requirements

- Bash shell
- Docker (with containers for each ARR application running)
- PostgreSQL (running in Docker containers for each application)
- zip utility

## Configuration

The scripts assume the following directory structure:
- Docker containers: `/home/user/docker/[app_name]/`
- Backup destination: `/home/user/backups/[app_name]/`

Ensure you have write permissions to these directories.

## Usage

### Individual Backup Scripts

1. Navigate to the `individual` directory in the cloned repository.
2. Make the desired script executable:
   ```
   chmod +x <app_name>-backup.sh
   ```
3. Run the script:
   ```
   ./<app_name>-backup.sh
   ```

### Combined Scheduled Backup

1. Navigate to the `scheduled` directory in the cloned repository.
2. Make the combined script executable:
   ```
   chmod +x combined_backup.sh
   ```
3. Run the script:
   ```
   ./combined_backup.sh
   ```

To schedule the combined backup, you can use cron. For example, to run the backup daily at 2 AM:

```
0 2 * * * /path/to/combined_backup.sh
```

## What the Scripts Do

For each application, the scripts:
1. Create a backup directory if it doesn't exist.
2. Dump the PostgreSQL databases:
   - For Sonarr, Radarr, Lidarr: main and log databases
   - For Readarr: main, log, and cache databases
   - For Prowlarr: main database
   - For Bazarr: single database
3. Copy the `config.xml` file.
4. Create a zip archive containing the database dumps and config file.
5. Clean up temporary files.

## Backup Location

Backups are stored in `/home/user/backups/[app_name]/` with the naming format:
```
[app_name]_backup_YYYYMMDD_HHMMSS.zip
```

## Error Handling

- The scripts will report any failures during the backup process.
- If any application's backup fails, the combined script will continue with the next application.
- At the end of the process, it will list any applications that failed to backup.

## Customization

You may need to modify the following variables in the scripts to match your setup:
- `BACKUP_DIR`: The base directory for storing backups
- `DOCKER_DIR`: The base directory where your Docker containers are located
- `DB_USER`: The PostgreSQL username (default is "qstick")

## If you have any considerations, please feel free to contribute!