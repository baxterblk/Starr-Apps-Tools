#!/bin/bash

# Prowlarr Restore Script

# Configuration
APP_NAME="prowlarr"
POSTGRES_CONTAINER="${APP_NAME}-postgres"
DOCKER_DIR="/home/user/docker/${APP_NAME}"
BACKUP_DIR="/home/user/backups/${APP_NAME}"
DB_USER="qstick"
DB_MAIN="prowlarr-main"
DB_LOG="prowlarr-log"

# Function to restore Prowlarr
restore_prowlarr() {
    local BACKUP_FILE=$1
    local TEMP_DIR="/tmp/prowlarr_restore"

    echo "Starting Prowlarr restore process..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Unzip backup file
    if ! unzip "$BACKUP_FILE" -d "$TEMP_DIR"; then
        echo "Failed to unzip backup file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Stop Prowlarr container
    echo "Stopping Prowlarr container..."
    docker stop prowlarr

    # Restore main database
    echo "Restoring main database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_MAIN" < "${TEMP_DIR}/prowlarr_main_db_"*.sql; then
        echo "Failed to restore main database"
        docker start prowlarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore log database
    echo "Restoring log database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_LOG" < "${TEMP_DIR}/prowlarr_log_db_"*.sql; then
        echo "Failed to restore log database"
        docker start prowlarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore config file
    echo "Restoring config file..."
    if ! cp "${TEMP_DIR}/config_"*.xml "${DOCKER_DIR}/config/config.xml"; then
        echo "Failed to restore config file"
        docker start prowlarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Start Prowlarr container
    echo "Starting Prowlarr container..."
    docker start prowlarr

    # Clean up
    rm -rf "$TEMP_DIR"

    echo "Prowlarr restore completed successfully!"
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

    if restore_prowlarr "$BACKUP_FILE"; then
        echo "Prowlarr restore process completed successfully"
    else
        echo "Prowlarr restore process failed"
        exit 1
    fi
}

# Run the main function
main "$@"