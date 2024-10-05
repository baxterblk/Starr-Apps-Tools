#!/bin/bash

# Lidarr Restore Script

# Configuration
APP_NAME="lidarr"
POSTGRES_CONTAINER="${APP_NAME}-postgres"
DOCKER_DIR="/home/user/docker/${APP_NAME}"
BACKUP_DIR="/home/user/backups/${APP_NAME}"
DB_USER="qstick"
DB_MAIN="lidarr-main"
DB_LOG="lidarr-log"

# Function to restore Lidarr
restore_lidarr() {
    local BACKUP_FILE=$1
    local TEMP_DIR="/tmp/lidarr_restore"

    echo "Starting Lidarr restore process..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Unzip backup file
    if ! unzip "$BACKUP_FILE" -d "$TEMP_DIR"; then
        echo "Failed to unzip backup file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Stop Lidarr container
    echo "Stopping Lidarr container..."
    docker stop lidarr

    # Restore main database
    echo "Restoring main database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_MAIN" < "${TEMP_DIR}/lidarr_main_db_"*.sql; then
        echo "Failed to restore main database"
        docker start lidarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore log database
    echo "Restoring log database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_LOG" < "${TEMP_DIR}/lidarr_log_db_"*.sql; then
        echo "Failed to restore log database"
        docker start lidarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore config file
    echo "Restoring config file..."
    if ! cp "${TEMP_DIR}/config_"*.xml "${DOCKER_DIR}/config/config.xml"; then
        echo "Failed to restore config file"
        docker start lidarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Start Lidarr container
    echo "Starting Lidarr container..."
    docker start lidarr

    # Clean up
    rm -rf "$TEMP_DIR"

    echo "Lidarr restore completed successfully!"
    return 0
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <path_to_backup_file>"
        exit 1
    fi

    BACKUP_FILE=$1

    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    if restore_lidarr "$BACKUP_FILE"; then
        echo "Lidarr restore process completed successfully"
    else
        echo "Lidarr restore process failed"
        exit 1
    fi
}

# Run the main function
main "$@"