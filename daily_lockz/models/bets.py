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
print('DONE')
