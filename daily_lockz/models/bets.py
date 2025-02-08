from datetime import date, timedelta
import numpy as np
import os
import pandas as pd

TEST = 1
DATE = date.today() + timedelta(days=TEST)
DATESEED = int(str(DATE).replace('-', ''))
print(DATESEED)

try:
    os.remove('./trevorAppsWebsites/daily-lockz/public/all_sims.csv')
except FileNotFoundError:
    pass
try:
    os.remove('./trevorAppsWebsites/DailyLockz/all_sims.csv')
except FileNotFoundError:
    pass

sims = pd.read_csv('./trevorscholz1/daily_lockz/models/sims.csv')

all_sims = sims.copy()
all_sims['cur_date'] = DATE
all_sims['datetime'] = pd.to_datetime(all_sims['time'], format='%I:%M%p')
all_sims = all_sims.sort_values(by=['datetime','home_team']).reset_index(drop=True)
all_sims = all_sims.drop(columns=['datetime'])

all_sims.to_csv('./trevorAppsWebsites/daily-lockz/public/all_sims.csv', index=False, header=True)
all_sims.to_csv('./trevorAppsWebsites/DailyLockz/all_sims.csv', index=False, header=True)
print(f"GAMES AVAILABLE: {len(all_sims[all_sims['is_dl'] == True])}")

os.chdir('trevorAppsWebsites/daily-lockz')
os.system('git add .')
os.system("git commit -m 'daily'")
os.system('git push')
os.chdir('../../trevorscholz1/daily_lockz/models')
# os.system('node uploadBlogPosts.js')
print('DONE')

bets = all_sims[all_sims['is_dl'] == True].copy()
bets['spread'] = all_sims['h_score'] - all_sims['a_score']
bets['total_score'] = all_sims['h_score'] + all_sims['a_score']
print(bets[['sport','home_team','away_team','h_score','a_score','implied_odds','spread','total_score','time']])

i = 0
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
            print(f"{row['sport'] + conference} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {winteam} by {abs(row['spread'])}")
        else:
            print(f"{row['sport'] + conference} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {row['total_score']}")
    elif row['sport'] in ['MLB','NHL']:
        if assignment == 'Spread':
            print(f"{row['sport']} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {winteam} at {row['implied_odds']}")
        else:
            print(f"{row['sport']} {row['time']} {row['home_team']}/{row['away_team']}: {assignment} {row['total_score']}")
    else:
        print(f"{row['sport']} {row['time']} {row['home_team']}/{row['away_team']}: {winteam} 3-Way ML {row['implied_odds']}")
        
    print('--------------------------------------------------')
    i += 1
