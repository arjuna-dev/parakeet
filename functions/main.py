from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
from google.cloud import storage
import json
import datetime
from utils.prompts import prompt_dialogue, prompt_big_JSON
import os
from utils.json_parsers import parse_and_create_script, parse_and_convert_to_speech
from utils.utilities import GPT_MODEL, TTS_PROVIDERS, convert_string_to_JSON, is_running_locally, voice_finder
from utils.chatGPT_API_call import chatGPT_API_call
from partialjson.json_parser import JSONParser
from utils.simulated_response import simulated_response

options.set_global_options(region="europe-west1", memory=512, timeout_sec=499)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()
gpt_model = GPT_MODEL.GPT_4o.value


def push_to_firestore(JSON_response, document):
    try:
        # storing chatGPT_response in Firestore
        document.set(JSON_response)
        print("Successfully stored chatGPT_response in Firestore")
    except Exception as e:
        raise Exception(f"Error storing chatGPT_response in Firestore: {e}")

def periodical_posting(JSON, last_keys):
    current_keys = set(JSON.keys())
    new_key = current_keys - last_keys
    if new_key:
        new_key_text = list(new_key)[0]

    if new_key and JSON[new_key_text]:
        last_keys = current_keys
        # push_to_firestore({"native": native_language_sentence}, subcollection_ref)
        print('JSON: ', JSON)
    return last_keys

@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def first_chatGPT_API_call(req: https_fn.Request) -> https_fn.Response:
    request_data = json.loads(req.data)
    requested_scenario = request_data.get("requested_scenario")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    length = request_data.get("length")
    user_ID = request_data.get("user_ID")
    document_id = request_data.get("document_id")
    try:
        language_level = request_data.get("language_level")
    except:
        language_level = "A1"
    try:
        keywords = request_data.get("keywords")
    except:
        keywords = ""

    if not all([requested_scenario, native_language, target_language, language_level, user_ID, length, document_id]):
        raise {'error': 'Missing required parameters in request data'}

    prompt = prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length)
    
    chatGPT_response = chatGPT_API_call(prompt, use_stream=True)
    # Uncomment the line below to use the simulated response
    # chatGPT_response = simulated_response

    # db = firestore.client()
    # doc_ref = db.collection('chatGPT_responses').document(document_id)
    # subcollection_ref = doc_ref.collection('only_target_sentences')
    # document = subcollection_ref.document()

    compiled_response = ""
    turn_nr = 0
    current_gender = ""
    last_keys = set()
    last_turns_length = 0
    last_turn_keys_sets = []

    parser = JSONParser()
    for chunk in chatGPT_response:

        is_finished = chunk.choices[0].finish_reason
        if is_finished != None:
            break

        a_chunk = chunk.choices[0].delta.content
        compiled_response += a_chunk

        rectified_JSON = parser.parse(compiled_response)
        if not rectified_JSON:
            continue

        last_keys = periodical_posting(rectified_JSON, last_keys)

        if rectified_JSON.get("all_turns") and isinstance(rectified_JSON.get("all_turns"), list):
            all_turns = rectified_JSON.get("all_turns")
            for i in range(len(all_turns)):
                turns_length = len(all_turns)
                if turns_length > last_turns_length:
                    last_turns_length = turns_length
                    last_turn_keys_sets.append(set())
                # rectified_JSON_turn = parser.parse(all_turns[i])
                last_turn_keys_sets[i] = periodical_posting(all_turns[i], last_turn_keys_sets[i])

        # # TODO: tts API calls use voice_finder(gender, target_language, tts_provider, exclude_voice_id=None) to get the 2 voices
        # dialogue_0_native_language.mp3

    # JSON_response = convert_string_to_JSON(compiled_response)
    # print('JSON_response: ', rectified_JSON)

    # JSON_response["response_db_id"] = doc_ref.id
    # JSON_response["user_ID"] = user_ID

    return rectified_JSON


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
    words_to_repeat = request_data.get("words_to_repeat")

    if not all([dialogue, response_db_id, user_ID, title, speakers, native_language, target_language, language_level, length, words_to_repeat]):
        return {'error': 'Missing required parameters in request data'}

    prompt = prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers)
    # ChatGPT API call
    response = chatGPT_API_call(prompt)
    chatGPT_response = response.choices[0].message.content

    # storing chatGPT_response in Firestore
    db = firestore.client()
    doc_ref = db.collection('chatGPT_responses').document(response_db_id)
    subcollection_ref = doc_ref.collection('all_breakdowns')
    subcollection_ref.document().set(chatGPT_response)

    print(words_to_repeat)
    # Parse chatGPT_response and create script
    script = parse_and_create_script(chatGPT_response, words_to_repeat)
    number_of_audio_files = len(script)

    # Parse chatGPT_response and store in Firebase Storage
    fileDurations = parse_and_convert_to_speech(chatGPT_response, response_db_id, TTS_PROVIDERS.GOOGLE.value, native_language, target_language, speakers, title, number_of_audio_files, words_to_repeat)

    # get narrator_audio_files_durations from Firestore
    collection_name_narrator = "narrator_audio_files_durations/google_tts/narrator_english"
    coll_ref_narrator= db.collection(collection_name_narrator)
    
    docs = coll_ref_narrator.stream()
    first_doc = next(docs, None)
    
    if first_doc:
        fileDurations.update(first_doc.to_dict())
    else:
        print("No such document!")

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

    #save script to Firestore inside the chatGPT_responses document
    subcollection_ref = doc_ref.collection('scripts')
    # Delete any existing script document
    docs = subcollection_ref.stream()
    for doc in docs:
        doc.reference.delete()
    
    subcollection_ref.document().set(response)

    return response
