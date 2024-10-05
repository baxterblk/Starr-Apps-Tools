#!/usr/bin/env bash

scriptVersion="1.4"
scriptName="InvalidMoviesAutoCleaner"

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "Error: .env file not found. Please create a .env file with your Radarr configuration."
    exit 1
fi

# Check if required variables are set
if [ -z "$ARR_URL" ] || [ -z "$ARR_API_KEY" ] || [ -z "$ENABLE_INVALID_MOVIES_AUTO_CLEANER" ]; then
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
        log "Error: Unable to connect to Radarr API. Please check your ARR_URL and ARR_API_KEY in the .env file."
        exit 1
    fi
}

verifyConfig() {
    if [ "$ENABLE_INVALID_MOVIES_AUTO_CLEANER" != "true" ]; then
        log "Script is not enabled. Set ENABLE_INVALID_MOVIES_AUTO_CLEANER to 'true' in the .env file to enable it."
        log "Sleeping (infinity)"
        sleep infinity
    fi
    
    if [ -z "$INVALID_MOVIES_AUTO_CLEANER_INTERVAL" ]; then
        INVALID_MOVIES_AUTO_CLEANER_INTERVAL="1h"
    fi
}

InvalidMovieAutoCleanerProcess() {
    # Get invalid movies tmdbid id's
    movieTmdbid="$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request GET "$ARR_URL/api/v3/health" | jq -r '.[] | select(.source=="RemovedMovieCheck") | select(.type=="error")' | grep -o 'tmdbid [0-9]*' | grep -o '[[:digit:]]*')"
   
    if [ -z "$movieTmdbid" ]; then
        log "No invalid movies (tmdbid) reported by Radarr health check, skipping..."
        return
    fi
  
    # Process each invalid movie tmdb id
    moviesData="$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request GET "$ARR_URL/api/v3/movie")"
    for tmdbid in $(echo $movieTmdbid); do
        movieData="$(echo "$moviesData" | jq -r ".[] | select(.tmdbId==$tmdbid)")"
        movieId="$(echo "$movieData" | jq -r .id)"
        movieTitle="$(echo "$movieData" | jq -r .title)"
        moviePath="$(echo "$movieData" | jq -r .path)"
      
        log "$movieId :: $movieTitle :: $moviePath :: Removing and deleting invalid movie (tmdbid: $tmdbid) based on Radarr Health Check error..."
        # Send command to Radarr to delete movie and files
        arrCommand=$(curl -s --header "X-Api-Key:$ARR_API_KEY" --request DELETE "$ARR_URL/api/v3/movie/$movieId?deleteFiles=true")
    done
}

# Main loop
for (( ; ; )); do
    let i++
    logfileSetup
    log "Script starting..."
    verifyConfig
    verifyApiAccess
    InvalidMovieAutoCleanerProcess
    log "Script sleeping for $INVALID_MOVIES_AUTO_CLEANER_INTERVAL..."
    sleep $INVALID_MOVIES_AUTO_CLEANER_INTERVAL
done

exit