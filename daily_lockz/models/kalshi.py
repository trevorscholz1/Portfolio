import base64
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization, hashes
import datetime
from dotenv import load_dotenv
import os
import pandas as pd
import requests

load_dotenv()
KALSHI_API_KEY_ID = os.getenv("KALSHI_API_KEY")
SPORTS_API_KEY_ID = os.getenv("SPORTS_API_KEY")
PRIVATE_KEY_PATH = os.getenv("KALSHI_KEY_PATH")
BASE_URL = "https://api.elections.kalshi.com"


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
    signature = create_signature(private_key, timestamp, "POST", path)

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
    url = f"https://api.elections.kalshi.com/trade-api/v2/events?status=open&with_nested_markets=True&series_ticker={league_id}"
    response = requests.get(url)
    data = response.json()["events"]

    prices = []
    for item in data[::-1]:
        prices.append(
            {
                item["markets"][0]["ticker"]: (
                    f"{item['markets'][0]['yes_ask'] + 2}&YES"
                    if item["markets"][0]["yes_ask"] <= item["markets"][1]["no_ask"]
                    else f"{item['markets'][1]['no_ask'] + 2}&NO"
                ),
                item["markets"][1]["ticker"]: (
                    f"{item['markets'][1]['yes_ask'] + 2}&YES"
                    if item["markets"][1]["yes_ask"] <= item["markets"][0]["no_ask"]
                    else f"{item['markets'][0]['no_ask'] + 2}&NO"
                ),
            }
        )
    return prices


def get_sports_odds(league_id):
    url = f"https://api.sportsgameodds.com/v2/events?leagueID={league_id}&limit=200&oddsAvailable=true&oddID=points-home-game-ml-home&includeOpposingOdds=true&&started=false"
    headers = {"X-Api-Key": SPORTS_API_KEY_ID}
    response = requests.get(url, headers=headers)
    return response.json()


def main():
    bets = pd.DataFrame(columns=["ticker", "side", "price"])
    sports = [["NCAAB", "KXNCAAMBGAME"], ["NBA", "KXNBAGAME"], ["NCAAF", "KXNCAAFGAME"]]

    for sport in sports:
        odds_data = get_sports_odds(sport[0])
        kalshi_prices = get_kalshi_prices(sport[1])

        GAMES_MATCHED = 0
        matched = []

        for matchup in kalshi_prices:
            game = None
            teams = list(matchup.keys())
            team0, team1 = teams[0].split("-")[-1], teams[1].split("-")[-1]
            print(team0, team1)

            for item in odds_data["data"]:
                if (
                    team0 in item["teams"]["home"]["names"]["short"]
                    and team1 in item["teams"]["away"]["names"]["short"]
                ):
                    print(f"GAME FOUND: {team1} at {team0}")
                    GAMES_MATCHED += 1
                    matched.append(item["teams"]["home"]["names"]["short"])
                    home_team, away_team = teams[0], teams[1]
                    game = item
                    break
                elif (
                    team0 in item["teams"]["away"]["names"]["short"]
                    and team1 in item["teams"]["home"]["names"]["short"]
                ):
                    print(f"GAME FOUND: {team0} at {team1}")
                    GAMES_MATCHED += 1
                    matched.append(item["teams"]["home"]["names"]["short"])
                    home_team, away_team = teams[1], teams[0]
                    game = item
                    break

            if game is None:
                print(f"Skipped {team0} vs {team1}")
                continue

            fair_home_odds = convert(
                game["odds"]["points-home-game-ml-home"]["fairOdds"]
            )
            fair_away_odds = convert(
                game["odds"]["points-away-game-ml-away"]["fairOdds"]
            )
            home_price = int(matchup[home_team].split("&")[0])
            away_price = int(matchup[away_team].split("&")[0])

            print(fair_home_odds, home_price)
            print(fair_away_odds, away_price)
            if (home_price / 100) < fair_home_odds:
                side = matchup[home_team].split("&")[-1]
                bet = pd.DataFrame(
                    [
                        {
                            "ticker": home_team if side == "YES" else away_team,
                            "side": matchup[home_team].split("&")[-1],
                            "price": home_price,
                        }
                    ]
                )
                bets = pd.concat(
                    [bets, bet],
                    ignore_index=True,
                )
            if (away_price / 100) < fair_away_odds:
                side = matchup[away_team].split("&")[-1]
                bet = pd.DataFrame(
                    [
                        {
                            "ticker": away_team if side == "YES" else home_team,
                            "side": matchup[away_team].split("&")[-1],
                            "price": away_price,
                        }
                    ]
                )
                bets = pd.concat(
                    [bets, bet],
                    ignore_index=True,
                )

        print(len(odds_data["data"]), GAMES_MATCHED)
        print(
            [
                item["teams"]["home"]["names"]["short"]
                for item in odds_data["data"]
                if item["teams"]["home"]["names"]["short"] not in matched
            ]
        )
        print()

    private_key = load_private_key(PRIVATE_KEY_PATH)

    for _, row in bets.iterrows():
        payload = {
            "ticker": row["ticker"],
            "side": row["side"].lower(),
            "action": "buy",
            "count": 1,
            "type": "limit",
            (row["side"].lower() + "_price"): row["price"],
            "time_in_force": "good_till_canceled",
            "buy_max_cost": row["price"],
        }

        response = post(
            private_key,
            KALSHI_API_KEY_ID,
            "/trade-api/v2/portfolio/orders",
            payload=payload,
        )
        print(response.json())

    print(bets)


if __name__ == "__main__":
    main()
