import firebase_admin
from firebase_admin import credentials, firestore
import json
import math

cred = credentials.Certificate('/Users/trevor/Documents/GoogleCerts/brickswipe-trevor-firebase-adminsdk-fbsvc-dad19187b9.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

with open('/Users/trevor/trevorscholz1/extras/lego/lego_sets.json', 'r') as file:
    data = json.load(file)

sets_ref = db.collection('sets')
for i in range(1, 11):
    sets_ref.document(f"data{i}").delete()

batch_size = math.ceil(len(data) / 10)
for i in range(10):
    start_index = i * batch_size
    end_index = min((i + 1) * batch_size, len(data))
    batch_data = data[start_index : end_index]
    sets_ref.document(f"data{i + 1}").set({'data': batch_data})
    print(f"Uploaded batch data{i + 1} with {len(batch_data)} items.")
