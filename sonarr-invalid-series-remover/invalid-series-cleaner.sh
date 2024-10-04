#!/usr/bin/env bash

scriptVersion="1.8"
scriptName="InvalidSeriesAutoCleaner"

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "Error: .env file not found. Please create a .env file with your Sonarr configuration."
    exit 1
fi

# Check if required variables are set
if [ -z "$ARR_URL" ] || [ -z "$ARR_API_KEY" ] || [ -z "$ENABLE_INVALID_SERIES_AUTO_CLEANER" ]; then
    echo "Error: Required variables are not set in the .env file."
    exit 1
fi

#### Create Log File
logFile="/tmp/${scriptName}.log"

logfileSetup() {
    touch "$logFile"
    exec &> >(tee -a "$logFile")
}

log() {
    echo "[$(date)] $1"
}

verifyApiAccess() {
    if ! curl -sf -H "X-Api-Key:$ARR_API_KEY" "$ARR_URL/api/v3/system/status" > /dev/null; then
        log "Error: Unable to connect to Sonarr API. Please check your ARR_URL and ARR_API_KEY in the .env file."
        exit 1
    fi
}

verifyConfig() {
    if [ "$ENABLE_INVALID_SERIES_AUTO_CLEANER" != "true" ]; then
        log "Script is not enabled. Set ENABLE_INVALID_SERIES_AUTO_CLEANER to 'true' in the .env file to enable it."
        log "Sleeping (infinity)"
        sleep infinity
    fi
    
    if [ -z "$INVALID_SERIES_AUTO_CLEANER_INTERVAL" ]; then
        INVALID_SERIES_AUTO_CLEANER_INTERVAL="1h"
    fi
}

InvalidSeriesAutoCleanerProcess() {
    # Get invalid series tvdb id's
    seriesTvdbId="$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request GET "$ARR_URL/api/v3/health" | jq -r '.[] | select(.source=="RemovedSeriesCheck") | select(.type=="error")' | grep "message" | grep -o '[[:digit:]]*')"
    
    if [ -z "$seriesTvdbId" ]; then
        log "No invalid series (tvdbid) reported by Sonarr health check, skipping..."
        return
    fi
    
    # Process each invalid series tvdb id
    for tvdbId in $(echo $seriesTvdbId); do
        seriesData="$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request GET "$ARR_URL/api/v3/series" | jq -r ".[] | select(.tvdbId==$tvdbId)")"
        seriesId="$(echo "$seriesData" | jq -r .id)"
        seriesTitle="$(echo "$seriesData" | jq -r .title)"
        seriesPath="$(echo "$seriesData" | jq -r .path)"
        
        log "$seriesId :: $seriesTitle :: $seriesPath :: Removing and deleting invalid Series (tvdbId: $tvdbId) based on Sonarr Health Check error..."
    
        # Send command to Sonarr to delete series and files
        arrCommand=$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request DELETE "$ARR_URL/api/v3/series/$seriesId?deleteFiles=true")
        
        # If you have a PlexNotify.bash script, uncomment the following lines
        # folderToScan="$(dirname "$seriesPath")"
        # log "Using PlexNotify.bash to update Plex.... ($folderToScan)"
        # bash /path/to/PlexNotify.bash "$folderToScan" "true"
    done
}

# Main loop
for (( ; ; )); do
    let i++
    logfileSetup
    log "Script starting..."
    verifyConfig
    verifyApiAccess
    InvalidSeriesAutoCleanerProcess
    log "Script sleeping for $INVALID_SERIES_AUTO_CLEANER_INTERVAL..."
    sleep $INVALID_SERIES_AUTO_CLEANER_INTERVAL
done

exit