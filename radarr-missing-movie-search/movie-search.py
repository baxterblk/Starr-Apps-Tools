import requests
import time
import logging
from requests.exceptions import RequestException, HTTPError
from typing import List, Dict
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Radarr API configuration
RADARR_INSTANCES = [
    {
        "url": os.getenv("RADARR_URL_1", "http://localhost:7878"),
        "api_key": os.getenv("RADARR_API_KEY_1"),
    },
    {
        "url": os.getenv("RADARR_URL_2", "http://localhost:7879"),  # Example second instance
        "api_key": os.getenv("RADARR_API_KEY_2"),
    },
    # Add more instances as needed...
]

# Script settings
SEARCH_INTERVAL = 600  # 10 minutes in seconds
BATCH_SIZE = 8
MAX_RETRIES = int(os.getenv("MAX_RETRIES", 5))
CLEAR_SEARCHED_IDS_INTERVAL = int(os.getenv("CLEAR_SEARCHED_IDS_INTERVAL", 86400))  # 24 hours in seconds

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def get_missing_movies(instance: Dict) -> List[Dict]:
    """Retrieves a list of missing movies from a Radarr instance using pagination."""
    url = f"{instance['url']}/api/v3/wanted/missing"
    headers = {"X-Api-Key": instance['api_key']}
    params = {
        "pageSize": 1000,
        "sortKey": "title",
        "sortDirection": "ascending",
        "monitored": "true"
    }
    all_missing_movies = []

    try:
        while True:
            response = requests.get(url, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            data = response.json()

            all_missing_movies.extend(data['records'])

            if len(all_missing_movies) >= data['totalRecords']:
                break

            params['page'] = data['page'] + 1

        return all_missing_movies
    except HTTPError as http_err:
        logger.error(f"HTTP error occurred while fetching missing movies from {instance['url']}: {http_err}")
        if response.status_code == 401:
            logger.error("Unauthorized access. Please check your API key.")
        elif response.status_code == 404:
            logger.error("The specified endpoint was not found. Please check your Radarr API URL.")
        elif response.status_code >= 500:
            logger.error("Server error. The Radarr server might be experiencing issues.")
        raise
    except RequestException as e:
        logger.error(f"Error fetching missing movies from {instance['url']}: {e}")
        raise


def search_movies(instance: Dict, movie_ids: List[int]) -> bool:
    """Triggers a search for the specified movie IDs in a Radarr instance."""
    url = f"{instance['url']}/api/v3/command"
    headers = {"X-Api-Key": instance['api_key']}
    data = {"name": "moviesSearch", "movieIds": movie_ids}
    try:
        response = requests.post(url, headers=headers, json=data, timeout=10)
        response.raise_for_status()
        return True
    except HTTPError as http_err:
        logger.error(f"HTTP error occurred while searching for movies in {instance['url']}: {http_err}")
        if response.status_code == 401:
            logger.error("Unauthorized access. Please check your API key.")
        elif response.status_code == 404:
            logger.error("The specified endpoint was not found. Please check your Radarr API URL.")
        elif response.status_code >= 500:
            logger.error("Server error. The Radarr server might be experiencing issues.")
        return False
    except RequestException as e:
        logger.error(f"Error searching for movies in {instance['url']}: {e}")
        return False


def main():
    """Main function to execute the script."""
    searched_ids = {}  # Keep track of searched movie IDs for each instance
    retry_count = {}
    last_clear_time = {}

    for instance in RADARR_INSTANCES:
        searched_ids[instance['url']] = set()
        retry_count[instance['url']] = 0
        last_clear_time[instance['url']] = time.time()

    while True:
        for instance in RADARR_INSTANCES:
            try:
                missing_movies = get_missing_movies(instance)
                unsearched_ids = [
                    movie["id"] for movie in missing_movies if movie["id"] not in searched_ids[instance['url']]
                ]
                logger.info(f"Found {len(unsearched_ids)} unsearched missing movies in {instance['url']}.")

                if not unsearched_ids:
                    logger.info(f"No new missing movies to search for in {instance['url']}. Waiting for next cycle...")
                    time.sleep(SEARCH_INTERVAL)
                    continue

                for i in range(0, len(unsearched_ids), BATCH_SIZE):
                    batch_ids = unsearched_ids[i: i + BATCH_SIZE]
                    if search_movies(instance, batch_ids):
                        searched_ids[instance['url']].update(batch_ids)
                        logger.info(f"Searched for movies with IDs: {batch_ids} in {instance['url']}")
                    else:
                        logger.warning(f"Failed to search for batch: {batch_ids} in {instance['url']}")

                    if i + BATCH_SIZE < len(unsearched_ids):
                        logger.info(f"Waiting {SEARCH_INTERVAL} seconds before next batch in {instance['url']}...")
                        time.sleep(SEARCH_INTERVAL)

                # Clear searched_ids periodically
                if time.time() - last_clear_time[instance['url']] > CLEAR_SEARCHED_IDS_INTERVAL:
                    logger.info(f"Clearing searched IDs for {instance['url']}...")
                    searched_ids[instance['url']].clear()
                    last_clear_time[instance['url']] = time.time()

                logger.info(f"Completed search cycle for {instance['url']}. Waiting {SEARCH_INTERVAL} seconds for next cycle...")
                time.sleep(SEARCH_INTERVAL)
                retry_count[instance['url']] = 0  # Reset retry count on success

            except Exception as e:
                logger.error(f"An unexpected error occurred in {instance['url']}: {e}")
                retry_count[instance['url']] += 1
                wait_time = min(SEARCH_INTERVAL * (2 ** retry_count[instance['url']]), 3600)  # Cap at 1 hour
                if retry_count[instance['url']] >= MAX_RETRIES:
                    logger.error(f"Max retries reached for {instance['url']}. Clearing searched IDs and resetting retry count.")
                    searched_ids[instance['url']].clear()
                    retry_count[instance['url']] = 0
                logger.info(f"Retrying {instance['url']} in {wait_time} seconds...")
                time.sleep(wait_time)


if __name__ == "__main__":
    main()