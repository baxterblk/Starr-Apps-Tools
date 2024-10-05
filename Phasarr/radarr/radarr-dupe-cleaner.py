import os
import sys
import logging
import time
import argparse
import configparser
import shutil
from datetime import datetime
from pathlib import Path

from plexapi.server import PlexServer
import requests
from tqdm import tqdm
from colorama import init, Fore, Style

# Initialize colorama
init(autoreset=True)

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
parser = argparse.ArgumentParser(description="Manage duplicate movie files between Plex and multiple Radarr instances")
parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without processing any files")
parser.add_argument("--config", "-c", default="config.ini", help="Specify the configuration file (default: config.ini)")
args = parser.parse_args()

# Load configuration
config = load_config(args.config)

# Set up logging
log_file = config.get('Logging', 'LogFile', fallback='duplicate_manager.log')
setup_logging(log_file)
log = logging.getLogger("Plex_Radarr_DupeManager")

# Plex configuration
PLEX_URL = config.get('Plex', 'URL')
PLEX_TOKEN = config.get('Plex', 'Token')

# Radarr instances configuration
radarr_instances = {}
for section in config.sections():
    if section == 'Radarr' or section.startswith('Radarr:'):
        instance_name = section.split(':', 1)[-1] if ':' in section else 'Movies'
        radarr_instances[instance_name] = {
            'url': config.get(section, 'URL'),
            'api_key': config.get(section, 'APIKey'),
            'plex_library': config.get(section, 'PlexLibrary')
        }

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
    """Get duplicate movies from Plex"""
    log.info(f"Connecting to Plex server and scanning {library_section} library...")
    section = plex.library.section(library_section)
    duplicates = section.search(duplicate=True)
    log.info(f"Found {len(duplicates)} movies with duplicates in Plex library: {library_section}")
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

def get_radarr_movies(url, api_key):
    """Get all movies from a Radarr instance"""
    log.info(f"Fetching movies from Radarr instance: {url}")
    api_url = f"{url}/api/v3/movie"
    params = {'apikey': api_key}
    response = requests.get(api_url, params=params)
    
    if response.status_code == 200:
        movies = {}
        for movie in response.json():
            if movie['hasFile']:
                movies[movie['title']] = Path(movie['movieFile']['path'])
        log.info(f"Found {len(movies)} movies in Radarr instance: {url}")
        return movies
    else:
        raise requests.exceptions.RequestException(f"Failed to get movies from Radarr. Status code: {response.status_code}")

def compare_and_mark_for_deletion(plex_duplicates, radarr_movies):
    """Compare duplicates and mark files for deletion"""
    files_to_delete = []
    
    log.info("Comparing Plex duplicates with Radarr movies...")
    for item in tqdm(plex_duplicates, desc="Comparing", unit="movie"):
        media_info = get_media_info(item)
        if media_info['title'] in radarr_movies:
            radarr_file = radarr_movies[media_info['title']]
            plex_files = [Path(file) for file in media_info['file']]
            if any(plex_file.resolve() != radarr_file.resolve() for plex_file in plex_files):
                files_to_delete.append((media_info['title'], plex_files, radarr_file, media_info))
    
    log.info(f"Marked {len(files_to_delete)} movies with potential duplicates")
    return files_to_delete

def confirm_deletion(files_to_delete, dry_run):
    """Confirm deletion with user"""
    log.info("Files marked for deletion:")
    for i, (title, plex_files, radarr_file, _) in enumerate(files_to_delete, 1):
        log.info(f"\nMovie: {title}")
        log.info("Plex Paths:")
        for j, plex_file in enumerate(plex_files, 1):
            log.info(f"File {j}: {plex_file}")
        log.info("Radarr Path:")
        log.info(f"File: {radarr_file}")
        log.info("File(s) to be deleted:")
        for plex_file in plex_files:
            if plex_file != radarr_file:
                log.info(f"{plex_file}")
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
    for title, plex_files, radarr_file, _ in tqdm(files_to_delete, desc=action, unit="movie"):
        for file in plex_files:
            if file != radarr_file:
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
                            shutil.move(abs_path, dest)
                            successfully_processed.append((abs_path, dest))
                            log.info(f"Successfully moved: {abs_path} to {dest}")
                    else:
                        log.warning(f"File not found: {abs_path}")
                        failed_processes.append(abs_path)
                except Exception as e:
                    failed_processes.append(abs_path)
                    log.error(f"Failed to {action.lower()} {abs_path}: {str(e)}")

    return successfully_processed, failed_processes

def generate_dry_run_report(files_to_delete, instance_name):
    """Generate a detailed report for dry run"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"dry_run_report_{instance_name}_{timestamp}.txt"
    
    with open(filename, 'w') as f:
        f.write(f"Dry Run Report - Files that would be processed (Radarr Instance: {instance_name})\n")
        f.write("==============================================\n\n")
        for title, plex_files, radarr_file, media_info in files_to_delete:
            f.write(f"Movie: {title}\n")
            f.write("Plex Paths:\n")
            for i, plex_file in enumerate(plex_files, 1):
                f.write(f"File {i}: {plex_file}\n")
            f.write("Radarr Path:\n")
            f.write(f"File: {radarr_file}\n")
            f.write("File(s) to be deleted:\n")
            for plex_file in plex_files:
                if plex_file != radarr_file:
                    f.write(f"{plex_file}\n")
            f.write(f"\nResolution: {media_info['video_resolution']}\n")
            f.write(f"Video Codec: {media_info['video_codec']}\n")
            f.write(f"Audio Codec: {media_info['audio_codec']}\n")
            f.write(f"File Size: {media_info['file_size']} bytes\n")
            f.write("\n" + "-" * 80 + "\n\n")
        
        f.write(f"\nTotal movies with duplicates: {len(files_to_delete)}\n")
    
    log.info(f"Dry run report generated: {filename}")
    return filename

def main(dry_run):
    log.info("Starting duplicate file management process")
    
    try:
        for instance_name, instance_config in radarr_instances.items():
            log.info(f"Processing Radarr instance: {instance_name}")
            radarr_url = instance_config['url']
            radarr_api_key = instance_config['api_key']
            plex_library = instance_config['plex_library']

            plex_duplicates = get_plex_duplicates(plex_library)
            radarr_movies = get_radarr_movies(radarr_url, radarr_api_key)
            
            files_to_delete = compare_and_mark_for_deletion(plex_duplicates, radarr_movies)
            
            if not files_to_delete:
                log.info(f"No duplicate files to process for Radarr instance: {instance_name}")
                continue

            confirmed_files = confirm_deletion(files_to_delete, dry_run)
            
            if dry_run:
                report_file = generate_dry_run_report(confirmed_files, instance_name)
                log.info(f"DRY RUN: No files were actually processed. Check {report_file} for details.")
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
                    for _, plex_files, radarr_file, _ in confirmed_files:
                        for file in plex_files:
                            if file != radarr_file and file.exists():
                                log.info(str(file))
            else:
                log.info(f"No files confirmed for processing for Radarr instance: {instance_name}")
    
    except Exception as e:
        log.error(f"An error occurred during the process: {str(e)}")
    
    log.info("Duplicate file management process completed")

if __name__ == "__main__":
    main(args.dry_run)