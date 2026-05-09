import base64
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization, hashes
from datetime import date, datetime as dt, timedelta
from dotenv import load_dotenv
import numpy as np
import os
import pandas as pd
import pytz
import requests
import time
import warnings

warnings.filterwarnings("ignore")
load_dotenv()
KALSHI_API_KEY_ID = os.getenv("KALSHI_API_KEY")
PRIVATE_KEY_PATH = os.getenv("KALSHI_KEY_PATH")
SPORTS_API_KEY = os.getenv("ODDS_API_KEY")

DUPLICATE_PATH = "/Users/trevor/trevorscholz1/daily_lockz/models/placed.csv"
EDGE = 0.02
COUNT = 4


def get_active_sports():
    sports = []
    response = requests.get(
        f"https://api.the-odds-api.com/v4/sports/?apiKey={SPORTS_API_KEY}"
    )
    data = response.json()
    for sport in data:
        try:
            _ = sport["key"]
            _ = sport["active"]
        except:
            print(f"ERROR: {sport}")
            continue

        if "winner" in sport["key"] or not sport["active"]:
            print(f"SKIPPED SPORT: {sport['key']}")
            continue
        else:
            sports.append(sport["key"])
    return sports


def fetch_odds(sport):
    est_zone = pytz.timezone("US/Eastern")
    est_now = dt.now(est_zone)
    time_limit = est_now + timedelta(days=7)
    utc_zone = pytz.timezone("UTC")
    utc_time = time_limit.astimezone(utc_zone)

    commence_limit = utc_time.strftime("%Y-%m-%dT%H:%M:%SZ")

    response = requests.get(
        f"https://api.the-odds-api.com/v4/sports/{sport}/odds/",
        params={
            "apiKey": SPORTS_API_KEY,
            "bookmakers": "pinnacle,fliff,kalshi",
            "markets": "h2h,spreads,totals",
            "includeSids": "true",
            "commenceTimeTo": commence_limit,
        },
    )

    return response.json()


def convert_odds(prob):
    if prob >= 0.5:
        odds = -100 * prob / (1 - prob)
    else:
        odds = 100 * (1 - prob) / prob
    return round(odds)


def convert_time(utc):
    utc_time = dt.strptime(utc, "%Y-%m-%dT%H:%M:%SZ")

    utc_zone = pytz.timezone("UTC")
    utc_time = utc_zone.localize(utc_time)

    est_zone = pytz.timezone("US/Eastern")
    est_time = utc_time.astimezone(est_zone)

    now_est = dt.now(est_zone)
    is_today = est_time.date() == now_est.date()

    return est_time, is_today


def is_duplicate(sport, team, type, time, book):
    placed = pd.read_csv(DUPLICATE_PATH)
    placed["date_placed"] = pd.to_datetime(
        placed["date_placed"], errors="coerce"
    ).dt.date

    mask = (
        (placed["sport"] == sport)
        & (placed["team"] == team)
        & (placed["type"] == type)
        & (placed["time"] == time)
        & (placed["book"] == book)
    )

    return mask.any()


def save_bet(sport, team, type, time, book):
    data = {
        "sport": [sport],
        "team": [team],
        "type": [type],
        "time": [time],
        "date_placed": [date.today()],
        "book": [book],
    }
    placed = pd.DataFrame(data=data)
    placed.to_csv(DUPLICATE_PATH, mode="a", header=False, index=False)


def clean_duplicates():
    cutoff = date.today() - timedelta(days=7)

    placed = pd.read_csv(DUPLICATE_PATH)
    placed["date_placed"] = pd.to_datetime(
        placed["date_placed"], errors="coerce"
    ).dt.date
    placed = placed[placed["date_placed"] >= cutoff]
    placed.to_csv(DUPLICATE_PATH, index=False)


def remove_juice(outcomes, is_kalshi):
    outcomes_df = pd.DataFrame(outcomes)
    probs = 1 / outcomes_df["price"]
    if is_kalshi:
        fair_probs = probs
    else:
        fair_probs = probs / probs.sum()
    return outcomes_df.assign(fair_prob=fair_probs, raw=probs)


