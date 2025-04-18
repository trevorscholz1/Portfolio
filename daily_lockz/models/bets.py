from datetime import date, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import numpy as np
import os
import pandas as pd

cred = credentials.Certificate('./Documents/GoogleCerts/daily-lockz-firebase-adminsdk-os684-05417a328a.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

TEST = 1
DATE = date.today() + timedelta(days=TEST)
DATESEED = int(str(DATE).replace('-', ''))
print(DATESEED)

sims = pd.read_csv('./trevorscholz1/daily_lockz/models/sims.csv')

all_sims = sims.copy()
all_sims['cur_date'] = DATE
all_sims['datetime'] = pd.to_datetime(all_sims['time'], format='%I:%M%p')
all_sims = all_sims.sort_values(by=['datetime','home_team']).reset_index(drop=True)
all_sims = all_sims.drop(columns=['datetime'])
print(f"GAMES AVAILABLE: {len(all_sims[all_sims['is_dl'] == True])}")

dailylockz = db.collection('picks')

existing_docs = dailylockz.stream()
for doc in existing_docs:
    doc.reference.delete()

bets_dict = all_sims.to_dict(orient='records')
for bet in bets_dict:
    bet['cur_date'] = bet['cur_date'].isoformat()
    dailylockz.add(bet)
print('Bets uploaded to Firestore.')

os.chdir('trevorAppsWebsites/daily-lockz')
os.system('git add .')
os.system("git commit -m 'daily'")
os.system('git push')
os.chdir('../../trevorscholz1/daily_lockz/models')
print('DONE')

bets = all_sims[all_sims['is_dl'] == True].copy()
bets['spread'] = all_sims['h_score'] - all_sims['a_score']
bets['total_score'] = all_sims['h_score'] + all_sims['a_score']
print(f"{bets[['sport','home_team','away_team','h_score','a_score','implied_odds','spread','total_score','time']]}\n")

i = 1
assignments = {}
bets.sort_values(by='sport', inplace=True)
for index, row in bets.iterrows():
    np.random.seed(i*DATESEED)
    
    conference = ''
    if 'NCAAB' in row['sport']:
        conference = row['sport'].split('NCAAB')[-1]
        row['sport'] = 'NCAAB'
    if row['sport'] not in assignments:
        assignments[row['sport']] = []

    if len(assignments[row['sport']]) == 0:
        assignment = np.random.choice(['Spread','Total'])
    elif len(assignments[row['sport']]) == 1:
        assignment = 'Spread' if assignments[row['sport']][0] == 'Total' else 'Total'

    if row['h_score'] >= row['a_score']:
        winteam = row['home_team']
    else:
        winteam = row['away_team']

    assignments[row['sport']].append(assignment)
    if row['sport'] in ['NBA','NCAAB','NCAAF','NFL']:
        if assignment == 'Spread':
            print(f"\n{row['sport'] + conference} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {winteam} by {abs(row['spread'])}")
        else:
            print(f"\n{row['sport'] + conference} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {row['total_score']}")
    elif row['sport'] in ['MLB','NHL']:
        print(f"\n{row['sport']} {row['time']} {row['home_team']}/{row['away_team']}: {winteam} at {row['implied_odds']}")
    else:
        print(f"\n{row['sport']} {row['time']} {row['home_team']}/{row['away_team']}: {winteam} 3-Way ML {row['implied_odds']}")
        
    print('------------------------------')
    i += 1
