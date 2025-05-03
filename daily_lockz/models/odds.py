from datetime import datetime as dt
from dotenv import load_dotenv
from macnotesapp import NotesApp
import os
import pandas as pd
import pytz
import requests

def convert(decimal):
    if decimal >= 2.0:
        return '+' + str(int((decimal - 1) * 100))
    else:
        return int(-100 / (decimal - 1))

def convert_time(utc):
    utc_time = dt.strptime(utc, '%Y-%m-%dT%H:%M:%SZ')
    
    utc_zone = pytz.timezone('UTC')
    utc_time = utc_zone.localize(utc_time)
    
    est_zone = pytz.timezone('US/Eastern')
    est_time = utc_time.astimezone(est_zone)
    
    now_est = dt.now(est_zone)
    is_today = est_time.date() == now_est.date()
    
    return est_time.strftime('%Y-%m-%d %H:%M:%S %Z%z'), is_today

def main():
    BODY = ''
    spacer = ''
    for _ in range(50):
        spacer += '|'
    
    BETS = pd.DataFrame(columns=['sport','team','odds','time'])

    load_dotenv()
    API_KEY = os.getenv('ODDS_API_KEY')

    ACTIVE_SPORTS = []
    SPORTS = ['baseball_mlb','basketball_nba','basketball_ncaab','americanfootball_ncaaf','americanfootball_nfl','icehockey_nhl','soccer_usa_mls']

    try:
        response = requests.get(f"https://api.the-odds-api.com/v4/sports/?apiKey={API_KEY}")
        response.raise_for_status()
        sports_data = response.json()
    except Exception as e:
        print('Error fetching sports:', e)
        return

    for sport in sports_data:
        if sport['key'] in SPORTS and sport['active']:
            ACTIVE_SPORTS.append(sport['key'])

    for sport in ACTIVE_SPORTS:
        try:
            response = requests.get(f"https://api.the-odds-api.com/v4/sports/{sport}/odds/?apiKey={API_KEY}&regions=us,us2&markets=h2h")
            response.raise_for_status()
            games = response.json()
        except Exception as e:
            print(f"Error fetching odds for {sport}:", e)
            return
        
        BODY += (f"PROCESSED {len(games)} {sport.split('_')[-1].upper()} GAMES")

        for game in games:
            home_team = game['home_team']
            away_team = game['away_team']
            home_odds = []
            away_odds = []
            fliff_h_odds = 0
            fliff_a_odds = 0
            
            time, live = convert_time(game['commence_time'])
            if live:
                continue

            for book in game['bookmakers']:
                outcomes = book['markets'][0]['outcomes']
                if outcomes[0]['name'] == home_team:
                    home_odd = outcomes[0]['price']
                    away_odd = outcomes[1]['price']
                else:
                    home_odd = outcomes[1]['price']
                    away_odd = outcomes[0]['price']

                if book['title'] == 'Fliff':
                    fliff_h_odds = home_odd
                    fliff_a_odds = away_odd

                home_odds.append(home_odd)
                away_odds.append(away_odd)

            if not home_odds or not away_odds:
                continue

            h_avg = sum(home_odds) / len(home_odds)
            a_avg = sum(away_odds) / len(away_odds)

            if fliff_h_odds and fliff_h_odds >= h_avg:
                odds = convert(fliff_h_odds)
                BETS.loc[len(BETS)] = {'sport': sport, 'team': home_team, 'odds': odds, 'time': time}

            if fliff_a_odds and fliff_a_odds >= a_avg:
                odds = convert(fliff_a_odds)
                BETS.loc[len(BETS)] = {'sport': sport, 'team': away_team, 'odds': odds, 'time': time}
    
    BODY += '-'
    for _, row in BETS.iterrows():
        row_str = ' '.join(row.astype(str))
        BODY += (row_str + spacer)

    notesapp = NotesApp()
    notesapp.make_note(f"{dt.now()} BETS", body=BODY)

if __name__ == '__main__':
    main()
