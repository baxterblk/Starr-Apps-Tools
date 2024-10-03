#!/bin/bash

# Function to perform backup for a single application
backup_app() {
    local APP_NAME=$1
    local POSTGRES_CONTAINER="${APP_NAME}-postgres"
    local BACKUP_DIR="/home/user/backups/${APP_NAME}"
    local DOCKER_DIR="/home/user/docker/${APP_NAME}"
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_FILE="${APP_NAME}_backup_${TIMESTAMP}.zip"
    local DB_USER="qstick"

    echo "Starting backup for ${APP_NAME}..."

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory for ${APP_NAME}"; return 1; }

    # Array to store database dump files
    local DB_DUMPS=()

    # Perform Postgres dumps based on the application
    case $APP_NAME in
        sonarr|radarr|lidarr|readarr)
            docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "${APP_NAME}-main" > "${BACKUP_DIR}/${APP_NAME}_main_db_${TIMESTAMP}.sql"
            docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "${APP_NAME}-log" > "${BACKUP_DIR}/${APP_NAME}_log_db_${TIMESTAMP}.sql"
            DB_DUMPS+=("${APP_NAME}_main_db_${TIMESTAMP}.sql" "${APP_NAME}_log_db_${TIMESTAMP}.sql")
            if [ "$APP_NAME" == "readarr" ]; then
                docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "readarr-cache" > "${BACKUP_DIR}/readarr_cache_db_${TIMESTAMP}.sql"
                DB_DUMPS+=("readarr_cache_db_${TIMESTAMP}.sql")
            fi
            ;;
        prowlarr)
            docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "prowlarr-main" > "${BACKUP_DIR}/prowlarr_main_db_${TIMESTAMP}.sql"
            DB_DUMPS+=("prowlarr_main_db_${TIMESTAMP}.sql")
            ;;
        bazarr)
            docker exec $POSTGRES_CONTAINER pg_dump -U "$DB_USER" "bazarr" > "${BACKUP_DIR}/bazarr_db_${TIMESTAMP}.sql"
            DB_DUMPS+=("bazarr_db_${TIMESTAMP}.sql")
            ;;
        *)
            echo "Unknown application: ${APP_NAME}"
            return 1
            ;;
    esac

    # Copy config.xml
    cp "${DOCKER_DIR}/config/config.xml" "${BACKUP_DIR}/config_${TIMESTAMP}.xml" || { echo "Failed to copy config.xml for ${APP_NAME}"; return 1; }

    # Create zip file
    cd "$BACKUP_DIR" || { echo "Failed to change directory to ${BACKUP_DIR}"; return 1; }
    zip "$BACKUP_FILE" "config_${TIMESTAMP}.xml" "${DB_DUMPS[@]}" || { echo "Failed to create zip file for ${APP_NAME}"; return 1; }

    # Clean up temporary files
    rm "config_${TIMESTAMP}.xml" "${DB_DUMPS[@]}"

    echo "${APP_NAME} backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"
    return 0
}

# Main script execution
main() {
    echo "Starting combined backup process for ALL ARR applications..."
    local apps=("sonarr" "radarr" "lidarr" "readarr" "prowlarr" "bazarr")
    local failed_apps=()

    for app in "${apps[@]}"; do
        if ! backup_app "$app"; then
            failed_apps+=("$app")
        fi
    done

    if [ ${#failed_apps[@]} -eq 0 ]; then
        echo "All backups completed successfully!"
    else
        echo "Backup process completed with errors. Failed apps: ${failed_apps[*]}"
        exit 1
    fi
}

# Run the main function
main