from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import openai
import json
from prompt import prompt
from enum import Enum
import os
from utilities import is_running_locally

if is_running_locally():
    from dotenv import load_dotenv
    load_dotenv()
    ELEVENLABS_API_KEY = os.getenv('OPEN_AI_API_KEY')
else:
    OPEN_AI_API_KEY = os.environ.get("OPEN_AI_API_KEY")

OPEN_AI_API_KEY = os.environ.get("OPEN_AI_API_KEY")

options.set_global_options(region="europe-west1", memory=256, timeout_sec=501)

class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode. Preview model.
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode. The default points to this one as of today.
    GPT_4_TURBO = "gpt-4-turbo" # Supports JSON mode. This points to some other one.
    GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode, results were not good.

gpt_model = GPT_MODEL.GPT_4_TURBO.value

initialize_app()

@https_fn.on_request(
    cors=options.CorsOptions(
      cors_origins=["*"],
      cors_methods=["GET", "POST"]
  )
)

@https_fn.on_request()
def first_chatGPT_API_call(req: https_fn.Request) -> https_fn.Response:
    request_data = json.loads(req.data)
    requested_scenario = request_data.get("requested_scenario")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    length = request_data.get("length")
    user_ID = request_data.get("user_ID")
    try:
        language_level = request_data.get("language_level")
    except:
        language_level = "A1"
    try:
        keywords = request_data.get("keywords")
    except:
        keywords = ""

    if not all([requested_scenario, native_language, target_language, language_level, user_ID, length]):
        return {'error': 'Missing required parameters in request data'}
    
    chatGPT_response = chatGPT_API_call(requested_scenario, native_language, target_language, language_level, user_ID, length, keywords)

    try:
        chatGPT_response = json.loads(chatGPT_response)
        # storing chatGPT_response in Firestore
        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document()
        subcollection_ref = doc_ref.collection('only_target_sentences')
        subcollection_ref.document().set(chatGPT_response)
    except Exception as e:
        print(chatGPT_response)
        print(f"Error parsing JSON response from chatGPT: {e}")
        #TODO: log error and failed JSON in DB and ask the user to try again
        return

    chatGPT_response["response_db_id"] = doc_ref.id
    chatGPT_response["user_ID"] = user_ID
    return chatGPT_response

def chatGPT_API_call(requested_scenario, native_language, target_language, language_level, user_ID, length, keywords):
    client = openai.OpenAI(api_key=OPEN_AI_API_KEY)

    # Create the chat completion
    completion = client.chat.completions.create(
        model=gpt_model,
        #   stream=True,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt(requested_scenario, native_language, target_language, language_level, keywords, length)}
        ],
        response_format={'type': 'json_object'}
    )

    chatGPT_JSON_response = completion.choices[0].message.content

    return chatGPT_JSON_response
