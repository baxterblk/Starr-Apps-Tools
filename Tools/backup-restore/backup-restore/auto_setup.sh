#!/bin/bash

# Setup log file for this script
SETUP_LOG="/var/log/arr_backup_setup.log"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "$(date): Starting ARR applications backup setup script" >> "$SETUP_LOG"

# Function to prompt for yes/no confirmation
confirm() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) echo "$(date): User confirmed: $1" >> "$SETUP_LOG"; return 0;;
            [Nn]* ) echo "$(date): User denied: $1" >> "$SETUP_LOG"; return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to get a valid path
get_valid_path() {
    local prompt="$1"
    local path
    while true; do
        read -p "$prompt" path
        if [ -d "$path" ]; then
            echo "$(date): Valid path entered: $path" >> "$SETUP_LOG"
            echo "$path"
            return 0
        else
            echo "Invalid path. Please try again."
            echo "$(date): Invalid path entered: $path" >> "$SETUP_LOG"
        fi
    done
}

# Array of available apps
apps=("Sonarr" "Radarr" "Lidarr" "Prowlarr" "Readarr" "Bazarr")

# Initialize arrays to store user selections
selected_apps=()
db_users=()
db_passwords=()
config_paths=()

echo "Welcome to the ARR applications backup setup script!"
echo "$(date): Script execution started" >> "$SETUP_LOG"

# 1. Select apps to back up
echo "Please select which apps you want to back up:"
echo "$(date): Prompting user to select apps for backup" >> "$SETUP_LOG"
for i in "${!apps[@]}"; do
    if confirm "Do you want to back up ${apps[$i]}?"; then
        selected_apps+=("${apps[$i]}")
        echo "$(date): User selected ${apps[$i]} for backup" >> "$SETUP_LOG"
    else
        echo "$(date): User did not select ${apps[$i]} for backup" >> "$SETUP_LOG"
    fi
done

# 2 & 3. Confirm database details and config.xml location for each selected app
echo "$(date): Prompting for database details and config.xml locations" >> "$SETUP_LOG"
for app in "${selected_apps[@]}"; do
    read -p "Enter database username for $app: " db_user
    db_users+=("$db_user")
    echo "$(date): Database username entered for $app" >> "$SETUP_LOG"
    read -s -p "Enter database password for $app: " db_password
    echo
    db_passwords+=("$db_password")
    echo "$(date): Database password entered for $app" >> "$SETUP_LOG"
    config_path=$(get_valid_path "Enter the path to config.xml for $app: ")
    config_paths+=("$config_path")
    echo "$(date): Config path entered for $app: $config_path" >> "$SETUP_LOG"
done

# 4. Confirm zip file save location
echo "$(date): Prompting for backup save location" >> "$SETUP_LOG"
backup_dir=$(get_valid_path "Enter the directory where you want to save the backup zip files: ")
echo "$(date): Backup directory set to: $backup_dir" >> "$SETUP_LOG"

# 5. Confirm all steps
echo "Please confirm your selections:"
echo "Selected apps: ${selected_apps[*]}"
echo "Backup directory: $backup_dir"
echo "$(date): Asking user to confirm selections" >> "$SETUP_LOG"
if ! confirm "Is this correct?"; then
    echo "Setup cancelled. Please run the script again."
    echo "$(date): User cancelled setup" >> "$SETUP_LOG"
    exit 1
fi

# 6. Save location for the backup script
echo "$(date): Prompting for backup script save location" >> "$SETUP_LOG"
script_dir=$(get_valid_path "Enter the directory where you want to save the backup script: ")
read -p "Enter the name for your backup script (default: custom_backup.sh): " script_name
script_name=${script_name:-custom_backup.sh}
script_path="$script_dir/$script_name"
echo "$(date): Backup script will be saved as: $script_path" >> "$SETUP_LOG"

# Generate the backup script
echo "$(date): Generating backup script" >> "$SETUP_LOG"
cat << EOF > "$script_path"
#!/bin/bash

# Custom backup script for ARR applications
BACKUP_LOG="/var/log/arr_backup.log"
echo "\$(date): Starting ARR applications backup" >> "\$BACKUP_LOG"

EOF

for i in "${!selected_apps[@]}"; do
    app="${selected_apps[$i]}"
    db_user="${db_users[$i]}"
    db_password="${db_passwords[$i]}"
    config_path="${config_paths[$i]}"
    
    cat << EOF >> "$script_path"
