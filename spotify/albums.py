import asyncio
from bs4 import BeautifulSoup
import datetime
from dotenv import load_dotenv
import os
import pandas as pd
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials

script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

# try:
#     os.remove('./data/charts/listeners.html')
#     print('Deleted current listeners')
# except:
#     pass

DATA_DIR = 'data'
CHARTS = os.path.join(DATA_DIR, 'charts')
artists = []

async def get_html(url, selector):
    html = None
    try:
        async with async_playwright() as p:
            browser = await p.webkit.launch()
            page = await browser.new_page()
            await page.goto(url)
            print(await page.title())
            html = await page.inner_html(selector)
    except PlaywrightTimeout:
        print(f"Timeout error on {url}")
    return html

async def scrape_charts():
    url = "https://kworb.net/spotify/listeners.html"
    save_path = os.path.join(CHARTS, url.split('/')[-1])
    if not os.path.exists(save_path):
        html = await get_html(url, '.addpos')
        with open(save_path, 'w+') as f:
            f.write(html)

async def scrape_artist(standings_file):
    with open(standings_file, 'r') as f:
        html = f.read()
    soup = BeautifulSoup(html, features="lxml")
    links = soup.find_all('a')
    hrefs = [l.get('href') for l in links]
    charts = [f"https://kworb.net{l}" for l in hrefs if l and 'artist' in l and 'html' in l]
    for url in charts:
        artist = url.split('/')[-1]
        artist = artist.split('_')[0]
        artists.append(artist)

async def main():
    await scrape_charts()
    filepath = os.path.join(CHARTS, 'listeners.html')
    await scrape_artist(filepath)

if __name__ == "__main__":
    asyncio.run(main())

load_dotenv()
SPOTIPY_CLIENT_ID=os.getenv('CLIENT_ID')
SPOTIPY_CLIENT_SECRET=os.getenv('CLIENT_SECRET')

credentials = SpotifyClientCredentials(client_id=SPOTIPY_CLIENT_ID, client_secret=SPOTIPY_CLIENT_SECRET)
sp = spotipy.Spotify(client_credentials_manager=credentials)

def get_artist_albums(artist_id):
    albums = []
    results = sp.artist_albums(artist_id, album_type='album', limit=50)
    albums.extend(results['items'])
    
    while results['next']:
        results = sp.next(results)
        albums.extend(results['items'])
    
    artist_info = sp.artist(artist_id)
    artist_name = artist_info['name']
    artist_popularity = artist_info['popularity']
    artist_image_url = artist_info['images'][0]['url'] if artist_info['images'] else None

    return albums, artist_name, artist_popularity, artist_image_url

def get_album_tracks(album_id):
    results = sp.album_tracks(album_id)

    album_info = sp.album(album_id)
    album_name = album_info['name']
    album_release_date = album_info['release_date']
    album_image_url = album_info['images'][0]['url'] if album_info['images'] else None

    tracks = results['items']
    track_ids = [track['id'] for track in tracks]
    track_names = [track['name'] for track in tracks]
    track_urls = [track['external_urls']['spotify'] for track in tracks]
    track_uris = [track['uri'] for track in tracks]

    features = sp.audio_features(track_ids)
    return album_name, album_release_date, album_image_url, track_names, track_urls, track_uris, features

#############################
artist_ids = artists[150:200]
print('150-200')
#############################

for i, artist_id in enumerate(artist_ids):
    try:
        songs_df = pd.DataFrame()
        artist_albums, artist_name, artist_popularity, artist_image_url = get_artist_albums(artist_id)

        for album in artist_albums:
            album_id = album['id']
            album_name, album_release_date, album_image_url, track_names, track_urls, track_uris, features = get_album_tracks(album_id)
            
            features_df = pd.DataFrame(features)

            features_df['album_name'] = album_name
            features_df['album_release_date'] = album_release_date
            features_df['album_image_url'] = album_image_url

            features_df['artist_name'] = artist_name
            features_df['artist_popularity'] = artist_popularity
            features_df['artist_image_url'] = artist_image_url
            
            features_df['track_name'] = track_names
            features_df['track_url'] = track_urls
            features_df['track_uri'] = track_uris
            
            audio_features = ['acousticness', 'danceability', 'duration_ms', 'energy', 'instrumentalness', 'key', 'liveness', 'loudness', 'mode', 'speechiness', 'tempo', 'time_signature', 'valence']
            features_df = features_df[audio_features + ['album_name', 'album_release_date', 'album_image_url', 'artist_name', 'artist_popularity', 'artist_image_url', 'track_name', 'track_url', 'track_uri']]
            
            scaler = StandardScaler()
            scaled_features = scaler.fit_transform(features_df[audio_features])
            
            kmeans_emotions = KMeans(n_clusters=5, random_state=0)
            features_df['cluster'] = kmeans_emotions.fit_predict(scaled_features)
            
            cluster_names = {0: 'Mixed Emotions (Anger/Sadness)', 1: 'Party', 2: 'Happy/Confident', 3: 'Euphoric', 4: 'Gym Songs'}
            features_df['cluster_name'] = features_df['cluster'].map(cluster_names)
            
            kmeans_seasons = KMeans(n_clusters=4, random_state=0)
            features_df['season_cluster'] = kmeans_seasons.fit_predict(scaled_features)
            
            season_names = {0: 'Spring', 1: 'Summer', 2: 'Fall', 3: 'Winter'}
            features_df['season_name'] = features_df['season_cluster'].map(season_names)
            
            songs_df = pd.concat([songs_df, features_df], ignore_index=True)

        songs_df.sort_values(by=['cluster','album_name'], inplace=True, ignore_index=True)
        songs_df.drop_duplicates('track_name', keep='first', inplace=True)
        songs_df['last_updated'] = datetime.date.today()

        print(f"{i+1} out of 50 complete | {artist_name}")

        if not os.path.isfile('/Users/trevor/trevorAppsWebsites/ClusterJam/clusters.csv'):
            songs_df.to_csv('/Users/trevor/trevorAppsWebsites/ClusterJam/clusters.csv', index=False)
        else:
            songs_df.to_csv('/Users/trevor/trevorAppsWebsites/ClusterJam/clusters.csv', mode='a', header=False, index=False)
    except Exception as error:
        print(error, artist_name)
        continue

final_csv = pd.read_csv('/Users/trevor/trevorAppsWebsites/ClusterJam/clusters.csv')

final_csv['duration_ms'] = final_csv['duration_ms'] / final_csv['duration_ms'].max()
final_csv['key'] = (final_csv['key'] + 1) / 12
final_csv['loudness'] = (final_csv['loudness'] + 60) / 60
final_csv['tempo'] = final_csv['tempo'] / final_csv['tempo'].max()
final_csv['time_signature'] = (final_csv['time_signature'] - 3) / 4

final_csv['last_updated'] = pd.to_datetime(final_csv['last_updated'])
cutoff_date = datetime.date.today() - datetime.timedelta(days=60)
final_csv = final_csv[final_csv['last_updated'].dt.date >= cutoff_date]

final_csv = final_csv.drop_duplicates(subset=['artist_name','track_name'], keep='last')
final_csv.to_csv('/Users/trevor/trevorAppsWebsites/ClusterJam/clusters.csv', index=False)
