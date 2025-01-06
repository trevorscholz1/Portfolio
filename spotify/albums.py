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

try:
    os.remove('./data/charts/listeners.html')
    print('Deleted current listeners')
except:
    pass

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

def scrape_artist(standings_file):
    with open(standings_file, 'r') as f:
        html = f.read()
    soup = BeautifulSoup(html, features="lxml")
    artist_table = pd.read_html(str(soup), attrs={'class':'addpos sortable'})[0]
    artist_list = artist_table['Artist']
    return artist_list

async def main():
    await scrape_charts()

if __name__ == "__main__":
    asyncio.run(main())

filepath = os.path.join(CHARTS, 'listeners.html')
artists = scrape_artist(filepath)
print(artists)