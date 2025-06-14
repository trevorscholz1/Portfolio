import firebase_admin
from firebase_admin import credentials, firestore
import json

cred = credentials.Certificate('/Users/trevor/Documents/GoogleCerts/brickswipe-trevor-firebase-adminsdk-fbsvc-dad19187b9.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# sets_ref = db.collection('sets')
# sets_doc = sets_ref.document('sets')
# sets_doc.delete()

with open('/Users/trevor/trevorscholz1/extras/lego/lego_sets.json', 'r') as file:
    data = json.load(file)
print(len(data))

# sets_ref.document('sets').set({'data': data})
# print('Sets uploaded to Firestore.')
