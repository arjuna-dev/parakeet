import os
from enum import Enum
import json
import google.api_core.exceptions
from firebase_admin import firestore


class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode.
    GPT_4_TURBO = "gpt-4-turbo" # Supports vision and JSON mode. This points to GPT_4_TURBO_V as of today
    GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode
    GPT_4o = "gpt-4o"

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2

def check_if_running_locally():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, 'local_scripts')
    return os.path.isdir(file_path)

is_running_locally = check_if_running_locally()

def convert_string_to_JSON(string):
    try:
        json_object = json.loads(string)
    except Exception as e:
        raise Exception(f"Error converting string to JSON: {e}")
    return json_object

def push_to_firestore(data, document, operation='update'):
    try:
        if operation == 'update':
            document.update(data)
        elif operation == 'overwrite':
            document.set(data)
    except google.api_core.exceptions.NotFound:
        # If the document does not exist, use set instead of update
        document.set(data)
    except Exception as e:
        raise Exception(f"Error storing chatGPT_response in Firestore: {e}")
    

def remove_user_from_active_creation_by_id(user_ID, document_id):
    db = firestore.client()
    doc_ref = db.collection('active_creation').document('active_creation')
    doc = doc_ref.get()
    
    if doc.exists:
        # Extract the users array from the document
        users = doc.to_dict().get('users', [])
        
        # Filter out the user with the matching userId and documentId
        updated_users = [user for user in users if not (user.get('userId') == user_ID and user.get('documentId') == document_id)]
        
        # Update the document with the filtered users array
        doc_ref.update({"users": updated_users})
    else:
        print("Document does not exist.")