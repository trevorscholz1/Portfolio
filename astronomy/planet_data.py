from datetime import date, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import os
from skyfield.api import load
from skyfield.magnitudelib import planetary_magnitude

try:
    os.remove('/Users/trevor/de421.bsp')
except FileNotFoundError:
    pass
PLANETS = load('de421.bsp')

SOLAR_OBJECTS = {
    'Sun': PLANETS['sun'],
    'Moon': PLANETS['moon'],
    'Mercury': PLANETS['mercury BARYCENTER'],
    'Venus': PLANETS['venus BARYCENTER'],
    'Mars': PLANETS['mars BARYCENTER'],
    'Jupiter': PLANETS['jupiter BARYCENTER'],
    'Saturn': PLANETS['saturn BARYCENTER'],
    'Uranus': PLANETS['uranus BARYCENTER'],
    'Neptune': PLANETS['neptune BARYCENTER']
}

def get_planet_data(planet, name, id, spect):
    ts = load.timescale()
    t = ts.utc(date.today() + timedelta(days=1))
    
    earth = PLANETS['earth']
    astrometric = earth.at(t).observe(planet)
    ra, dec, dist = astrometric.radec()
    if name == 'Sun':
        mag = -26.74
    elif name == 'Moon':
        mag = -12.74
    else:
        mag = planetary_magnitude(earth.at(t).observe(planet))
    return {
        'id': id,
        'name': name,
        'constellation': '',
        'distance': float(dist.au),
        'declination': float(dec.degrees),
        'rightAscension': float(ra.hours),
        'magnitude': float(mag),
        'luminosity': -999.0,
        'spectralType': chr(spect)
    }

def main():
    cred = credentials.Certificate('/Users/trevor/Documents/GoogleCerts/astroworld-trevor-firebase-adminsdk-l05ps-820638c3ff.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    planet_data = []
    id = 0.0
    spect = ord('r')
    for name, planet in SOLAR_OBJECTS.items():
        data = get_planet_data(planet, name, id, spect)
        planet_data.append(data)
        id += 1.0
        spect += 1

    objects_ref = db.collection('objects')
    planets_doc = objects_ref.document('planets')
    planets_doc.delete()
        
    objects_ref.document('planets').set({'data': planet_data})
    print('Solar system objects updated in Firestore.')

if __name__ == '__main__':
    main()
