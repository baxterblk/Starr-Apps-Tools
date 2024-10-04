# Radarr Missing Movie Search

This script automates the process of searching for missing movies in one or more Radarr instances. It periodically checks for missing movies and triggers searches for them in batches.

## Features

- Supports multiple Radarr instances
- Fetches missing movies using pagination
- Searches for movies in batches to avoid overwhelming the system
- Implements error handling and retries
- Clears searched movie IDs periodically to ensure all movies are rechecked
- Uses environment variables for configuration

## Requirements

- Python 3.6+
- Radarr instance(s) with API access

## Installation

1. Clone the repository:
   ```
   git clone https://git.blakbox.vip/baxterblk/Starr-Apps-Tools.git
   ```

2. Navigate to the project directory:
   ```
   cd Starr-Apps-Tools/radarr-missing-movie-search
   ```

3. Install the required packages:
   ```
   pip install -r requirements.txt
   ```

4. Copy the `.env.example` file to `.env` and update it with your Radarr instance details:
   ```
   cp .env.example .env
   ```

## Configuration

Update the `.env` file with your Radarr instance details:

```
RADARR_URL_1=http://localhost:7878
RADARR_API_KEY_1=your_api_key_here
RADARR_URL_2=http://localhost:7879
RADARR_API_KEY_2=your_second_api_key_here
MAX_RETRIES=5
CLEAR_SEARCHED_IDS_INTERVAL=86400
```

You can add more Radarr instances by adding additional URL and API key pairs.

## Usage

Run the script using Python:

```
python movie-search.py
```

The script will continuously run, checking for missing movies and triggering searches at the specified interval.

## Customization

You can modify the following variables in the script to adjust its behavior:

- `SEARCH_INTERVAL`: Time between search cycles (in seconds)
- `BATCH_SIZE`: Number of movies to search for in each batch
- `MAX_RETRIES`: Maximum number of retries when an error occurs
- `CLEAR_SEARCHED_IDS_INTERVAL`: Time interval to clear the list of searched movie IDs (in seconds)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE).