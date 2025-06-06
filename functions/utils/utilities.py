import os
from enum import Enum
import json
import google.api_core.exceptions
from firebase_admin import firestore


class GPT_MODEL(Enum):
    GPT_41_nano = "gpt-4.1-nano"
    GPT_4o = "gpt-4o"
    GPT_4o_mini = "gpt-4o-mini"

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2
    OPENAI = 3

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
        elif operation == 'add':
            document.set(data, merge=True)
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