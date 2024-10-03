# Individual ARR Application Backup Scripts

This folder contains individual backup scripts for each ARR application.

## Getting Started

To use these scripts, first clone the repository:

1. Open a terminal on your system.
2. Navigate to the directory where you want to clone the repository.
3. Run the following command:

   ```
   git clone https://git.blakbox.vip/baxterblk/arr-postgres-backup-script.git
   ```

4. Navigate into the cloned repository and then into the "individual" folder:

   ```
   cd arr-postgres-backup-script/individual
   ```

## Available Scripts

- `sonarr-backup.sh`
- `radarr-backup.sh`
- `lidarr-backup.sh`
- `readarr-backup.sh`
- `prowlarr-backup.sh`
- `bazarr-backup.sh`

## Usage

1. Make the script executable:
   ```
   chmod +x <app_name>-backup.sh
   ```
2. Run the script:
   ```
   ./<app_name>-backup.sh
   ```

Replace `<app_name>` with the name of the application you want to back up (e.g., sonarr, radarr, etc.).

## Setting Up Cron Jobs

To schedule regular backups, you can set up cron jobs for each script. Here's how:

1. Open the crontab file:
   ```
   crontab -e
   ```

2. Add a line for each application you want to back up regularly. For example:
   ```
   0 1 * * * /path/to/individual/sonarr-backup.sh
   0 2 * * * /path/to/individual/radarr-backup.sh
   0 3 * * * /path/to/individual/lidarr-backup.sh
   0 4 * * * /path/to/individual/readarr-backup.sh
   0 5 * * * /path/to/individual/prowlarr-backup.sh
   0 6 * * * /path/to/individual/bazarr-backup.sh
   ```

   This example runs backups daily, with each application backed up at a different hour to spread the load.

3. Save and exit the crontab file.

Adjust the timing as needed for your specific requirements.

## Customization

Each script can be customized by modifying the following variables at the top of the file:
- `BACKUP_DIR`: The directory where backups will be stored
- `DOCKER_DIR`: The directory where your Docker containers are located
- `DB_USER`: The PostgreSQL username (default is "qstick")

Ensure you have the necessary permissions to read from the Docker directories and write to the backup directories.

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

## Error Handling

Each script will report any failures during the backup process. If a backup fails, check the script output for error messages.

## Security Note

These scripts contain sensitive information like database usernames. Ensure they're stored securely and not accessible to unauthorized users.

## Disclaimer

Always verify your backups and test the restoration process. These scripts are provided as-is, without any guarantees. Use at your own risk.