README.md

# Plex-Radarr Duplicate File Manager

This script helps manage and remove duplicate movie files between a Plex server and multiple Radarr instances. It compares the movie files in your Plex library with the files tracked by your Radarr instances, identifies duplicates based on file path and title matching, and allows you to selectively delete or move the extra copies.

## Features

* Scans your Plex library for movies marked as duplicates.
* Connects to multiple Radarr instances to get movie file information.
* Compares Plex and Radarr movie files based on title and full file path.
* Provides a detailed report of potential duplicate files.
* Allows you to selectively choose which duplicate files to process.
* Supports both permanent deletion and moving files to a trash directory.
* Generates a dry-run report for previewing potential changes.

## Requirements

* Python 3.6 or higher
* Plex API (plexapi)
* Requests library
* Tqdm library (for progress bars)
* Colorama library (for colored output)

## Installation

1. Clone the repository:

   ```bash
   git clone https://git.blakbox.vip/baxterblk/Starr-Apps-Tools.git
   cd Starr-Apps-Tools/phasarr/radarr
   ```

2. Install the required libraries:

   ```bash
   pip install -r requirements.txt
   ```

3. Configure the script:

   * Create a `config.ini` file based on the `config.ini.example` template.
   * Fill in the required information for your Plex server and Radarr instances.

## Usage

```
python duplicate_manager.py [--dry-run] [--config <config_file>]
```

* `--dry-run`: Perform a dry run without processing any files.
* `--config`: Specify the configuration file (default: `config.ini`).

## Configuration

The `config.ini` file stores the settings for the script:

```ini
[Plex]
URL = http://your-plex-server:32400
Token = your_plex_token_here

[Radarr:Movies]
URL = https://radarr.your-domain.com
APIKey = your_api_key_here
PlexLibrary = Movies

[Radarr:4K]
URL = https://radarr-4k.your-domain.com
APIKey = your_4k_api_key_here
PlexLibrary = Movies (4K)

[General]
TrashDirectory = /path/to/your/trash/directory

[Logging]
LogFile = duplicate_manager.log
```

* **Plex section:**
    * `URL`: The URL of your Plex server.
    * `Token`: Your Plex authentication token.

* **Radarr sections:**
    * You can define multiple Radarr instances with sections like `[Radarr:InstanceName]`.
    * `URL`: The URL of the Radarr instance.
    * `APIKey`: The API key of the Radarr instance.
    * `PlexLibrary`: The name of the corresponding Plex library section for this Radarr instance.

* **General section:**
    * `TrashDirectory`: The directory where files will be moved when not permanently deleting.

* **Logging section:**
    * `LogFile`: The file where logs will be written.

## How it Works

1. The script scans your Plex library for movies marked as duplicates.
2. It retrieves movie file information from your configured Radarr instances.
3. It compares the Plex and Radarr movie files based on title and full file path.
4. If duplicates are found, it presents you with a list of files to be processed.
5. You can choose to permanently delete the files or move them to a trash directory.
6. The script processes the selected files and provides a summary of the actions taken.

## Disclaimer

* Use this script at your own risk.
* Always back up your data before running the script.
* The script is provided as-is, without any warranty.

This script is intended to help you manage duplicate movie files. Please use it responsibly and ensure you understand the actions it performs before running it on your system.