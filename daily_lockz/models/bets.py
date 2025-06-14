from datetime import date, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import os
import pandas as pd

cred = credentials.Certificate('/Users/trevor/Documents/GoogleCerts/daily-lockz-firebase-adminsdk-os684-05417a328a.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

TEST = 1
DATE = date.today() + timedelta(days=TEST)
DATESEED = int(str(DATE).replace('-', ''))
print(DATESEED)

sims = pd.read_csv('/Users/trevor/trevorscholz1/daily_lockz/models/sims.csv')

all_sims = sims.copy()
all_sims['cur_date'] = DATE
all_sims['datetime'] = pd.to_datetime(all_sims['time'], format='%I:%M%p')
all_sims = all_sims.sort_values(by=['datetime','home_team']).reset_index(drop=True)
all_sims = all_sims.drop(columns=['datetime'])

picks_ref = db.collection('picks')
picks_doc = picks_ref.document('picks')
picks_doc.delete()

bets_dict = all_sims.to_dict(orient='records')
for bet in bets_dict:
    bet['cur_date'] = bet['cur_date'].isoformat()

picks_ref.document('picks').set({'data': bets_dict})
print('Bets uploaded to Firestore.')

os.chdir('trevorAppsWebsites/daily-lockz')
os.system('git add .')
os.system("git commit -m 'daily'")
os.system('git push')
print('DONE')
