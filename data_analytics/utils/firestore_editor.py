import firebase_admin
from firebase_admin import credentials, firestore

# Initialize the Firebase Admin SDK with your credentials
cred = credentials.Certificate("noble-descent-420612-firebase-adminsdk-2wjte-2694a7866f.json")
firebase_admin.initialize_app(cred)

# Get a Firestore client
db = firestore.client()

def add_nickname_to_users():
    # Reference the users collection
    users_ref = db.collection("users")
    
    # Get all documents in the users collection
    users = users_ref.stream()

    for user in users:
        # For each user document, set a default nickname or calculate a nickname
        user_data = user.to_dict()
        
        # Add the nickname field to the document
        users_ref.document(user.id).update({"nickname": ""})
        
        print(f"Added nickname '{""}' to user with ID: {user.id}")

# Run the function
add_nickname_to_users()
