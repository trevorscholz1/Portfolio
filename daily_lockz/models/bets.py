from datetime import date, timedelta
import numpy as np
import os
import pandas as pd

TEST = 0
DATE = date.today() + timedelta(days=TEST)

np.random.seed(int(str(DATE).replace('-', '')))
print(int(str(DATE).replace('-', '')))

try:
    os.remove('./trevorAppsWebsites/daily-lockz/public/all_sims.csv')
except FileNotFoundError:
    pass
try:
    os.remove('./trevorAppsWebsites/DailyLockz/all_sims.csv')
except FileNotFoundError:
    pass

sims = pd.read_csv('./trevorscholz1/daily_lockz/models/sims.csv')
soccer_sims = pd.read_csv('./trevorscholz1/daily_lockz/models/soccer_sims.csv')

sims['is_dl'] = False
soccer_sims['is_dl'] = False

sims['datetime'] = pd.to_datetime(sims['time'], format='%m/%d/%Y %I:%M %p')
soccer_sims['datetime'] = pd.to_datetime(soccer_sims['time'], format='%m/%d/%Y %I:%M %p')

sims = sims.sort_values(by=['datetime', 'home_team']).reset_index(drop=True)
soccer_sims = soccer_sims.sort_values(by=['datetime', 'home_team']).reset_index(drop=True)

dl_indices = []
for sport, group in sims.groupby('sport'):
    if len(group) >= 2:
        dl_indices.extend(np.random.choice(group.index, size=2, replace=False))
    else:
        dl_indices.extend(group.index)
sims.loc[dl_indices, 'is_dl'] = True

if len(soccer_sims) >= 1:
    dl_indices = np.random.choice(soccer_sims.index, size=1, replace=False)
else:
    dl_indices = soccer_sims.index
soccer_sims.loc[dl_indices, 'is_dl'] = True

all_sims = pd.concat([sims, soccer_sims], ignore_index=True)
all_sims['cur_date'] = DATE
all_sims['datetime'] = pd.to_datetime(all_sims['datetime'], format='%m/%d/%Y %I:%M %p')
all_sims = all_sims.sort_values(by=['datetime', 'home_team']).reset_index(drop=True)
all_sims = all_sims.drop(columns=['datetime'])

print(f"GAMES AVAILABLE: {len(all_sims[all_sims['is_dl'] == True])}")
all_sims.to_csv('./trevorAppsWebsites/daily-lockz/public/all_sims.csv', index=False, header=True)
all_sims.to_csv('./trevorAppsWebsites/DailyLockz/all_sims.csv', index=False, header=True)

os.chdir('trevorAppsWebsites/daily-lockz')
os.system('git add .')
os.system("git commit -m 'daily'")
os.system('git push')
os.chdir('../../trevorscholz1/daily_lockz/models')
os.system('node uploadBlogPosts.js')
print('DONE')

bets = all_sims[all_sims['is_dl'] == True].copy()
bets['spread'] = all_sims['h_score'] - all_sims['a_score']
bets['total_score'] = all_sims['h_score'] + all_sims['a_score']
print(bets[['sport','home_team','away_team','h_score','a_score','implied_odds','spread','total_score','time']])

bets.sort_values(by='sport', inplace=True)
for index, row in bets.iterrows():
    if row['sport'] == 'NBA' or row['sport'] == 'NCAAB' or row['sport'] == 'NCAAF' or row['sport'] == 'NFL':
        if row['h_score'] >= row['a_score']:
            print(f"{row['home_team']} by {abs(row['spread'])} points ||| {row['total_score']}")
        else:
            print(f"{row['away_team']} by {abs(row['spread'])} points ||| {row['total_score']}")
    else:
        if row['h_score'] >= row['a_score']:
            print(f"{row['home_team']} at {row['implied_odds']} ||| {row['total_score']}")
        else:
            print(f"{row['away_team']} at {row['implied_odds']} ||| {row['total_score']}")
