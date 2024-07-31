from datetime import date
import os
import pandas as pd
import numpy as np

try:
    os.remove('./trevorAppsWebsites/daily-lockz/public/all_sims.csv')
except FileNotFoundError:
    pass

sims = pd.read_csv('./trevorscholz1/daily_lockz/models/sims.csv')
soccer_sims = pd.read_csv('./trevorscholz1/daily_lockz/models/soccer_sims.csv')
all_sims = pd.concat([sims, soccer_sims], ignore_index=True)

all_sims['cur_date'] = date.today()
all_sims['datetime'] = pd.to_datetime(all_sims['time'], format='%m/%d/%Y %I:%M %p')
all_sims = all_sims.sort_values(by=['datetime', 'home_team']).reset_index(drop=True)

all_sims['is_dl'] = False
today = date.today()
today_sims = all_sims[all_sims['datetime'].dt.date == today]

np.random.seed(0)

if len(today_sims) >= 12:
    dl_indices = np.random.choice(today_sims.index, size=12, replace=False)
else:
    dl_indices = today_sims.index

all_sims.loc[dl_indices, 'is_dl'] = True

all_sims = all_sims.drop(columns=['datetime'])

all_sims.to_csv('./trevorAppsWebsites/daily-lockz/public/all_sims.csv', index=False, header=True)
print('DONE')