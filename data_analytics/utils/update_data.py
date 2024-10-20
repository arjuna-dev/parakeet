import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import logging

def get_updated_data():
    # Enable Firestore Logging
    logging.basicConfig(level=logging.DEBUG)

    # Initialize Firebase Admin SDK
    cred = credentials.Certificate("private_key/noble-descent-420612-firebase-adminsdk-2wjte-2694a7866f.json")
    firebase_admin.initialize_app(cred)

    # Initialize Firestore DB
    db = firestore.client()

    users_data = []
    analytics_data = []
    big_jsons = []

    users_ref = db.collection('users')
    users_doc = users_ref.stream()

    # Loop through each user document
    for doc in users_doc:
        user_dict = doc.to_dict()
        user_id = doc.id
        user_dict['id'] = user_id
        user_id = doc.id  # Get the document ID for the user
        users_data.append(user_dict)
        
        # Fetch the 'analytics' sub-collection for this user
        analytics_ref = db.collection('users').document(user_id).collection('analytics')
        analytics_docs = analytics_ref.stream()

        for analytics_doc in analytics_docs:
            analytics_dict = analytics_doc.to_dict()
            analytics_dict['id'] = analytics_doc.id
            analytics_dict['user_id'] = user_id
            analytics_data.append(analytics_dict)

    # List all document references in 'chatGPT_responses'
    chatgpt_responses_ref = db.collection('chatGPT_responses')
    documents = chatgpt_responses_ref.list_documents()  # This will give us all document references

    # Loop through each document reference and fetch its 'all_breakdowns' sub-collection
    for doc_ref in documents:

        all_breakdowns_ref = doc_ref.collection('all_breakdowns')
        all_breakdowns_docs = all_breakdowns_ref.stream()

        # Process each document in the 'all_breakdowns' sub-collection
        for breakdown_doc in all_breakdowns_docs:
            breakdown_dict = breakdown_doc.to_dict()
            big_jsons.append(breakdown_dict)

    df_users = pd.DataFrame(users_data)
    df_analytics = pd.DataFrame(analytics_data)
    df_big_jsons = pd.DataFrame(big_jsons)

    # Export the DataFrame to CSV
    df_users.to_csv('users.csv')
    df_analytics.to_csv('analytics.csv')
    df_big_jsons.to_csv('big_jsons.csv')