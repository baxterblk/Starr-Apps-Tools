# Combined ARR Applications Backup Script

This folder contains the `combined_backup.sh` script, which performs backups for all ARR applications in one go.

## Getting Started

To use this script, first clone the repository:

1. Open a terminal on your system.
2. Navigate to the directory where you want to clone the repository.
3. Run the following command:

   ```
   git clone https://git.blakbox.vip/baxterblk/arr-postgres-backup-script.git
   ```

4. Navigate into the cloned repository and then into the "scheduled" folder:

   ```
   cd arr-postgres-backup-script/scheduled
   ```

## Usage

1. Make the script executable:
   ```
   chmod +x combined_backup.sh
   ```

2. Run the script:
   ```
   ./combined_backup.sh
   ```

## Setting Up Cron Job

To schedule regular combined backups, you can set up a cron job. Here's how:

1. Open the crontab file:
   ```
   crontab -e
   ```

2. Add a line to schedule the combined backup. For example, to run daily at 2 AM:
   ```
   0 2 * * * /path/to/scheduled/combined_backup.sh
   ```

3. Save and exit the crontab file.

Adjust the timing as needed for your specific requirements.

## What the Script Does

The `combined_backup.sh` script:
1. Iterates through all ARR applications (Sonarr, Radarr, Lidarr, Readarr, Prowlarr, Bazarr).
2. For each application, it:
   - Creates a backup directory if it doesn't exist.
   - Dumps the PostgreSQL databases:
     - For Sonarr, Radarr, Lidarr: main and log databases
     - For Readarr: main, log, and cache databases
     - For Prowlarr: main database
     - For Bazarr: single database
   - Copies the `config.xml` file.
   - Creates a zip archive containing the database dumps and config file.
   - Cleans up temporary files.
3. Reports any failures during the backup process.

## Customization

You can customize the script by modifying the following variables at the top of the file:
- `BACKUP_DIR`: The base directory for storing backups
- `DOCKER_DIR`: The base directory where your Docker containers are located
- `DB_USER`: The PostgreSQL username (default is "qstick")

Ensure you have the necessary permissions to read from the Docker directories and write to the backup directories.

## Error Handling

If any application's backup fails, the script will continue with the next application. At the end of the process, it will list any applications that failed to backup.

## Backup Location

Backups are stored in `$BACKUP_DIR/[app_name]/` with the naming format:
```
[app_name]_backup_YYYYMMDD_HHMMSS.zip
```

## Security Note

This script contains sensitive information like database usernames. Ensure it's stored securely and not accessible to unauthorized users.

## Disclaimer

Always verify your backups and test the restoration process. This script is provided as-is, without any guarantees. Use at your own risk.