def game_odds(game):
    game_odds = pd.DataFrame(
        columns=[
            "id",
            "sport",
            "h_team",
            "a_team",
            "book",
            "h_ml",
            "a_ml",
            "d_ml",
            "h_spread",
            "a_spread",
            "spreads_pt",
            "over",
            "under",
            "totals_pt",
            "time",
        ]
    )
    index = 0

    h_team = game["home_team"]
    a_team = game["away_team"]

    for book in game["bookmakers"]:
        game_odds.at[index, "id"] = game["id"]
        game_odds.at[index, "sport"] = game["sport_key"]
        game_odds.at[index, "h_team"] = h_team
        game_odds.at[index, "a_team"] = a_team
        game_odds.at[index, "time"] = game["commence_time"]

        game_odds.at[index, "book"] = book["key"]
        for market in book["markets"]:
            if market["key"] == "h2h":
                outcomes = remove_juice(
                    market["outcomes"], True if book["key"] == "kalshi" else False
                )
                home_row = outcomes[outcomes["name"] == h_team].iloc[0]
                away_row = outcomes[outcomes["name"] == a_team].iloc[0]
                if len(outcomes[outcomes["name"] == "Draw"]) > 0:
                    draw_row = outcomes[outcomes["name"] == "Draw"].iloc[0]
                else:
                    draw_row = None
                game_odds.at[index, "h_ml"] = home_row["fair_prob"]
                game_odds.at[index, "a_ml"] = away_row["fair_prob"]
                game_odds.at[index, "d_ml"] = (
                    draw_row["fair_prob"] if draw_row is not None else np.nan
                )

                game_odds.at[index, "h_ml_raw"] = home_row["raw"]
                game_odds.at[index, "a_ml_raw"] = away_row["raw"]
                game_odds.at[index, "d_ml_raw"] = (
                    draw_row["raw"] if draw_row is not None else np.nan
                )

                if book["key"] == "kalshi":
                    game_odds.at[index, "h_ml_sid"] = home_row["sid"]
                    game_odds.at[index, "a_ml_sid"] = away_row["sid"]
                    game_odds.at[index, "d_ml_sid"] = (
                        draw_row["sid"] if draw_row is not None else np.nan
                    )

            if market["key"] == "spreads":
                outcomes = remove_juice(
                    market["outcomes"], True if book["key"] == "kalshi" else False
                )
                home_row = outcomes[outcomes["name"] == h_team].iloc[0]
                away_row = outcomes[outcomes["name"] == a_team].iloc[0]
                game_odds.at[index, "h_spread"] = home_row["fair_prob"]
                game_odds.at[index, "a_spread"] = away_row["fair_prob"]
                game_odds.at[index, "spreads_pt"] = home_row["point"]

                game_odds.at[index, "h_spread_raw"] = home_row["raw"]
                game_odds.at[index, "a_spread_raw"] = away_row["raw"]

                if book["key"] == "kalshi":
                    game_odds.at[index, "h_spread_sid"] = home_row["sid"]
                    game_odds.at[index, "a_spread_sid"] = away_row["sid"]

            if market["key"] == "totals":
                outcomes = remove_juice(
                    market["outcomes"], True if book["key"] == "kalshi" else False
                )
                over_row = outcomes[outcomes["name"] == "Over"].iloc[0]
                under_row = outcomes[outcomes["name"] == "Under"].iloc[0]
                game_odds.at[index, "over"] = over_row["fair_prob"]
                game_odds.at[index, "under"] = under_row["fair_prob"]
                game_odds.at[index, "totals_pt"] = over_row["point"]

                game_odds.at[index, "over_raw"] = over_row["raw"]
                game_odds.at[index, "under_raw"] = under_row["raw"]

                if book["key"] == "kalshi":
                    game_odds.at[index, "over_sid"] = over_row["sid"]
                    game_odds.at[index, "under_sid"] = under_row["sid"]

        index += 1
    return game_odds


def fliff_place_bet(sport, team, type, point, odds, time):
    if not is_duplicate(sport, team, type, time, "fliff"):
        est, _ = convert_time(time)
        print("\n*", sport, team, type, point, odds, est, "*\n")
        save_bet(sport, team, type, time, "fliff")
    else:
        print("SKIPPED DUPLICATE", team, type)


def kalshi_place_order(kalshi, ticker, raw_price, team, type):
    def match_kalshi_price(ticker, raw_price):
        response = requests.get(
            f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
        )
        data = response.json()
        market = data["market"]
        kalshi_price = float(market["yes_ask_dollars"])
        print(kalshi_price, raw_price, team)
        if abs(kalshi_price - float(raw_price)) <= (EDGE / 2):
            return True
        else:
            return False

    def load_private_key(key_path):
        with open(key_path, "rb") as f:
            return serialization.load_pem_private_key(
                f.read(), password=None, backend=default_backend()
            )

    def create_signature(private_key, timestamp, method, path):
        path_without_query = path.split("?")[0]
        message = f"{timestamp}{method}{path_without_query}".encode("utf-8")
        signature = private_key.sign(
            message,
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.DIGEST_LENGTH
            ),
            hashes.SHA256(),
        )
        return base64.b64encode(signature).decode("utf-8")

    def post(
        private_key,
        api_key_id,
        path,
        payload,
        base_url="https://api.elections.kalshi.com",
    ):
        timestamp = str(int(dt.now().timestamp() * 1000))
        signature = create_signature(private_key, timestamp, "POST", path)

        headers = {
            "KALSHI-ACCESS-KEY": api_key_id,
            "KALSHI-ACCESS-SIGNATURE": signature,
            "KALSHI-ACCESS-TIMESTAMP": timestamp,
            "Content-Type": "application/json",
        }
        return requests.post(base_url + path, json=payload, headers=headers)

    if not is_duplicate(kalshi["sport"], team, type, kalshi["time"], "kalshi"):
        if not match_kalshi_price(ticker, raw_price):
            return

        payload = {
            "ticker": ticker,
            "side": "yes",
            "action": "buy",
            "count": COUNT,
            "yes_price": int(raw_price * 100),
        }

        private_key = load_private_key(PRIVATE_KEY_PATH)
        response = post(
            private_key,
            KALSHI_API_KEY_ID,
            "/trade-api/v2/portfolio/orders",
            payload=payload,
        )
        print("\n*", response.json(), "*\n")
        save_bet(kalshi["sport"], team, type, kalshi["time"], "kalshi")
    else:
        print("SKIPPED DUPLICATE", team, type)


