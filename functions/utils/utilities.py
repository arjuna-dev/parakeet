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
    GPT_4_1_nano = "gpt-4.1-nano"
    GPT_5_mini = "gpt-5-mini"
    GPT_5_nano = "gpt-5-nano"
    GPT_5_1 = "gpt-5.1"

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
    """Remove one slot; uses a transaction so concurrent updates do not drop entries."""
    db = firestore.client()
    doc_ref = db.collection('active_creation').document('active_creation')

    @firestore.transactional
    def _remove_in_transaction(transaction, ref, uid, did):
        snap = ref.get(transaction=transaction)
        if not snap.exists:
            return
        users = snap.to_dict().get('users', [])
        updated_users = [
            u
            for u in users
            if not (u.get('userId') == uid and u.get('documentId') == did)
        ]
        transaction.set(ref, {'users': updated_users}, merge=True)

    transaction = db.transaction()
    try:
        _remove_in_transaction(transaction, doc_ref, user_ID, document_id)
    except Exception as e:
        print(f'remove_user_from_active_creation_by_id: {e}')