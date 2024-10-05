#!/bin/bash

# Function to perform backup for Sonarr
backup_sonarr() {
    local APP_NAME="sonarr"
    local POSTGRES_CONTAINER="${APP_NAME}-postgres"
    local BACKUP_DIR="/home/user/backups/${APP_NAME}"
    local DOCKER_DIR="/home/user/docker/${APP_NAME}"
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_FILE="${APP_NAME}_backup_${TIMESTAMP}.zip"
    local DB_USER="qstick"
    local DB_MAIN="${APP_NAME}-main"
    local DB_LOG="${APP_NAME}-log"

    echo "Starting backup for ${APP_NAME}..."

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory for ${APP_NAME}"; exit 1; }

    # Perform Postgres dump for main database
    if ! docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "$DB_MAIN" > "${BACKUP_DIR}/${APP_NAME}_main_db_${TIMESTAMP}.sql"; then
        echo "Failed to backup main database for ${APP_NAME}"
        exit 1
    fi

    # Perform Postgres dump for log database
    if ! docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "$DB_LOG" > "${BACKUP_DIR}/${APP_NAME}_log_db_${TIMESTAMP}.sql"; then
        echo "Failed to backup log database for ${APP_NAME}"
        exit 1
    fi

    # Copy config.xml
    if ! cp "${DOCKER_DIR}/config/config.xml" "${BACKUP_DIR}/config_${TIMESTAMP}.xml"; then
        echo "Failed to copy config.xml for ${APP_NAME}"
        exit 1
    fi

    # Create zip file
    cd "$BACKUP_DIR" || { echo "Failed to change directory to ${BACKUP_DIR}"; exit 1; }
    if ! zip "$BACKUP_FILE" "${APP_NAME}_main_db_${TIMESTAMP}.sql" "${APP_NAME}_log_db_${TIMESTAMP}.sql" "config_${TIMESTAMP}.xml"; then
        echo "Failed to create zip file for ${APP_NAME}"
        exit 1
    fi

    # Clean up temporary files
    rm "${APP_NAME}_main_db_${TIMESTAMP}.sql" "${APP_NAME}_log_db_${TIMESTAMP}.sql" "config_${TIMESTAMP}.xml"

    echo "${APP_NAME} backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"
}

# Run the backup function
backup_sonarr