def find_value(game_odds):
    if len(game_odds) < 1 or game_odds.empty:
        return

    sharp = game_odds[game_odds["book"] == "pinnacle"]
    if sharp.empty:
        return
    else:
        sharp = sharp.iloc[0]

    sport = game_odds["sport"][0]
    h_team = game_odds["h_team"][0]
    a_team = game_odds["a_team"][0]
    time = game_odds["time"][0]

    h_ml_sharp = sharp["h_ml"]
    a_ml_sharp = sharp["a_ml"]
    d_ml_sharp = sharp["d_ml"]

    h_spread_sharp = sharp["h_spread"]
    a_spread_sharp = sharp["a_spread"]

    over_sharp = sharp["over"]
    under_sharp = sharp["under"]

    fliff = game_odds[game_odds["book"] == "fliff"]
    if not fliff.empty:
        fliff = fliff.iloc[0]

        if fliff["h_ml"] < (h_ml_sharp - EDGE):
            fliff_place_bet(
                sport, h_team, "ML", 0, convert_odds(fliff["h_ml_raw"]), time
            )
        if fliff["a_ml"] < (a_ml_sharp - EDGE):
            fliff_place_bet(
                sport, a_team, "ML", 0, convert_odds(fliff["a_ml_raw"]), time
            )
        if fliff["d_ml"] < (d_ml_sharp - EDGE):
            fliff_place_bet(
                sport,
                f"{h_team}***Draw",
                "ML",
                0,
                convert_odds(fliff["d_ml_raw"]),
                time,
            )

        if (
            fliff["h_spread"] < (h_spread_sharp - EDGE)
            and fliff["spreads_pt"] == sharp["spreads_pt"]
        ):
            fliff_place_bet(
                sport,
                h_team,
                "Spread",
                fliff["spreads_pt"],
                convert_odds(fliff["h_spread_raw"]),
                time,
            )
        if (
            fliff["a_spread"] < (a_spread_sharp - EDGE)
            and fliff["spreads_pt"] == sharp["spreads_pt"]
        ):
            fliff_place_bet(
                sport,
                a_team,
                "Spread",
                fliff["spreads_pt"],
                convert_odds(fliff["a_spread_raw"]),
                time,
            )

        if (
            fliff["over"] < (over_sharp - EDGE)
            and fliff["totals_pt"] == sharp["totals_pt"]
        ):
            fliff_place_bet(
                sport,
                h_team,
                "Over",
                fliff["totals_pt"],
                convert_odds(fliff["over_raw"]),
                time,
            )
        if (
            fliff["under"] < (under_sharp - EDGE)
            and fliff["totals_pt"] == sharp["totals_pt"]
        ):
            fliff_place_bet(
                sport,
                h_team,
                "Under",
                fliff["totals_pt"],
                convert_odds(fliff["under_raw"]),
                time,
            )

    kalshi = game_odds[game_odds["book"] == "kalshi"]
    if not kalshi.empty:
        kalshi = kalshi.iloc[0]

        if kalshi["h_ml"] < (h_ml_sharp - EDGE):
            kalshi_place_order(
                kalshi,
                kalshi["h_ml_sid"],
                round(kalshi["h_ml_raw"], 2),
                h_team,
                "ML",
            )
        if kalshi["a_ml"] < (a_ml_sharp - EDGE):
            kalshi_place_order(
                kalshi,
                kalshi["a_ml_sid"],
                round(kalshi["a_ml_raw"], 2),
                a_team,
                "ML",
            )
        if kalshi["d_ml"] < (d_ml_sharp - EDGE):
            kalshi_place_order(
                kalshi,
                kalshi["d_ml_sid"],
                round(kalshi["d_ml_raw"], 2),
                f"{h_team}***Draw",
                "ML",
            )


def main():
    ACTIVE_SPORTS = get_active_sports()

    for sport in ACTIVE_SPORTS:
        time.sleep(0.7)

        GAME_ODDS = None
        GAME_ODDS = fetch_odds(sport)

        print(f"{sport}: {len(GAME_ODDS)} games")
        if GAME_ODDS is not None:
            for game in GAME_ODDS:
                if type(game) is str:
                    print(GAME_ODDS)
                else:
                    game_time = game["commence_time"]
                    _, live = convert_time(game_time)
                    if not live:
                        odds = game_odds(game)
                        find_value(odds)
    clean_duplicates()


if __name__ == "__main__":
    main()
