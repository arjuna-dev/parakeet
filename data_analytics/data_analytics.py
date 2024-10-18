import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Initialize Firebase Admin SDK
cred = credentials.Certificate("private_key/noble-descent-420612-firebase-adminsdk-2wjte-2694a7866f.json")
firebase_admin.initialize_app(cred)

# Initialize Firestore DB
db = firestore.client()

# Fetch data from the Firestore collection
users_ref = db.collection('users')
users_doc = users_ref.stream()

# Create a list of dictionaries to hold user data
users_data = []

for doc in users_doc:
    user_dict = doc.to_dict()
    user_dict['id'] = doc.id  # Add the document ID if you need it
    users_data.append(user_dict)

# Convert the list of dictionaries into a Pandas DataFrame
df = pd.DataFrame(users_data)
df.to_csv('users.csv')

# Display DataFrame info and summary statistics
print(df.info())  # This will show the structure of the DataFrame
df.describe().to_csv('summary.csv')
print(df.describe())  # This will show a summary of numerical columns
