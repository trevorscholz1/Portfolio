from datetime import date, datetime as dt, timedelta
from dotenv import load_dotenv
from macnotesapp import NotesApp
import os
import pandas as pd
import pytz
import requests

PATH = "/Users/trevor/trevorscholz1/daily_lockz/models/placed.csv"
EDGE = 0.015


def convert(decimal):
    if decimal >= 2.0:
        return "+" + str(int((decimal - 1) * 100))
    else:
        return int(-100 / (decimal - 1))


def normalize(outcome0, outcome1):
    outcome0 = 1 / outcome0
    outcome1 = 1 / outcome1

    margin = (outcome0 + outcome1) % 1
    vig = margin / 2
    outcome0 -= vig
    outcome1 -= vig

    return outcome0, outcome1


def soccer_normalize(outcome0, outcome1, outcome2):
    outcome0 = 1 / outcome0
    outcome1 = 1 / outcome1
    outcome2 = 1 / outcome2

    margin = (outcome0 + outcome1 + outcome2) % 1
    vig = margin / 3
    outcome0 -= vig
    outcome1 -= vig

    return outcome0, outcome1


def convert_time(utc):
    utc_time = dt.strptime(utc, "%Y-%m-%dT%H:%M:%SZ")

    utc_zone = pytz.timezone("UTC")
    utc_time = utc_zone.localize(utc_time)

    est_zone = pytz.timezone("US/Eastern")
    est_time = utc_time.astimezone(est_zone)

    now_est = dt.now(est_zone)
    is_today = est_time.date() == now_est.date()

    return est_time, is_today


def load_placed():
    placed = pd.read_csv(PATH)
    placed["date_placed"] = pd.to_datetime(
        placed["date_placed"], errors="coerce"
    ).dt.date

    return placed


def save_placed(placed):
    placed["date_placed"] = pd.to_datetime(
        placed["date_placed"], errors="coerce"
    ).dt.date

    cutoff = date.today() - timedelta(days=7)
    placed = placed[placed["date_placed"] >= cutoff]
    placed.to_csv(PATH, index=False)


