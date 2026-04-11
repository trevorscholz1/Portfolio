import asyncio
from bs4 import BeautifulSoup
import io
import pandas as pd
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
from sklearn.cluster import KMeans
import time

pd.options.display.max_rows = 100


async def get_html(url, selector, sleep=5, retries=5):
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


def extract_price(all_prices):
    price = str(all_prices).split(" ")[0]
    return price


def format_numbers(num):
    num = str(num)
    if num.endswith("%"):
        num = num.split("%")[0]
        if num.startswith("+"):
            num = num.split("+")[-1]
    elif num.endswith("M"):
        num = float(num.split("M")[0]) * 1e6
    elif num.endswith("B"):
        num = float(num.split("B")[0]) * 1e9
    elif num.endswith("T"):
        num = float(num.split("T")[0]) * 1e12

    num = str(num).replace(",", "")
    num = str(num).replace("--", "0")
    return num


def make_table(html):
    soup = BeautifulSoup(html, features="lxml")
    df = pd.read_html(io.StringIO(str(soup)))[0]
    df = df.dropna(axis=0, how="all")
    df = df.dropna(axis=1, how="all")
    df = df.drop("52 Wk Range", axis=1)
    return df


def find_stocks(html):
    stocks = make_table(html)

    stocks["Price"] = stocks["Price"].apply(extract_price).apply(format_numbers)
    stocks["Change %"] = stocks["Change %"].apply(format_numbers)
    stocks["Volume"] = stocks["Volume"].apply(format_numbers)
    stocks["Avg Vol (3M)"] = stocks["Avg Vol (3M)"].apply(format_numbers)
    stocks["Market Cap"] = stocks["Market Cap"].apply(format_numbers)
    stocks["52 Wk Change %"] = stocks["52 Wk Change %"].apply(format_numbers)
    stocks["P/E Ratio (TTM)"] = stocks["P/E Ratio (TTM)"].apply(format_numbers)

    stocks_numbers = stocks[
        [
            "Price",
            "Change",
            "Change %",
            "Volume",
            "Avg Vol (3M)",
            "Market Cap",
            "P/E Ratio (TTM)",
            "52 Wk Change %",
        ]
    ]
    stocks_numbers = stocks_numbers.apply(pd.to_numeric)

    kmeans = KMeans(n_clusters=5, random_state=0).fit(stocks_numbers)
    stocks["signal"] = kmeans.labels_
    print(stocks[stocks["signal"] == 3])


def find_crypto(html):
    crypto = make_table(html)

    crypto["Price"] = crypto["Price"].apply(extract_price).apply(format_numbers)
    crypto["Change"] = crypto["Change"].apply(format_numbers)
    crypto["Change %"] = crypto["Change %"].apply(format_numbers)
    crypto["Volume"] = crypto["Volume"].apply(format_numbers)
    crypto["Volume In Currency (24hr)"] = crypto["Volume In Currency (24hr)"].apply(
        format_numbers
    )
    crypto["Total Volume All Currencies (24hr)"] = crypto[
        "Total Volume All Currencies (24hr)"
    ].apply(format_numbers)
    crypto["Circulating Supply"] = crypto["Circulating Supply"].apply(format_numbers)
    crypto["Market Cap"] = crypto["Market Cap"].apply(format_numbers)
    crypto["52 Wk Change %"] = crypto["52 Wk Change %"].apply(format_numbers)

    crypto_numbers = crypto[
        [
            "Price",
            "Change",
            "Change %",
            "Volume",
            "Volume In Currency (24hr)",
            "Total Volume All Currencies (24hr)",
            "Market Cap",
            "Circulating Supply",
            "52 Wk Change %",
        ]
    ]
    crypto_numbers = crypto_numbers.apply(pd.to_numeric)

    kmeans = KMeans(n_clusters=5, random_state=0).fit(crypto_numbers)
    crypto["signal"] = kmeans.labels_
    print(crypto[crypto["signal"] == 3])


async def main():
    s_html = await get_html(
        "https://finance.yahoo.com/markets/stocks/most-active/?start=0&count=100",
        ".tableContainer",
    )
    find_stocks(s_html)

    c_html = await get_html(
        "https://finance.yahoo.com/markets/crypto/most-active/?start=0&count=100",
        ".tableContainer",
    )
    find_crypto(c_html)


if __name__ == "__main__":
    asyncio.run(main())
