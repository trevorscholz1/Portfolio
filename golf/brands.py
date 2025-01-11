import asyncio
from bs4 import BeautifulSoup # type: ignore
import pandas as pd # type: ignore
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout # type: ignore
import time # type: ignore

async def get_html(url, selector, sleep=5, retries=3):
    html = None
    for i in range(1, retries + 1):
        time.sleep(sleep * i)
        try:
            async with async_playwright() as p:
                browser = await p.webkit.launch()
                page = await browser.new_page()
                await page.goto(url)
                print(await page.title())
                html = await page.inner_html(selector)
        except PlaywrightTimeout:
            print(f"Timeout error on {url}")
            continue
        else:
            break
    return html

BRANDS = []
async def main():
    html = await get_html('https://en.wikipedia.org/wiki/List_of_golf_equipment_manufacturers', '#bodyContent')
    soup = BeautifulSoup(html, features='lxml')
    brands_page = soup.find_all('ul')[0]
    brand_links = brands_page.find_all('li')
    for brand in brand_links:
        if brand:
            text = brand.find('a').text
            BRANDS.append(text)

asyncio.run(main())
BRANDS = pd.DataFrame(BRANDS)
BRANDS.to_csv('~/trevorAppsWebsites/HoleInOne/HoleInOne/brands.csv')
