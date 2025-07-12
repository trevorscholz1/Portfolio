from datetime import date, datetime as dt
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

    BETS = pd.DataFrame(columns=['sport','team','type','point','odds','time'])

    load_dotenv()
    DATE = date.today()
    DATESEED = int(str(DATE).replace('-', ''))
    if DATESEED % 2 == 0:
        API_KEY = os.getenv('ODDS_API_KEY')
        BODY += 'USING MAIN'
    else:
        API_KEY = os.getenv('ODDS_BACKUP_KEY')
        BODY += 'USING BACKUP'

    ACTIVE_SPORTS = []
    SPORTS = ['baseball_mlb','basketball_nba','basketball_ncaab','americanfootball_ncaaf','americanfootball_nfl','icehockey_nhl','soccer_usa_mls']

    try:
        response = requests.get(f"https://api.the-odds-api.com/v4/sports/?apiKey={API_KEY}")
        response.raise_for_status()
        sports_data = response.json()
    except Exception as e:
        print('Error fetching sports:', e)

    for sport in sports_data:
        if sport['key'] in SPORTS and sport['active']:
            ACTIVE_SPORTS.append(sport['key'])

    for sport in ACTIVE_SPORTS:
        try:
            response = requests.get(f"https://api.the-odds-api.com/v4/sports/{sport}/odds/?apiKey={API_KEY}&regions=us,us2&markets=h2h,spreads,totals")
            response.raise_for_status()
            games = response.json()
        except Exception as e:
            print(f"Error fetching odds for {sport}:", e)
            
        BODY += (f"PROCESSED {len(games)} {sport.split('_')[-1].upper()} GAMES")

        for game in games:
            index = 0
            GAME = pd.DataFrame(columns=['sport','h_team','a_team','book','h_ml','a_ml','h_spread','a_spread','spread_point','over','under','total_point'])
        
            home_team = game['home_team']
            away_team = game['away_team']
            
            time, live = convert_time(game['commence_time'])
            if live:
                continue

            for book in game['bookmakers']:
                GAME.at[index, 'sport'] = sport
                GAME.at[index, 'h_team'] = home_team
                GAME.at[index, 'a_team'] = away_team
                GAME.at[index, 'book'] = book['key']
                
                for market in book['markets']:
                    outcomes = market['outcomes']
                    if outcomes[0]['name'] == home_team or outcomes[0]['name'] == 'Over':
                        if market['key'] == 'h2h':
                            GAME.at[index, 'h_ml'] = outcomes[0]['price']
                            GAME.at[index, 'a_ml'] = outcomes[1]['price']
                        elif market['key'] == 'spreads':
                            GAME.at[index, 'h_spread'] = outcomes[0]['price']
                            GAME.at[index, 'a_spread'] = outcomes[1]['price']
                            GAME.at[index, 'spread_point'] = outcomes[0]['point']
                        elif market['key'] == 'totals':
                            GAME.at[index, 'over'] = outcomes[0]['price']
                            GAME.at[index, 'under'] = outcomes[1]['price']
                            GAME.at[index, 'total_point'] = outcomes[0]['point']
                    elif outcomes[1]['name'] == home_team or outcomes[1]['name'] == 'Over':
                        if market['key'] == 'h2h':
                            GAME.at[index, 'h_ml'] = outcomes[1]['price']
                            GAME.at[index, 'a_ml'] = outcomes[0]['price']
                        elif market['key'] == 'spreads':
                            GAME.at[index, 'h_spread'] = outcomes[1]['price']
                            GAME.at[index, 'a_spread'] = outcomes[0]['price']
                            GAME.at[index, 'spread_point'] = outcomes[1]['point']
                        elif market['key'] == 'totals':
                            GAME.at[index, 'over'] = outcomes[1]['price']
                            GAME.at[index, 'under'] = outcomes[0]['price']
                            GAME.at[index, 'total_point'] = outcomes[1]['point']
                index += 1
            
            fliff = GAME[GAME['book'] == 'fliff'].reset_index()
            if not fliff['h_ml'].empty and fliff['h_ml'][0] >= (GAME['h_ml'].mean() + 0.03):
                odds = convert(fliff['h_ml'][0])
                BETS.loc[len(BETS)] = {'sport': sport, 'team': home_team, 'type': 'ML', 'point': 0, 'odds': odds, 'time': time}
                
            if not fliff['a_ml'].empty and fliff['a_ml'][0] >= (GAME['a_ml'].mean() + 0.03):
                odds = convert(fliff['a_ml'][0])
                BETS.loc[len(BETS)] = {'sport': sport, 'team': away_team, 'type': 'ML', 'point': 0, 'odds': odds, 'time': time}

            if not fliff.empty:
                SPREAD = GAME[GAME['spread_point'] == fliff['spread_point'][0]].reset_index()
            else:
                SPREAD = []
            if len(SPREAD) > 1:
                if not fliff['h_spread'].empty and fliff['h_spread'][0] >= (SPREAD['h_spread'].mean() + 0.03):
                    odds = convert(fliff['h_spread'][0])
                    point = fliff['spread_point'][0]
                    BETS.loc[len(BETS)] = {'sport': sport, 'team': home_team, 'type': 'SPREAD', 'point': point, 'odds': odds, 'time': time}
                    
                if not fliff['a_spread'].empty and fliff['a_spread'][0] >= (SPREAD['a_spread'].mean() + 0.03):
                    odds = convert(fliff['a_spread'][0])
                    point = fliff['spread_point'][0]
                    BETS.loc[len(BETS)] = {'sport': sport, 'team': away_team, 'type': 'SPREAD', 'point': point, 'odds': odds, 'time': time}

            if not fliff.empty:
                TOTAL = GAME[GAME['total_point'] == fliff['total_point'][0]].reset_index()
            else:
                TOTAL = []
            if len(TOTAL) > 1:
                if not fliff['over'].empty and fliff['over'][0] >= (TOTAL['over'].mean() + 0.03):
                    odds = convert(fliff['over'][0])
                    point = fliff['total_point'][0]
                    BETS.loc[len(BETS)] = {'sport': sport, 'team': home_team, 'type': 'OVER', 'point': point, 'odds': odds, 'time': time}
                    
                if not fliff['under'].empty and fliff['under'][0] >= (TOTAL['under'].mean() + 0.03):
                    odds = convert(fliff['under'][0])
                    point = fliff['total_point'][0]
                    BETS.loc[len(BETS)] = {'sport': sport, 'team': away_team, 'type': 'UNDER', 'point': point, 'odds': odds, 'time': time}
    
    BODY += '-'
    for _, row in BETS.iterrows():
        row_str = ' '.join(row.astype(str))
        BODY += (row_str + spacer)

    notesapp = NotesApp()
    notesapp.make_note(f"{dt.now()} BETS", body=BODY)

if __name__ == '__main__':
    main()
