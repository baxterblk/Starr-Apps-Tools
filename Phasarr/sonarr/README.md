# Sonarr Duplicate Manager

This script helps manage duplicate files between Plex and multiple Sonarr instances. It identifies duplicate files in your Plex libraries and compares them with the files managed by your Sonarr instances, allowing you to delete or move the duplicates to a trash directory.

## Features

- Support for multiple Sonarr instances
- Dry-run mode for safe testing
- Option to delete files permanently or move them to a trash directory
- Detailed logging
- Interactive confirmation process

## Requirements

- Python 3.7+
- Plex server
- One or more Sonarr instances
- Required Python packages (see `requirements.txt`)

## Installation

1. Clone the Starr-Apps-Tools repository:

   ```
   git clone https://git.blakbox.vip/baxterblk/Starr-Apps-Tools.git
   ```

2. Navigate to the Sonarr directory:

   ```
   cd Starr-Apps-Tools/phasarr/sonarr
   ```

3. Install the required Python packages:

   ```
   pip install -r requirements.txt
   ```

4. Copy the `config.ini.example` file to `config.ini` and edit it with your specific configuration:

   ```
   cp config.ini.example config.ini
   ```

## Configuration

Edit the `config.ini` file to match your setup. Here's an explanation of each section:

- `[Logging]`: Specify the log file location
- `[Plex]`: Enter your Plex server URL and token
- `[Sonarr:*]`: Add a section for each Sonarr instance, replacing `*` with a unique identifier
- `[General]`: Set the trash directory for moved files

## Usage

Run the script with:

```
python sonarr-dupe-cleaner.py
```

### Command-line options:

- `--dry-run`: Perform a dry run without actually deleting or moving any files
- `--config` or `-c`: Specify a custom config file (default is `config.ini`)

Example:

```
python sonarr-dupe-cleaner.py --dry-run
```

## How it works

1. The script connects to your Plex server and scans the specified libraries for duplicates.
2. It then fetches the file information from your Sonarr instances.
3. The script compares the Plex duplicates with the Sonarr files and identifies potential duplicates.
4. You're presented with a list of duplicate files and can choose which ones to process.
5. Depending on your choice, the script will either delete the files or move them to the specified trash directory.