# Backup $app
echo "Backing up $app..."
echo "\$(date): Starting backup of $app" >> "\$BACKUP_LOG"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$backup_dir/${app,,}_backup_\$TIMESTAMP.zip"
EOF

    case $app in
        Sonarr|Radarr|Lidarr)
            cat << EOF >> "$script_path"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-main > "/tmp/${app,,}_main_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} main database dumped" >> "\$BACKUP_LOG"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-log > "/tmp/${app,,}_log_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} log database dumped" >> "\$BACKUP_LOG"
zip -j "\$BACKUP_FILE" "/tmp/${app,,}_main_\$TIMESTAMP.sql" "/tmp/${app,,}_log_\$TIMESTAMP.sql" "$config_path" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} backup files zipped" >> "\$BACKUP_LOG"
rm "/tmp/${app,,}_main_\$TIMESTAMP.sql" "/tmp/${app,,}_log_\$TIMESTAMP.sql"
echo "\$(date): ${app} temporary files cleaned up" >> "\$BACKUP_LOG"
EOF
            ;;
        Readarr)
            cat << EOF >> "$script_path"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-main > "/tmp/${app,,}_main_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} main database dumped" >> "\$BACKUP_LOG"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-log > "/tmp/${app,,}_log_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} log database dumped" >> "\$BACKUP_LOG"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-cache > "/tmp/${app,,}_cache_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} cache database dumped" >> "\$BACKUP_LOG"
zip -j "\$BACKUP_FILE" "/tmp/${app,,}_main_\$TIMESTAMP.sql" "/tmp/${app,,}_log_\$TIMESTAMP.sql" "/tmp/${app,,}_cache_\$TIMESTAMP.sql" "$config_path" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} backup files zipped" >> "\$BACKUP_LOG"
rm "/tmp/${app,,}_main_\$TIMESTAMP.sql" "/tmp/${app,,}_log_\$TIMESTAMP.sql" "/tmp/${app,,}_cache_\$TIMESTAMP.sql"
echo "\$(date): ${app} temporary files cleaned up" >> "\$BACKUP_LOG"
EOF
            ;;
        Prowlarr)
            cat << EOF >> "$script_path"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w ${app,,}-main > "/tmp/${app,,}_main_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} main database dumped" >> "\$BACKUP_LOG"
zip -j "\$BACKUP_FILE" "/tmp/${app,,}_main_\$TIMESTAMP.sql" "$config_path" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} backup files zipped" >> "\$BACKUP_LOG"
rm "/tmp/${app,,}_main_\$TIMESTAMP.sql"
echo "\$(date): ${app} temporary files cleaned up" >> "\$BACKUP_LOG"
EOF
            ;;
        Bazarr)
            cat << EOF >> "$script_path"
docker exec ${app,,}-postgres pg_dump -U "$db_user" -w bazarr > "/tmp/${app,,}_\$TIMESTAMP.sql" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} database dumped" >> "\$BACKUP_LOG"
zip -j "\$BACKUP_FILE" "/tmp/${app,,}_\$TIMESTAMP.sql" "$config_path" 2>> "\$BACKUP_LOG"
echo "\$(date): ${app} backup files zipped" >> "\$BACKUP_LOG"
rm "/tmp/${app,,}_\$TIMESTAMP.sql"
echo "\$(date): ${app} temporary files cleaned up" >> "\$BACKUP_LOG"
EOF
            ;;
    esac

    cat << EOF >> "$script_path"
echo "$app backup completed: \$BACKUP_FILE"
echo "\$(date): $app backup completed" >> "\$BACKUP_LOG"

EOF
done

cat << EOF >> "$script_path"
echo "\$(date): All backups completed" >> "\$BACKUP_LOG"
EOF

chmod +x "$script_path"

echo "Backup script has been created at: $script_path"
echo "$(date): Backup script created: $script_path" >> "$SETUP_LOG"

# 7. Set up cron job
if confirm "Do you want to set up a cron job for automatic backups?"; then
    read -p "Enter the time for the cron job (default: 3:00 AM, format: HH:MM): " cron_time
    cron_time=${cron_time:-03:00}
    
    # Convert time to cron format
    IFS=':' read -ra TIME <<< "$cron_time"
    HOUR=${TIME[0]}
    MINUTE=${TIME[1]}
    
    (crontab -l 2>/dev/null; echo "$MINUTE $HOUR * * * $script_path") | crontab -
    
    echo "Cron job has been set up to run daily at $cron_time"
    echo "$(date): Cron job set up to run daily at $cron_time" >> "$SETUP_LOG"
else
    echo "No cron job has been set up. You can manually run the backup script as needed."
    echo "$(date): User chose not to set up a cron job" >> "$SETUP_LOG"
fi

echo "Setup complete! Your custom backup script is ready to use."
echo "$(date): Setup completed successfully" >> "$SETUP_LOG"