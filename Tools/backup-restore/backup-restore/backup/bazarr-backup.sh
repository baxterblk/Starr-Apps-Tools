#!/bin/bash

# Function to perform backup for Bazarr
backup_bazarr() {
    local APP_NAME="bazarr"
    local POSTGRES_CONTAINER="${APP_NAME}-postgres"
    local BACKUP_DIR="/home/user/backups/${APP_NAME}"
    local DOCKER_DIR="/home/user/docker/${APP_NAME}"
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_FILE="${APP_NAME}_backup_${TIMESTAMP}.zip"
    local DB_USER="qstick"
    local DB_NAME="bazarr"

    echo "Starting backup for ${APP_NAME}..."

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory for ${APP_NAME}"; exit 1; }

    # Perform Postgres dump for the bazarr database
    if ! docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "$DB_NAME" > "${BACKUP_DIR}/${APP_NAME}_db_${TIMESTAMP}.sql"; then
        echo "Failed to backup database for ${APP_NAME}"
        exit 1
    fi

    # Copy config.xml
    if ! cp "${DOCKER_DIR}/config/config.xml" "${BACKUP_DIR}/config_${TIMESTAMP}.xml"; then
        echo "Failed to copy config.xml for ${APP_NAME}"
        exit 1
    fi

    # Create zip file
    cd "$BACKUP_DIR" || { echo "Failed to change directory to ${BACKUP_DIR}"; exit 1; }
    if ! zip "$BACKUP_FILE" "${APP_NAME}_db_${TIMESTAMP}.sql" "config_${TIMESTAMP}.xml"; then
        echo "Failed to create zip file for ${APP_NAME}"
        exit 1
    fi

    # Clean up temporary files
    rm "${APP_NAME}_db_${TIMESTAMP}.sql" "config_${TIMESTAMP}.xml"

    echo "${APP_NAME} backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"
}

# Run the backup function
backup_bazarr