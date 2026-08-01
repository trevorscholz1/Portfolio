import base64
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization, hashes
import datetime
from dotenv import load_dotenv
import os
import pandas as pd
import requests
from urllib.parse import urlparse

load_dotenv()
KALSHI_API_KEY_ID = os.getenv("KALSHI_API_KEY")
SPORTS_API_KEY_ID = os.getenv("SGO_DEMO_KEY")
PRIVATE_KEY_PATH = os.getenv("KALSHI_KEY_PATH")
BASE_URL = "https://external-api.kalshi.com/trade-api/v2"


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


def post(private_key, api_key_id, path, payload, base_url=BASE_URL):
    timestamp = str(int(datetime.datetime.now().timestamp() * 1000))
    sign_path = urlparse(base_url + path).path
    signature = create_signature(private_key, timestamp, "POST", sign_path)

    headers = {
        "KALSHI-ACCESS-KEY": api_key_id,
        "KALSHI-ACCESS-SIGNATURE": signature,
        "KALSHI-ACCESS-TIMESTAMP": timestamp,
        "Content-Type": "application/json",
    }

    return requests.post(base_url + path, json=payload, headers=headers)


def convert(odds):
    odds = float(odds)

    if odds > 0:
        return 100 / (odds + 100)
    else:
        return abs(odds) / (abs(odds) + 100)


def get_kalshi_prices(league_id):
    url = f"{BASE_URL}/events?status=open&with_nested_markets=True&series_ticker={league_id}"
    response = requests.get(url)
    data = response.json()["events"]

    prices = pd.DataFrame(
        columns=[
            "team0_ticker",
            "team0_code",
            "team0_name",
            "team0_side",
            "team0_price",
            "team1_ticker",
            "team1_code",
            "team1_name",
            "team1_side",
            "team1_price",
        ]
    )
    for item in data[::-1]:
        team0_bid = float(item["markets"][0]["yes_ask_dollars"])
        team1_bid = float(item["markets"][1]["yes_ask_dollars"])

        game = pd.DataFrame(
            [
                {
                    "team0_ticker": item["markets"][0]["ticker"],
                    "team0_code": item["markets"][0]["ticker"].split("-")[-1],
                    "team0_name": item["markets"][0]["yes_sub_title"],
                    "team0_side": "bid",
                    "team0_price": team0_bid,
                    "team1_ticker": item["markets"][1]["ticker"],
                    "team1_code": item["markets"][1]["ticker"].split("-")[-1],
                    "team1_name": item["markets"][1]["yes_sub_title"],
                    "team1_side": "bid",
                    "team1_price": team1_bid,
                }
            ]
        )
        prices = pd.concat([prices, game], ignore_index=True)
    return prices


def get_sports_odds(league_id):
    url = f"https://api.sportsgameodds.com/v2/events?leagueID={league_id}&startsBefore=2026-08-01T00:00:00Z&oddsAvailable=true&oddID=points-home-game-ml-home&includeOpposingOdds=true&started=false"
    headers = {"X-Api-Key": SPORTS_API_KEY_ID}
    response = requests.get(url, headers=headers)
    return response.json()


def main():
    bets = pd.DataFrame(columns=["ticker", "side", "price"])
    sports = [
        ["MLB", "KXMLBGAME"],
        ["NBA", "KXNBAGAME"],
        ["NCAAB", "KXNCAAMBGAME"],
        ["NCAAF", "KXNCAAFGAME"],
        ["NFL", "KXNFLGAME"],
        ["NHL", "KXNHLGAME"],
    ]

    for sport in sports:
        odds_data = get_sports_odds(sport[0])
        kalshi_prices = get_kalshi_prices(sport[1])

        GAMES_MATCHED = 0

        for matchup in odds_data["data"]:
            game = None
            try:
                h_team, a_team = (
                    matchup["teams"]["home"]["names"]["short"],
                    matchup["teams"]["away"]["names"]["short"],
                )
            except:
                h_team, a_team = "", ""
            try:
                h_team_full, a_team_full = (
                    matchup["teams"]["home"]["names"]["medium"],
                    matchup["teams"]["away"]["names"]["medium"],
                )
            except:
                h_team_full, a_team_full = "", ""
            if sport[0] == "NCAAB" or sport[0] == "NCAAF":
                h_team_full = h_team_full.replace("State", "St.")
                a_team_full = a_team_full.replace("State", "St.")
            print(f"{a_team_full} ({a_team}), {h_team_full} ({h_team})")

            for _, row in kalshi_prices.iterrows():
                if (h_team == row["team0_code"] and a_team == row["team1_code"]) or (
                    h_team == row["team1_code"] and a_team == row["team0_code"]
                ):
                    print(f"GAME FOUND: {a_team} at {h_team}")
                    GAMES_MATCHED += 1
                    if h_team == row["team0_code"]:
                        home_num, away_num = 0, 1
                    else:
                        home_num, away_num = 1, 0
                    game = row
                    break
                elif (
                    h_team_full == row["team0_name"]
                    and a_team_full == row["team1_name"]
                ) or (
                    h_team_full == row["team1_name"]
                    and a_team_full == row["team0_name"]
                ):
                    print(f"GAME FOUND: {a_team_full} at {h_team_full}")
                    GAMES_MATCHED += 1
                    if h_team_full == row["team0_name"]:
                        home_num, away_num = 0, 1
                    else:
                        home_num, away_num = 1, 0
                    game = row
                    break

            if game is None:
                print(f"Skipped {a_team} vs {h_team}")
                continue

            fair_home_odds = convert(
                matchup["odds"]["points-home-game-ml-home"]["fairOdds"]
            )
            fair_away_odds = convert(
                matchup["odds"]["points-away-game-ml-away"]["fairOdds"]
            )
            home_price = game[f"team{home_num}_price"]
            away_price = game[f"team{away_num}_price"]

            print(fair_home_odds, home_price)
            print(fair_away_odds, away_price)
            if (home_price + 0.02) < fair_home_odds:
                side = game[f"team{home_num}_side"]
                bet = pd.DataFrame(
                    [
                        {
                            "ticker": (game[f"team{home_num}_ticker"]),
                            "side": side,
                            "price": home_price,
                        }
                    ]
                )
                bets = pd.concat(
                    [bets, bet],
                    ignore_index=True,
                )
            if (away_price + 0.02) < fair_away_odds:
                side = game[f"team{away_num}_side"]
                bet = pd.DataFrame(
                    [
                        {
                            "ticker": (game[f"team{away_num}_ticker"]),
                            "side": side,
                            "price": away_price,
                        }
                    ]
                )
                bets = pd.concat(
                    [bets, bet],
                    ignore_index=True,
                )

        print(len(odds_data["data"]), GAMES_MATCHED)
        print()

    private_key = load_private_key(PRIVATE_KEY_PATH)

    for _, row in bets.iterrows():
        payload = {
            "ticker": row["ticker"],
            "side": "bid",
            "count": "1",
            "price": f"{row["price"]}",
            "time_in_force": "good_till_canceled",
            "self_trade_prevention_type": "taker_at_cross",
        }

        response = post(
            private_key,
            KALSHI_API_KEY_ID,
            "/portfolio/events/orders",
            payload=payload,
        )
        print(response.json())
    print(bets)


if __name__ == "__main__":
    main()
