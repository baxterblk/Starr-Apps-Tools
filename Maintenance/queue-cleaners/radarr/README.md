# Queue Cleaner for Radarr and Sonarr

This script helps manage download queues in Radarr and Sonarr by identifying problematic items, removing them, adding them to the blocklist, and triggering a new search.

## Features

- Supports multiple Radarr and Sonarr instances
- Identifies completed downloads with warnings, failed downloads, and stalled downloads
- Removes problematic items from the queue
- Adds removed items to the blocklist
- Triggers a new search for blocklisted items
- Dry run mode for testing
- Configurable via environment variables

## Requirements

- Bash
- curl
- jq

## Installation

1. Clone this repository:
   ```
   git clone https://git.blakbox.vip/baxterblk/arr-queue-cleaner.git
   cd arr-queue-cleaner
   ```

2. Copy the sample .env file and edit it with your settings:
   ```
   cp .env.sample .env
   nano .env
   ```

3. Make the script executable:
   ```
   chmod +x queue_cleaner.sh
   ```

## Usage

Run the script:

```
./queue_cleaner.sh
```

For a dry run (no changes made):

```
DRY_RUN=true ./queue_cleaner.sh
```

## Configuration

Edit the `.env` file to configure the script. Here are the available options:

- `ENABLE_QUEUE_CLEANER`: Set to "true" to enable the script
- `QUEUE_CLEANER_INTERVAL`: How often the script should run (e.g., "15m" for 15 minutes)
- `RADARR_INSTANCES`: Space-separated list of Radarr instance names
- `SONARR_INSTANCES`: Space-separated list of Sonarr instance names
- For each instance, define URL and API key:
  - `RADARR_<instance>_URL`
  - `RADARR_<instance>_API_KEY`
  - `SONARR_<instance>_URL`
  - `SONARR_<instance>_API_KEY`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.