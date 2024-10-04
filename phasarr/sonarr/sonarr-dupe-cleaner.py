import os
import sys
import logging
import time
import argparse
import configparser
from pathlib import Path

from plexapi.server import PlexServer
import requests
from tqdm import tqdm

def setup_logging(log_file):
    """Set up logging configuration"""
    logging.basicConfig(
        level=logging.INFO,
        format='[%(asctime)s] %(levelname)s - %(message)s',
        datefmt='%H:%M:%S',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    logging.getLogger('urllib3.connectionpool').disabled = True

def load_config(config_file):
    """Load configuration from file"""
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

# Set up argument parser
parser = argparse.ArgumentParser(description="Manage duplicate files between Plex and Sonarr")
parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without processing any files")
parser.add_argument("--config", "-c", default="config.ini", help="Specify the configuration file (default: config.ini)")
args = parser.parse_args()

# Load configuration
config = load_config(args.config)

# Set up logging
log_file = config.get('Logging', 'LogFile', fallback='sonarr_duplicate_manager.log')
setup_logging(log_file)
log = logging.getLogger("Plex_Sonarr_DupeManager")

# Plex configuration
PLEX_URL = config.get('Plex', 'URL')
PLEX_TOKEN = config.get('Plex', 'Token')

# Sonarr configuration
SONARR_URL = config.get('Sonarr', 'URL')
SONARR_API_KEY = config.get('Sonarr', 'APIKey')
SONARR_PLEX_LIBRARY = config.get('Sonarr', 'PlexLibrary')

TRASH_DIR = Path(config.get('General', 'TrashDirectory', fallback='./trash'))

# Create trash directory if it doesn't exist
TRASH_DIR.mkdir(parents=True, exist_ok=True)

# Setup PlexServer object
try:
    plex = PlexServer(PLEX_URL, PLEX_TOKEN)
except Exception as e:
    log.exception(f"Exception connecting to Plex server {PLEX_URL}")
    print(f"Exception connecting to {PLEX_URL}: {str(e)}")
    sys.exit(1)

def get_plex_duplicates(library_section):
    """Get duplicate items from Plex"""
    log.info(f"Connecting to Plex server and scanning {library_section} library...")
    section = plex.library.section(library_section)
    duplicates = section.search(duplicate=True)
    log.info(f"Found {len(duplicates)} items with duplicates in Plex library: {library_section}")
    return duplicates

def get_media_info(item):
    """Get media info for a Plex item"""
    info = {
        'id': item.ratingKey,
        'title': item.title,
        'file': [],
        'video_resolution': 'Unknown',
        'video_codec': 'Unknown',
        'audio_codec': 'Unknown',
        'file_size': 0
    }
    for media in item.media:
        for part in media.parts:
            info['file'].append(part.file)
            info['file_size'] += part.size if part.size else 0
        info['video_resolution'] = media.videoResolution if media.videoResolution else 'Unknown'
        info['video_codec'] = media.videoCodec if media.videoCodec else 'Unknown'
        info['audio_codec'] = media.audioCodec if media.audioCodec else 'Unknown'
    return info

def get_sonarr_items():
    """Get all items from Sonarr"""
    log.info(f"Fetching items from Sonarr")
    api_url = f"{SONARR_URL}/api/v3/series"
    params = {'apikey': SONARR_API_KEY}
    response = requests.get(api_url, params=params)
    
    if response.status_code == 200:
        items = {}
        for series in response.json():
            episodes_url = f"{SONARR_URL}/api/v3/episode"
            episodes_params = {'apikey': SONARR_API_KEY, 'seriesId': series['id']}
            episodes_response = requests.get(episodes_url, params=episodes_params)
            if episodes_response.status_code == 200:
                for episode in episodes_response.json():
                    if episode.get('hasFile', False):
                        items[f"{series['title']} - {episode['seasonNumber']}x{episode['episodeNumber']:02d}"] = Path(episode['episodeFile']['path'])
        log.info(f"Found {len(items)} episodes in Sonarr")
        return items
    else:
        raise requests.exceptions.RequestException(f"Failed to get items from Sonarr. Status code: {response.status_code}")

def compare_and_mark_for_deletion(plex_duplicates, sonarr_items):
    """Compare duplicates and mark files for deletion"""
    files_to_delete = []
    
    log.info("Comparing Plex duplicates with Sonarr items...")
    for item in tqdm(plex_duplicates, desc="Comparing", unit="item"):
        media_info = get_media_info(item)
        if media_info['title'] in sonarr_items:
            sonarr_file = sonarr_items[media_info['title']]
            plex_files = [Path(file) for file in media_info['file']]
            if any(plex_file.resolve() != sonarr_file.resolve() for plex_file in plex_files):
                files_to_delete.append((media_info['title'], plex_files, sonarr_file, media_info))
    
    log.info(f"Marked {len(files_to_delete)} items with potential duplicates")
    return files_to_delete

def confirm_deletion(files_to_delete, dry_run):
    """Confirm deletion with user"""
    log.info("Files marked for deletion:")
    for i, (title, plex_files, sonarr_file, _) in enumerate(files_to_delete, 1):
        log.info(f"\n{i}. Item: {title}")
        log.info("Plex Paths:")
        for j, plex_file in enumerate(plex_files, 1):
            log.info(f"  File {j}: {plex_file}")
        log.info("Sonarr Path:")
        log.info(f"  File: {sonarr_file}")
        log.info("File(s) to be deleted:")
        for plex_file in plex_files:
            if plex_file != sonarr_file:
                log.info(f"  {plex_file}")
        log.info("-" * 80)
    
    if dry_run:
        log.info("DRY RUN: No files will be processed.")
        return files_to_delete
    
    while True:
        choice = input("\nEnter 'all' to process all files, or file numbers separated by commas to process specific files (or 'q' to quit): ").strip().lower()
        
        if choice == 'q':
            log.info("User chose to quit. No files will be processed.")
            return []
        elif choice == 'all':
            return files_to_delete
        else:
            try:
                indices = [int(i.strip()) - 1 for i in choice.split(',')]
                if all(0 <= i < len(files_to_delete) for i in indices):
                    return [files_to_delete[i] for i in indices]
                else:
                    log.warning("Invalid input. Please enter valid file numbers.")
            except ValueError:
                log.warning("Invalid input. Please enter 'all', valid file numbers, or 'q' to quit.")

def process_files(files_to_delete, permanent_delete=False):
    """Process files based on user choice"""
    successfully_processed = []
    failed_processes = []

    action = "Deleting" if permanent_delete else "Moving"
    log.info(f"{action} files...")
    for title, plex_files, sonarr_file, _ in tqdm(files_to_delete, desc=action, unit="item"):
        for file in plex_files:
            if file != sonarr_file:
                try:
                    abs_path = os.path.abspath(file)
                    log.debug(f"Attempting to {action.lower()}: {abs_path}")
                    if os.path.exists(abs_path):
                        if permanent_delete:
                            os.remove(abs_path)
                            successfully_processed.append((abs_path, "Deleted"))
                            log.info(f"Successfully deleted: {abs_path}")
                        else:
                            dest = os.path.join(TRASH_DIR, f"{title}_{os.path.basename(file)}")
                            os.rename(abs_path, dest)
                            successfully_processed.append((abs_path, dest))
                            log.info(f"Successfully moved: {abs_path} to {dest}")
                    else:
                        log.warning(f"File not found: {abs_path}")
                        failed_processes.append(abs_path)
                except Exception as e:
                    failed_processes.append(abs_path)
                    log.error(f"Failed to {action.lower()} {abs_path}: {str(e)}")

    return successfully_processed, failed_processes

def main(dry_run):
    log.info("Starting Sonarr duplicate file management process")
    
    try:
        plex_duplicates = get_plex_duplicates(SONARR_PLEX_LIBRARY)
        sonarr_items = get_sonarr_items()
        
        files_to_delete = compare_and_mark_for_deletion(plex_duplicates, sonarr_items)
        
        if not files_to_delete:
            log.info("No duplicate files to process")
            return

        confirmed_files = confirm_deletion(files_to_delete, dry_run)
        
        if dry_run:
            log.info("DRY RUN: No files were actually processed. Check the log for details.")
        elif confirmed_files:
            while True:
                action_choice = input("\nDo you want to permanently delete the files or move them to trash? (delete/trash): ").strip().lower()
                if action_choice in ['delete', 'trash']:
                    break
                else:
                    print("Invalid choice. Please enter 'delete' or 'trash'.")

            permanent_delete = action_choice == 'delete'
            successfully_processed, failed_processes = process_files(confirmed_files, permanent_delete)
            
            action = "deleted" if permanent_delete else "moved to trash"
            log.info(f"Successfully {action} {len(successfully_processed)} files")
            if failed_processes:
                log.warning(f"Failed to process {len(failed_processes)} files")
            
            if not permanent_delete:
                log.info("Files that still exist in their original location:")
                for _, plex_files, sonarr_file, _ in confirmed_files:
                    for file in plex_files:
                        if file != sonarr_file and os.path.exists(file):
                            log.info(str(file))
        else:
            log.info("No files confirmed for processing")
    
    except Exception as e:
        log.error(f"An error occurred during the process: {str(e)}")
    
    log.info("Sonarr duplicate file management process completed")

if __name__ == "__main__":
    main(args.dry_run)