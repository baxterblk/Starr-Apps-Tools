#!/bin/bash

# Readarr Restore Script

# Configuration
APP_NAME="readarr"
POSTGRES_CONTAINER="${APP_NAME}-postgres"
DOCKER_DIR="/home/user/docker/${APP_NAME}"
BACKUP_DIR="/home/user/backups/${APP_NAME}"
DB_USER="qstick"
DB_MAIN="readarr-main"
DB_LOG="readarr-log"

# Function to restore Readarr
restore_readarr() {
    local BACKUP_FILE=$1
    local TEMP_DIR="/tmp/readarr_restore"

    echo "Starting Readarr restore process..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Unzip backup file
    if ! unzip "$BACKUP_FILE" -d "$TEMP_DIR"; then
        echo "Failed to unzip backup file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Stop Readarr container
    echo "Stopping Readarr container..."
    docker stop readarr

    # Restore main database
    echo "Restoring main database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_MAIN" < "${TEMP_DIR}/readarr_main_db_"*.sql; then
        echo "Failed to restore main database"
        docker start readarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore log database
    echo "Restoring log database..."
    if ! docker exec -i $POSTGRES_CONTAINER psql -U "$DB_USER" -d "$DB_LOG" < "${TEMP_DIR}/readarr_log_db_"*.sql; then
        echo "Failed to restore log database"
        docker start readarr
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Restore config file
    echo "Restoring config file..."
    if ! cp "${TEMP_DIR}/config_"*.xml "${DOCKER_DIR}/config/config.xml"; then