def main():
    BODY = ""
    spacer = ""
    for _ in range(50):
        spacer += "|"

    BETS = pd.DataFrame(columns=["sport", "team", "type", "point", "odds", "time"])
    SKIPPED_BETS = []
    placed = load_placed()

    load_dotenv()
    DATE = date.today()
    DATESEED = int(str(DATE).replace("-", ""))
    key = DATESEED % 3
    if key == 0:
        API_KEY = os.getenv("ODDS_API_KEY")
        BODY += "USING MAIN"
    elif key == 1:
        API_KEY = os.getenv("ODDS_BACKUP_KEY")
        BODY += "USING BACKUP"
    else:
        API_KEY = os.getenv("ODDS_DEMO_KEY")
        BODY += "USING DEMO"

    ACTIVE_SPORTS = []
    SPORTS = [
        "baseball_mlb",
        "basketball_nba",
        "basketball_ncaab",
        "americanfootball_ncaaf",
        "americanfootball_nfl",
        "icehockey_nhl",
        "soccer_usa_mls",
    ]

    try:
        response = requests.get(
            f"https://api.the-odds-api.com/v4/sports/?apiKey={API_KEY}"
        )
        response.raise_for_status()
        sports_data = response.json()
    except Exception as e:
        print("Error fetching sports:", e)
        return

    for sport in sports_data:
        if sport["key"] in SPORTS and sport["active"]:
            ACTIVE_SPORTS.append(sport["key"])

    NEW_BETS = []

    for sport in ACTIVE_SPORTS:
        try:
            response = requests.get(
                f"https://api.the-odds-api.com/v4/sports/{sport}/odds/?apiKey={API_KEY}&regions=us,us2&markets=h2h,spreads,totals"
            )
            response.raise_for_status()
            games = response.json()
        except Exception as e:
            print(f"Error fetching odds for {sport}:", e)
            continue

        BODY += f"PROCESSED {len(games)} {sport.split('_')[-1].upper()} GAMES"

        for game in games:
            index = 0
            GAME = pd.DataFrame(
                columns=[
                    "sport",
                    "h_team",
                    "a_team",
                    "book",
                    "h_ml",
                    "a_ml",
                    "h_spread",
                    "a_spread",
                    "spread_point",
                    "over",
                    "under",
                    "total_point",
                ]
            )

            home_team = game["home_team"]
            away_team = game["away_team"]

            time, live = convert_time(game["commence_time"])
            if live:
                continue

            for book in game["bookmakers"]:
                GAME.at[index, "sport"] = sport
                GAME.at[index, "h_team"] = home_team
                GAME.at[index, "a_team"] = away_team
                GAME.at[index, "book"] = book["key"]

                for market in book["markets"]:
                    outcomes = market["outcomes"]
                    if (
                        outcomes[0]["name"] == home_team
                        or outcomes[0]["name"] == "Over"
                    ):
                        if market["key"] == "h2h":
                            if "soccer" in sport:
                                if outcomes[1]["name"] == "Draw":
                                    price0, price1 = soccer_normalize(
                                        outcomes[0]["price"],
                                        outcomes[2]["price"],
                                        outcomes[1]["price"],
                                    )
                                elif outcomes[2]["name"] == "Draw":
                                    price0, price1 = soccer_normalize(
                                        outcomes[0]["price"],
                                        outcomes[1]["price"],
                                        outcomes[2]["price"],
                                    )
                            else:
                                price0, price1 = normalize(
                                    outcomes[0]["price"], outcomes[1]["price"]
                                )
                            GAME.at[index, "h_ml"] = price0
                            GAME.at[index, "a_ml"] = price1

                            GAME.at[index, "h_ml_raw"] = outcomes[0]["price"]
                            GAME.at[index, "a_ml_raw"] = outcomes[1]["price"]
                        elif market["key"] == "spreads":
                            price0, price1 = normalize(
                                outcomes[0]["price"], outcomes[1]["price"]
                            )
                            GAME.at[index, "h_spread"] = price0
                            GAME.at[index, "a_spread"] = price1
                            GAME.at[index, "spread_point"] = outcomes[0]["point"]

                            GAME.at[index, "h_spread_raw"] = outcomes[0]["price"]
                            GAME.at[index, "a_spread_raw"] = outcomes[1]["price"]
                        elif market["key"] == "totals":
                            price0, price1 = normalize(
                                outcomes[0]["price"], outcomes[1]["price"]
                            )
                            GAME.at[index, "over"] = price0
                            GAME.at[index, "under"] = price1
                            GAME.at[index, "total_point"] = outcomes[0]["point"]

                            GAME.at[index, "over_raw"] = outcomes[0]["price"]
                            GAME.at[index, "under_raw"] = outcomes[1]["price"]
                    elif (
                        outcomes[1]["name"] == home_team
                        or outcomes[1]["name"] == "Over"
                    ):
                        if market["key"] == "h2h":
                            if "soccer" in sport:
                                if outcomes[1]["name"] == "Draw":
                                    price0, price1 = soccer_normalize(
                                        outcomes[0]["price"],
                                        outcomes[2]["price"],
                                        outcomes[1]["price"],
                                    )
                                elif outcomes[2]["name"] == "Draw":
                                    price0, price1 = soccer_normalize(
                                        outcomes[0]["price"],
                                        outcomes[1]["price"],
                                        outcomes[2]["price"],
                                    )
                            else:
                                price0, price1 = normalize(
                                    outcomes[0]["price"], outcomes[1]["price"]
                                )
                            GAME.at[index, "h_ml"] = price1
                            GAME.at[index, "a_ml"] = price0

                            GAME.at[index, "h_ml_raw"] = outcomes[1]["price"]
                            GAME.at[index, "a_ml_raw"] = outcomes[0]["price"]
                        elif market["key"] == "spreads":
                            price0, price1 = normalize(
                                outcomes[0]["price"], outcomes[1]["price"]
                            )
                            GAME.at[index, "h_spread"] = price1
                            GAME.at[index, "a_spread"] = price0
                            GAME.at[index, "spread_point"] = outcomes[1]["point"]

                            GAME.at[index, "h_spread_raw"] = outcomes[1]["price"]
                            GAME.at[index, "a_spread_raw"] = outcomes[0]["price"]
                        elif market["key"] == "totals":
                            price0, price1 = normalize(
                                outcomes[0]["price"], outcomes[1]["price"]
                            )
                            GAME.at[index, "over"] = price1
                            GAME.at[index, "under"] = price0
                            GAME.at[index, "total_point"] = outcomes[1]["point"]

                            GAME.at[index, "over_raw"] = outcomes[1]["price"]
                            GAME.at[index, "under_raw"] = outcomes[0]["price"]
                index += 1

            fliff = GAME[GAME["book"] == "fliff"].reset_index()

            def add_bet(team, btype, point, odds, time):
                today = date.today()
                duplicate = False

                if not placed.empty:
                    placed_times = pd.to_datetime(
                        placed["time"], errors="coerce", utc=True
                    )
                    placed_times = placed_times.dt.tz_convert("US/Eastern")

                    mask = (
                        (placed["sport"] == sport)
                        & (placed["team"] == team)
                        & (placed["type"] == btype)
                    )

                    for placed_time in placed_times[mask]:
                        if abs(time - placed_time) <= timedelta(minutes=75):
                            duplicate = True
                            break

                if not duplicate:
                    BETS.loc[len(BETS)] = {
                        "sport": sport,
                        "team": team,
                        "type": btype,
                        "point": point,
                        "odds": odds,
                        "time": time,
                    }
                    NEW_BETS.append(
                        {
                            "sport": sport,
                            "team": team,
                            "type": btype,
                            "time": time,
                            "date_placed": today,
                        }
                    )
                else:
                    SKIPPED_BETS.append(
                        f"SKIPPED {sport} {team} {btype} {point} {odds} {time}"
                    )

            if not fliff["h_ml"].empty and fliff["h_ml"][0] <= (
                GAME["h_ml"].mean() - EDGE
            ):
                odds = convert(fliff["h_ml_raw"][0])
                add_bet(home_team, "ML", 0, odds, time)

            if not fliff["a_ml"].empty and fliff["a_ml"][0] <= (
                GAME["a_ml"].mean() - EDGE
            ):
                odds = convert(fliff["a_ml_raw"][0])
                add_bet(away_team, "ML", 0, odds, time)

            if not fliff.empty:
                SPREAD = GAME[
                    GAME["spread_point"] == fliff["spread_point"][0]
                ].reset_index()
            else:
                SPREAD = []
            if len(SPREAD) > 1:
                if not fliff["h_spread"].empty and fliff["h_spread"][0] <= (
                    SPREAD["h_spread"].mean() - EDGE
                ):
                    odds = convert(fliff["h_spread_raw"][0])
                    point = fliff["spread_point"][0]
                    add_bet(home_team, "SPREAD", abs(point), odds, time)

                if not fliff["a_spread"].empty and fliff["a_spread"][0] <= (
                    SPREAD["a_spread"].mean() - EDGE
                ):
                    odds = convert(fliff["a_spread_raw"][0])
                    point = fliff["spread_point"][0]
                    add_bet(away_team, "SPREAD", abs(point), odds, time)

            if not fliff.empty:
                TOTAL = GAME[
                    GAME["total_point"] == fliff["total_point"][0]
                ].reset_index()
            else:
                TOTAL = []
            if len(TOTAL) > 1:
                if not fliff["over"].empty and fliff["over"][0] <= (
                    TOTAL["over"].mean() - EDGE
                ):
                    odds = convert(fliff["over_raw"][0])
                    point = fliff["total_point"][0]
                    add_bet(home_team, "OVER", point, odds, time)

                if not fliff["under"].empty and fliff["under"][0] <= (
                    TOTAL["under"].mean() - EDGE
                ):
                    odds = convert(fliff["under_raw"][0])
                    point = fliff["total_point"][0]
                    add_bet(away_team, "UNDER", point, odds, time)

    BODY += "---"
    for _, row in BETS.iterrows():
        row_str = " ".join(row.astype(str))
        BODY += row_str + spacer
    BODY += "---" + str(SKIPPED_BETS)

    if NEW_BETS:
        placed = pd.concat([placed, pd.DataFrame(NEW_BETS)], ignore_index=True)
        save_placed(placed)

    notesapp = NotesApp()
    notesapp.make_note(f"{dt.now()} BETS", body=BODY)


if __name__ == "__main__":
    main()
