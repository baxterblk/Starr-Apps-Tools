# Plex Radarr Sonarr Duplicate Manager

This script is part of the [Starr-Apps-Tools](https://git.blakbox.vip/baxterblk/Starr-Apps-Tools) collection. It manages duplicate files between Plex, Radarr, and Sonarr instances by identifying and optionally removing or moving duplicate files.

## Features

- Supports multiple Radarr and Sonarr instances
- Compares files in Plex libraries with Radarr and Sonarr databases
- Offers options to delete or move duplicate files to a trash directory
- Provides a dry run option for testing without file modifications
- Generates detailed logs and reports

## Requirements

- Python 3.6+
- Plex Media Server
- Radarr and/or Sonarr instances

## Installation

1. Clone the repository or download the script:

   ```
   git clone https://git.blakbox.vip/baxterblk/Starr-Apps-Tools.git
   cd Starr-Apps-Tools/phasarr/combined
   ```

2. Install the required dependencies:

   ```
   pip install -r requirements.txt
   ```

## Configuration

1. Copy the `config.ini.example` file to `config.ini`:

   ```
   cp config.ini.example config.ini
   ```

2. Edit the `config.ini` file and update it with your Plex, Radarr, and Sonarr information:

   ```ini
   [Plex]
   URL = http://your-plex-server:32400
   Token = your_plex_token_here

   [Radarr:Movies]
   URL = https://radarr.your-domain.com
   APIKey = your_radarr_api_key_here
   PlexLibrary = Movies

   [Sonarr:TV]
   URL = https://sonarr.your-domain.com
   APIKey = your_sonarr_api_key_here
   PlexLibrary = TV Shows

   [General]
   TrashDirectory = /path/to/your/trash/directory

   [Logging]
   LogFile = duplicate_manager.log
   ```

   Add additional Radarr or Sonarr instances as needed, following the same format.

## Usage

Run the script with the following command:

```
python combined-dupe-finder.py [options]
```

### Options:

- `--dry-run`: Perform a dry run without processing any files
- `--config` or `-c`: Specify the configuration file (default: config.ini)

## Example:

```
python combined-dupe-finder.py --dry-run
```

This will perform a dry run, showing which files would be processed without actually modifying anything.

## Output

The script will generate a log file (specified in the config.ini) with detailed information about the process. If you use the dry run option, it will also create a report file showing which files would be processed.