import os
import pandas as pd

try:
    os.remove('./all_sims.csv')
except:
    pass

sims = pd.read_csv('./trevorscholz1/daily_lockz/models/sims.csv', index_col=0)
soccer_sims = pd.read_csv('./trevorscholz1/daily_lockz/models/soccer_sims.csv', index_col=0)

all_sims = pd.concat([sims, soccer_sims], ignore_index=True)
all_sims = all_sims.sort_values(by=['time', 'home_team']).reset_index(drop=True)

all_sims.to_csv('./trevorscholz1/daily_lockz/models/all_sims.csv', index=False, header=True)
print('DONE')