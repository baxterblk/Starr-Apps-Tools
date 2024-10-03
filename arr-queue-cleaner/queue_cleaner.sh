#!/usr/bin/env bash
scriptVersion="9.0"
scriptName="queue_cleaner.sh"

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Error: .env file not found. Please create it with the required variables."
    exit 1
fi

# Default configuration
DRY_RUN=${DRY_RUN:-false}

# Function to log messages with timestamps
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

verifyConfig() {
    if [ "$ENABLE_QUEUE_CLEANER" != "true" ]; then
        log "Script is not enabled. Set ENABLE_QUEUE_CLEANER to \"true\" in the \".env\" file to enable."
        exit 0
    fi

    if [ -z "$QUEUE_CLEANER_INTERVAL" ]; then
        QUEUE_CLEANER_INTERVAL="15m"
        log "QUEUE_CLEANER_INTERVAL not set, using default: 15m"
    fi

    # Verify Radarr instances
    if [ -z "$RADARR_INSTANCES" ]; then
        log "Warning: No Radarr instances defined. Radarr functionality will be disabled."
    else
        for instance in $RADARR_INSTANCES; do
            url_var="RADARR_${instance}_URL"
            api_key_var="RADARR_${instance}_API_KEY"
            if [ -z "${!url_var}" ] || [ -z "${!api_key_var}" ]; then
                log "Warning: $instance is missing URL or API key. This instance will be skipped."
            else
                log "Radarr instance configured: $instance"
            fi
        done
    fi

    # Verify Sonarr instances
    if [ -z "$SONARR_INSTANCES" ]; then
        log "Warning: No Sonarr instances defined. Sonarr functionality will be disabled."
    else
        for instance in $SONARR_INSTANCES; do
            url_var="SONARR_${instance}_URL"
            api_key_var="SONARR_${instance}_API_KEY"
            if [ -z "${!url_var}" ] || [ -z "${!api_key_var}" ]; then
                log "Warning: $instance is missing URL or API key. This instance will be skipped."
            else
                log "Sonarr instance configured: $instance"
            fi
        done
    fi

    # Verify Readarr instances
    if [ -z "$READARR_INSTANCES" ]; then
        log "Warning: No Readarr instances defined. Readarr functionality will be disabled."
    else
        for instance in $READARR_INSTANCES; do
            url_var="READARR_${instance}_URL"
            api_key_var="READARR_${instance}_API_KEY"
            if [ -z "${!url_var}" ] || [ -z "${!api_key_var}" ]; then
                log "Warning: $instance is missing URL or API key. This instance will be skipped."
            else
                log "Readarr instance configured: $instance"
            fi
        done
    fi

    # Verify Lidarr instances
    if [ -z "$LIDARR_INSTANCES" ]; then
        log "Warning: No Lidarr instances defined. Lidarr functionality will be disabled."
    else
        for instance in $LIDARR_INSTANCES; do
            url_var="LIDARR_${instance}_URL"
            api_key_var="LIDARR_${instance}_API_KEY"
            if [ -z "${!url_var}" ] || [ -z "${!api_key_var}" ]; then
                log "Warning: $instance is missing URL or API key. This instance will be skipped."
            else
                log "Lidarr instance configured: $instance"
            fi
        done
    fi

    if [ -z "$RADARR_INSTANCES" ] && [ -z "$SONARR_INSTANCES" ] && [ -z "$READARR_INSTANCES" ] && [ -z "$LIDARR_INSTANCES" ]; then
        log "Error: No valid Radarr, Sonarr, Readarr, or Lidarr instances configured. Exiting."
        exit 1
    fi
}

triggerSearch() {
    local arrType=$1
    local instance=$2
    local itemId=$3
    local itemTitle=$4
    
    local url_var="${arrType^^}_${instance}_URL"
    local api_key_var="${arrType^^}_${instance}_API_KEY"
    local url=${!url_var}
    local api_key=${!api_key_var}

    case "$arrType" in
        RADARR)
            search_command="MoviesSearch"
            search_payload="{\"name\":\"$search_command\",\"movieIds\":[$itemId]}"
            api_version="v3"
            ;;
        SONARR)
            search_command="SeriesSearch"
            search_payload="{\"name\":\"$search_command\",\"seriesId\":$itemId}"
            api_version="v3"
            ;;
        READARR)
            search_command="AuthorSearch"
            search_payload="{\"name\":\"$search_command\",\"authorId\":$itemId}"
            api_version="v1"
            ;;
        LIDARR)
            search_command="ArtistSearch"
            search_payload="{\"name\":\"$search_command\",\"artistId\":$itemId}"
            api_version="v1"
            ;;
        *)
            log "Error: Unknown arrType: $arrType"
            return 1
            ;;
    esac

    if [ -z "$itemId" ] || [ "$itemId" == "null" ]; then
        log "Error: Invalid item ID for $itemTitle in $instance. Skipping search."
        return
    fi
    log "Triggering new search for $arrType item in $instance: $itemTitle (ID: $itemId)"
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would trigger search for $itemTitle in $instance"
        return
    fi
    local searchResponse
    searchResponse=$(curl -s -X POST "$url/api/$api_version/command" -H "X-Api-Key: $api_key" -H "Content-Type: application/json" -d "$search_payload")
    
    if echo "$searchResponse" | jq -e '.id' >/dev/null 2>&1; then
        log "Search triggered successfully for $itemTitle in $instance"
    else
        log "Failed to trigger search for $itemTitle in $instance. Response: $searchResponse"
    fi
}

