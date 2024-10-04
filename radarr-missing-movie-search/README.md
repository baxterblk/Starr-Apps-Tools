Here’s a detailed `README.md` and `requirements.txt` file based on your project setup:

### `README.md`

```md
# Radarr Missing Movie Auto Searcher

This Python script automatically searches for missing movies in multiple Radarr instances periodically, based on the configuration in an `.env` file. It retrieves missing (monitored) movies and triggers Radarr to search for those movies in batches.

## Features

- **Multiple Radarr Instance Support**: Configure multiple Radarr instances and automate missing movie searches for all of them.
- **Batch Processing**: Handle missing movies in batches to optimize search requests.
- **Retry Capability**: Automatically retries failed searches with exponential back-off, then resets after reaching the configured retry limit.
- **Logging**: Logs all activities to help monitor the search process and any issues that arise.
- **Scheduled Cleanup**: Periodically clears the list of searched movie IDs to allow re-searching after a defined period.

## Getting Started

### Prerequisites

1. Install Python (version 3.7 or higher)
2. Clone this repository:

```bash
git clone https://git.blakbox.vip/baxterblk/Starr-Apps-Tools.git
cd Starr-Apps-Tools/src/branch/main/radarr-missing-movie-search/
```

3. Ensure you have API keys for your Radarr instances.

### Installation

1. Create a virtual environment (optional but recommended):
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows use: venv\Scripts\activate
   ```

2. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Copy `.env.example` to create your configuration as `.env`:
   ```bash
   cp .env.example .env
   ```

4. Edit the `.env` file to fit your Radarr settings and movie search preferences:
   ```bash
   nano .env  # Or use any text editor to open the file
   ```

### Environment Configuration (.env)

The `.env` file contains configuration for your Radarr instances and script behavior.

Here is an example `.env` file layout:

```ini
# Instance 1
RADARR_URL_1=http://localhost:7878
RADARR_API_KEY_1=your_api_key_here

# Instance 2
RADARR_URL_2=http://localhost:7879
RADARR_API_KEY_2=your_api_key_here

# Additional instances can be added following the above pattern

# Script settings
SEARCH_INTERVAL=600    # 10 minutes between searches (in seconds)
BATCH_SIZE=8           # Number of movie IDs to search at once
MAX_RETRIES=5          # Maximum number of retries before clearing search attempts
CLEAR_SEARCHED_IDS_INTERVAL=86400  # Time to reset searched movie IDs (default 24 hours)
```

- **`RADARR_URL_1`, `RADARR_API_KEY_1`**: Specify the URL and API key for the first Radarr instance.
- **`SEARCH_INTERVAL`**: Interval between search cycles or batches (in seconds).
- **`BATCH_SIZE`**: Number of movie IDs to search in each batch.
- **`MAX_RETRIES`**: Maximum attempts before reset in the event of errors.
- **`CLEAR_SEARCHED_IDS_INTERVAL`**: Time (in seconds) after which the previously searched movie IDs will be cleared.

### Usage

1. To run the script, execute the following command:
   ```bash
   python movie-search.py
   ```

2. The script will automatically start searching for missing movies in all configured Radarr instances and log the operations.

### Crontab (Optional)

To run this script automatically at system startup or at regular intervals, you can add a crontab entry:

```bash
# Edit crontab
crontab -e

# Add the following line to run the script every day at 2 AM
0 2 * * * cd /path/to/Starr-Apps-Tools/src/branch/main/radarr-missing-movie-search && /path/to/bin/python movie-search.py
```

Make sure to replace `/path/to/` with your actual folder paths.

## Logging

The script outputs log messages in the console at various points to indicate its progress or error conditions. Logs include information about:

- Which Radarr instance is being processed.
- Number of unsearched missing movies found.
- Success or failure when triggering a movie search.
- Retry attempts in case of errors.
  
## Contributing

Feel free to fork this repository, create issues, or submit pull requests.

### Example Contribution

```bash
# Make your changes by forking the repo, then create a pull request

# Ensure your code follows Python best practices, and format using `black` or `flake8`.

# Run tests before submitting a PR:
# python3 -m unittest discover -s tests
```

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
```

### `requirements.txt`

```txt
requests==2.28.2
python-dotenv==1.0.0
```

### Explanation

- **`requests`**: The Python library used to handle networking and HTTP requests to the Radarr API.
- **`python-dotenv`**: This package is used to load configuration variables from a `.env` file into the environment.

### Notes:
- Replace the placeholder in the `.env` for `your_api_key_here` with the actual API keys for your instances.
- The repository URL in the `README.md` links should work as per your organization's Git setup. 

Now you can place both the `README.md` and `requirements.txt` files into your repository under the `radarr-missing-movie-search/` folder.