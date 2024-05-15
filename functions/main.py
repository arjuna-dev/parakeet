from enum import Enum
from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
from google.cloud import storage
import json
import openai
import datetime
from prompt import prompt
import os
from json_parsers import parse_and_create_script, parse_and_convert_to_speech, TTS_PROVIDERS
from utilities import is_running_locally, GPT_MODEL

if is_running_locally():
    from dotenv import load_dotenv
    load_dotenv()
    OPEN_AI_API_KEY = os.getenv('OPEN_AI_API_KEY')
else:
    OPEN_AI_API_KEY = os.environ.get("OPEN_AI_API_KEY")

assert OPEN_AI_API_KEY, "OPEN_AI_API_KEY is not set in the environment variables"


options.set_global_options(region="europe-west1", memory=512, timeout_sec=499)


now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

app = initialize_app()


class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode.
    GPT_4_TURBO = "gpt-4-turbo" # Supports vision and JSON mode. This points to GPT_4_TURBO_V as of today
    GPT_4_O = "gpt-4o"
    # GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode

gpt_model = GPT_MODEL.GPT_4_O.value

# @storage_fn.on_object_finalized(timeout_sec=500)
@https_fn.on_request(
    cors=options.CorsOptions(
      cors_origins=["*"],
      cors_methods=["GET", "POST"]
  )
)
@https_fn.on_request()
def full_API_workflow(req: https_fn.Request) -> https_fn.Response:
    request_data = json.loads(req.data)
    dialogue = request_data.get("dialogue")
    response_db_id = request_data.get("response_db_id")
    user_ID = request_data.get("user_ID")
    title = request_data.get("title")
    speakers = request_data.get("speakers")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    language_level = request_data.get("language_level")
    length = request_data.get("length")

    if not all([dialogue, response_db_id, user_ID, title, speakers, native_language, target_language, language_level, length]):
        return {'error': 'Missing required parameters in request data'}


    # ChatGPT API call
    chatGPT_response = chatGPT_API_call(dialogue, native_language, target_language, language_level, length, speakers)
    
    print(chatGPT_response)

    # storing chatGPT_response in Firestore
    db = firestore.client()
    doc_ref = db.collection('chatGPT_responses').document(response_db_id)
    subcollection_ref = doc_ref.collection('all_breakdowns')
    subcollection_ref.document().set(chatGPT_response)

    # Parse chatGPT_response and store in Firebase Storage
    fileDurations = parse_and_convert_to_speech(chatGPT_response, response_db_id, TTS_PROVIDERS.GOOGLE.value, native_language, target_language, speakers, title)
    
    # get all the file durations from narrator_audio_files bucket metadata
    client = storage.Client()
    bucket = client.get_bucket("narrator_audio_files")
    
    for blob in bucket.list_blobs(prefix="google_tts/narrator_english"):
        metadata = blob.metadata
        if metadata and 'duration' in metadata:
            fileDurations[blob.name] = metadata['duration']
        
    
   
    
    

    # Parse chatGPT_response and create script
    script = parse_and_create_script(chatGPT_response)
    
    

    # Create final response with link to audio files and script
    response = {}
    response["script"] = script
    response["native_language"] = native_language
    response["target_language"] = target_language
    response["language_level"] = language_level
    response["dialogue"] = dialogue
    response["speakers"] = speakers
    response["title"] = title
    response["userID"] = user_ID
    response["fileDurations"] = fileDurations

    #save script to Firestore
    subcollection_ref = doc_ref.collection('scripts')
    subcollection_ref.document().set(response)
    
    return response

def chatGPT_API_call(dialogue, native_language, target_language, language_level, length, speakers):

    client = openai.OpenAI(api_key=OPEN_AI_API_KEY)

    # Create the chat completion
    completion = client.chat.completions.create(
        model=gpt_model,
        #   stream=True,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt(dialogue, native_language, target_language, language_level, length, speakers)}
        ],
        response_format={'type': 'json_object'}
    )

    chatGPT_JSON_response = completion.choices[0].message.content
    try:
        data = json.loads(chatGPT_JSON_response)
    except Exception as e:
        print(chatGPT_JSON_response)
        print(f"Error parsing JSON response from chatGPT: {e}")
        #TODO: log error and failed JSON in DB and ask the user to try again
        return

    return data