processQueue() {
    local arrType=$1
    local instance=$2
    
    local url_var="${arrType^^}_${instance}_URL"
    local api_key_var="${arrType^^}_${instance}_API_KEY"
    local url=${!url_var}
    local api_key=${!api_key_var}

    if [ -z "$url" ] || [ -z "$api_key" ]; then
        log "Error: URL or API key not set for $arrType instance $instance. Skipping."
        return 1
    fi

    case "$arrType" in
        RADARR)
            id_field="movieId"
            api_version="v3"
            ;;
        SONARR)
            id_field="seriesId"
            api_version="v3"
            ;;
        READARR)
            id_field="authorId"
            api_version="v1"
            ;;
        LIDARR)
            id_field="artistId"
            api_version="v1"
            ;;
        *)
            log "Error: Unknown arrType: $arrType"
            return 1
            ;;
    esac

    local arrQueueData
    arrQueueData=$(curl -s "$url/api/$api_version/queue?page=1&pageSize=200&sortDirection=descending&sortKey=progress&includeUnknownItems=true&apikey=$api_key")
    
    if [ -z "$arrQueueData" ] || [ "$(echo "$arrQueueData" | jq -r '.error // empty')" != "" ]; then
        log "Error: Failed to fetch queue data from $arrType instance $instance. Please check your URL and API key."
        log "${arrType^^}_${instance}_URL: $url"
        log "API Response: $arrQueueData"
        return 1
    fi

    local arrQueueRecords
    arrQueueRecords=$(echo "$arrQueueData" | jq -r '.records[]')
    local arrQueueIdCount
    arrQueueIdCount=$(echo "$arrQueueData" | jq -r '.totalRecords')

    local problematicItems
    problematicItems=$(echo "$arrQueueRecords" | jq -r 'select(.status=="completed" and .trackedDownloadStatus=="warning") | .id')
    problematicItems+=$'\n'$(echo "$arrQueueRecords" | jq -r 'select(.status=="failed") | .id')
    problematicItems+=$'\n'$(echo "$arrQueueRecords" | jq -r 'select(.status=="stalled") | .id')
    problematicItems=$(echo "$problematicItems" | sort -u | grep -v '^$')

    local problematicItemsCount
    problematicItemsCount=$(echo "$problematicItems" | grep -v '^$' | wc -l)

    if [ $problematicItemsCount -eq 0 ]; then
        log "$arrType $instance: $arrQueueIdCount items in queue, no problematic items found"
    else
        log "$arrType $instance: Found $problematicItemsCount problematic items out of $arrQueueIdCount total queue items"
        while IFS= read -r queueId; do
            if [ -z "$queueId" ] || [ "$queueId" == "null" ]; then
                continue
            fi
            local arrQueueItemData
            arrQueueItemData=$(echo "$arrQueueRecords" | jq -r "select(.id==$queueId)")
            local arrQueueItemTitle
            arrQueueItemTitle=$(echo "$arrQueueItemData" | jq -r '.title')
            local itemId
            itemId=$(echo "$arrQueueItemData" | jq -r ".$id_field")
            
            log "$arrType $instance: Processing problematic queue item: $queueId ($arrQueueItemTitle)"
            if [ "$DRY_RUN" = "true" ]; then
                log "[DRY RUN] Would remove queue item and add to blocklist: $queueId ($arrQueueItemTitle)"
                log "[DRY RUN] Would trigger new search for: $arrQueueItemTitle"
                continue
            fi
            local deleteResponse
            deleteResponse=$(curl -sX DELETE "$url/api/$api_version/queue/$queueId?removeFromClient=true&blocklist=true&apikey=$api_key")
            if [ -z "$deleteResponse" ]; then
                log "$arrType $instance: Successfully removed item $queueId and added to blocklist"
                # Trigger a new search for the item
                triggerSearch "$arrType" "$instance" "$itemId" "$arrQueueItemTitle"
            else
                log "$arrType $instance: Error processing item $queueId: $deleteResponse"
            fi
        done <<< "$problematicItems"
    fi
}

main() {
    verifyConfig
    log "Script started. Version: $scriptVersion"
    if [ "$DRY_RUN" = "true" ]; then
        log "Running in DRY RUN mode. No changes will be made."
    fi
    while true; do
        log "Starting Queue Cleaner process..."
        
        # Process Radarr instances
        for instance in $RADARR_INSTANCES; do
            url_var="RADARR_${instance}_URL"
            api_key_var="RADARR_${instance}_API_KEY"
            if [ -n "${!url_var}" ] && [ -n "${!api_key_var}" ]; then
                log "Processing Radarr instance: $instance"
                processQueue "RADARR" "$instance"
            fi
        done

        # Process Sonarr instances
        for instance in $SONARR_INSTANCES; do
            url_var="SONARR_${instance}_URL"
            api_key_var="SONARR_${instance}_API_KEY"
            if [ -n "${!url_var}" ] && [ -n "${!api_key_var}" ]; then
                log "Processing Sonarr instance: $instance"
                processQueue "SONARR" "$instance"
            fi
        done

        # Process Readarr instances
        for instance in $READARR_INSTANCES; do
            url_var="READARR_${instance}_URL"
            api_key_var="READARR_${instance}_API_KEY"
            if [ -n "${!url_var}" ] && [ -n "${!api_key_var}" ]; then
                log "Processing Readarr instance: $instance"
                processQueue "READARR" "$instance"
            fi
        done

        # Process Lidarr instances
        for instance in $LIDARR_INSTANCES; do
            url_var="LIDARR_${instance}_URL"
            api_key_var="LIDARR_${instance}_API_KEY"
            if [ -n "${!url_var}" ] && [ -n "${!api_key_var}" ]; then
                log "Processing Lidarr instance: $instance"
                processQueue "LIDARR" "$instance"
            fi
        done

        log "Queue Cleaner process completed. Sleeping for $QUEUE_CLEANER_INTERVAL..."
        sleep "$QUEUE_CLEANER_INTERVAL"
    done
}

main