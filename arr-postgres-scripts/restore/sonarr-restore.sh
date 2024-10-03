#!/bin/bash

# Sonarr Restore Script

# Configuration
APP_NAME="sonarr"
POSTGRES_CONTAINER="${APP_NAME}-postgres"
DOCKER_DIR="/home/user/docker/${APP_NAME}"
BACKUP_DIR="/home/user/backups/${APP_NAME}"
DB_USER="qstick"
DB_MAIN="sonarr-main"
DB_LOG="sonarr-log"

# Function to restore Sonarr
restore_sonarr() {
    local BACKUP_FILE=$1
    local TEMP_DIR="/tmp/sonarr_restore"

    echo "Starting Sonarr restore process..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Unzip backup file
    if ! unzip "$BACKUP_FILE" -d "$TEMP_DIR"; then
        echo "Failed to unzip backup file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Stop Sonarr container
    echo "Stopping Sonarr container..."
    docker stop sonarr

    # Restore main database
    echo "Restoring main database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_MAIN" < "${TEMP_DIR}/sonarr_main_db_"*.sql; then
        echo "Failed to restore main database"
        docker start sonarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore log database
    echo "Restoring log database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_LOG" < "${TEMP_DIR}/sonarr_log_db_"*.sql; then
        echo "Failed to restore log database"
        docker start sonarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore config file
    echo "Restoring config file..."
    if ! cp "${TEMP_DIR}/config_"*.xml "${DOCKER_DIR}/config/config.xml"; then
        echo "Failed to restore config file"
        docker start sonarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Start Sonarr container
    echo "Starting Sonarr container..."
    docker start sonarr

    # Clean up
    rm -rf "$TEMP_DIR"

    echo "Sonarr restore completed successfully!"
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

    if restore_sonarr "$BACKUP_FILE"; then
        echo "Sonarr restore process completed successfully"
    else
        echo "Sonarr restore process failed"
        exit 1
    fi
}

# Run the main function
main "$@"