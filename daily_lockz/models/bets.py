import os
import pandas as pd

try:
    os.remove('./all_bets.csv')
except:
    pass

bets = pd.read_csv('./trevorscholz1/daily_lockz/models/bets.csv', index_col=0)
soccer_bets = pd.read_csv('./trevorscholz1/daily_lockz/models/soccer_bets.csv', index_col=0)

all_bets = pd.concat([bets, soccer_bets], ignore_index=True)
all_bets = all_bets.sort_values(by=['time', 'home_team']).reset_index(drop=True)

all_bets.to_csv('./trevorscholz1/daily_lockz/models/all_bets.csv', index=False, header=True)
print('DONE')