import firebase_admin
from firebase_admin import credentials, firestore, auth
import pandas as pd
import logging
import datetime

def get_updated_data():
    # Enable Firestore Logging
    logging.basicConfig(level=logging.DEBUG)

    # Initialize Firebase Admin SDK if not already initialized
    try:
        # Check if app is already initialized
        firebase_admin.get_app()
    except ValueError:
        # Initialize app if not already done
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
    # Try to add user creation timestamps
    try:
        # Get user creation timestamps
        df_users_with_timestamps = add_creation_timestamps_to_users_df(df_users)
        df_users = df_users_with_timestamps
        print(f"Successfully added creation timestamps to {len(df_users[df_users['created_at'].notna()])} users.")
    except Exception as e:
        print(f"Error getting user creation timestamps: {e}")
        print("Continuing with original user data without timestamps.")

    df_users.to_csv('users.csv')
    df_analytics.to_csv('analytics.csv')
    df_big_jsons.to_csv('big_jsons.csv')

def get_users_creation_timestamps():
    """
    Get creation timestamps for users from Firebase Auth
    
    Returns:
        DataFrame with user IDs and their creation timestamps
    """
    # Initialize Firebase Admin SDK if not already initialized
    try:
        # Check if app is already initialized
        firebase_admin.get_app()
    except ValueError:
        # Initialize app if not already done
        cred = credentials.Certificate("private_key/noble-descent-420612-firebase-adminsdk-2wjte-2694a7866f.json")
        firebase_admin.initialize_app(cred)
    
    logging.info("Fetching user creation timestamps from Firebase Auth...")
    
    # Initialize list to store user data
    users_data = []
    
    # Get all user IDs from Firestore (we need this to know which users to query)
    db = firestore.client()
    users_ref = db.collection('users')
    users_docs = users_ref.stream()
    
    # Extract user IDs
    user_ids = [doc.id for doc in users_docs]
    logging.info(f"Found {len(user_ids)} users in Firestore.")
    
    # Fetch user creation timestamps from Firebase Auth in batches
    # Firebase has rate limits, so we process in batches
    batch_size = 50
    for i in range(0, len(user_ids), batch_size):
        batch = user_ids[i:i+batch_size]
        logging.info(f"Processing batch {i//batch_size + 1} of {len(user_ids)//batch_size + 1}...")
        
        for uid in batch:
            try:
                # Get user from Firebase Auth
                user = auth.get_user(uid)
                
                # Access user metadata correctly - Firebase Python SDK structure
                # Different versions of the SDK might have different attribute names
                if hasattr(user, 'user_metadata') and hasattr(user.user_metadata, 'creation_timestamp'):
                    timestamp_ms = user.user_metadata.creation_timestamp
                elif hasattr(user, 'user_create_time'):
                    # Alternative attribute in some SDK versions
                    timestamp_ms = int(user.user_create_time.timestamp() * 1000)
                elif hasattr(user, 'creation_timestamp'):
                    timestamp_ms = user.creation_timestamp
                else:
                    # Last resort, try accessing through dictionary-like access
                    try:
                        timestamp_ms = user.__dict__.get('_data', {}).get('createdAt', None)
                    except:
                        timestamp_ms = None
                
                # Create datetime if we found a timestamp
                if timestamp_ms:
                    creation_time = datetime.datetime.fromtimestamp(timestamp_ms / 1000)
                    
                    # Append user data
                    users_data.append({
                        'id': uid,
                        'email': getattr(user, 'email', None),
                        'created_at': creation_time
                    })
                
            except auth.UserNotFoundError:
                logging.warning(f"User {uid} not found in Firebase Auth")
            except Exception as e:
                logging.error(f"Error fetching user {uid}: {e}")
    
    # Create DataFrame from collected data
    df_users_timestamps = pd.DataFrame(users_data)
    
    # Save to CSV
    df_users_timestamps.to_csv('users_timestamps.csv')
    logging.info(f"Saved {len(df_users_timestamps)} user creation timestamps to users_timestamps.csv")
    
    return df_users_timestamps

def add_creation_timestamps_to_users_df(users_df, users_timestamps_df=None):
    """
    Add creation timestamps to users DataFrame
    
    Args:
        users_df: DataFrame with user data
        users_timestamps_df: Optional DataFrame with user creation timestamps
        
    Returns:
        users_df with added created_at column
    """
    if users_timestamps_df is None:
        # Try to load from CSV file
        try:
            users_timestamps_df = pd.read_csv('users_timestamps.csv')
        except FileNotFoundError:
            # Generate the timestamps
            users_timestamps_df = get_users_creation_timestamps()
    
    # Merge timestamps with users DataFrame
    merged_df = pd.merge(users_df, users_timestamps_df[['id', 'created_at']], on='id', how='left')
    
    return merged_df

# Example usage in main workflow:
# Call this function after loading users.csv to add creation timestamps
# df_users = add_creation_timestamps_to_users_df(df_users)