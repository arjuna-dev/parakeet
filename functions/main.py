from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
from google.cloud import storage
import json
import datetime
from utils.prompts import prompt_dialogue, prompt_big_JSON
import os
# from utils.json_parsers import parse_and_create_script, parse_and_convert_to_speech
from utils.utilities import TTS_PROVIDERS
from utils.chatGPT_API_call import chatGPT_API_call
from partialjson.json_parser import JSONParser
from utils.simulated_response import simulated_response
from utils.google_tts.gcloud_text_to_speech_api import voice_finder_google, google_synthesize_text
from utils.elevenlabs.elevenlabs_api import elevenlabs_tts

options.set_global_options(region="europe-west1", memory=512, timeout_sec=499)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()

def push_to_firestore(JSON_response, document):
    try:
        # storing chatGPT_response in Firestore
        document.set(JSON_response)
        # print("Mock pushed to firestore")
        pass
    except Exception as e:
        raise Exception(f"Error storing chatGPT_response in Firestore: {e}")

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
    tts_provider = request_data.get("tts_provider")
    tts_provider = int(tts_provider)
    assert tts_provider in [TTS_PROVIDERS.ELEVENLABS.value, TTS_PROVIDERS.GOOGLE.value]
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
    
    turn_nr = 0
    speaker_count = 0
    gender_count = 0
    generating_turns = False
    narrator_voice, narrator_voice_id = voice_finder_google("f", native_language)
    voice_1 = None
    voice_2 = None
    voice_1_id = None
    file_durations = {}
    if tts_provider == TTS_PROVIDERS.GOOGLE.value:
        tts_function = google_synthesize_text
    elif tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
        tts_function = elevenlabs_tts
    else:
        raise Exception("Invalid TTS provider")

    # def mock_tts_func(*args):
    #     for arg in args:
    #         print('arg: ', arg)
    # tts_function = mock_tts_func

    def handle_line(current_line, full_json, document):
        nonlocal turn_nr
        nonlocal speaker_count
        nonlocal gender_count
        nonlocal generating_turns
        nonlocal voice_1
        nonlocal voice_2
        nonlocal target_language
        nonlocal tts_function
        nonlocal voice_1_id
        nonlocal narrator_voice
        nonlocal file_durations
        if '"all_turns": ' in current_line:
            generating_turns = True
        elif "}" in current_line:
            if generating_turns:
                tts_function(full_json["all_turns"][turn_nr]["native_language"], narrator_voice, f"{document_id}/dialogue_{turn_nr}_native_language.mp3")
                voice_to_use = voice_1 if turn_nr % 2 == 0 else voice_2
                tts_function(full_json["all_turns"][turn_nr]["target_language"], voice_to_use, f"{document_id}/dialogue_{turn_nr}target_language.mp3")
                turn_nr += 1
                push_to_firestore(full_json, document)
        elif '"title": ' in current_line:
            tts_function(full_json["title"], narrator_voice, f"{document_id}/title.mp3")
            if generating_turns:
                generating_turns = False
            push_to_firestore(full_json, document)
        elif '"speakers": ' in current_line:
            if generating_turns:
                generating_turns = False
        elif '"gender": ' in current_line:
            if generating_turns:
                if turn_nr == 0:
                    print('full_json["all_turns"][turn_nr]["gender"]: ', full_json["all_turns"][turn_nr]["gender"])
                    print('target_language: ', target_language)
                    voice_1, voice_1_id = voice_finder_google(full_json["all_turns"][turn_nr]["gender"], target_language)
                    print('voice_1: ', voice_1)
                if turn_nr == 1:
                    voice_2, voice_2_id = voice_finder_google(full_json["all_turns"][turn_nr]["gender"], target_language, voice_1_id)
                    print('voice_2: ', voice_2)
        else:
            pass
        return None

    prompt = prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length)
    
    chatGPT_response = chatGPT_API_call(prompt, use_stream=True)
    # Uncomment the line below to use the simulated response
    # chatGPT_response = simulated_response

    db = firestore.client()
    doc_ref = db.collection('chatGPT_responses').document(document_id)
    subcollection_ref = doc_ref.collection('only_target_sentences')
    document = subcollection_ref.document('updatable_json')
    # document = "Mock doc"
    subcollection_ref_durations = doc_ref.collection('file_durations')
    document_durations = subcollection_ref_durations.document('file_durations')

    compiled_response = ""
    turn_nr = 0
    end_of_line = False
    last_few_chunks = []
    max_chunks_size = 6
    current_line = []

    parser = JSONParser()
    for chunk in chatGPT_response:

        is_finished = chunk.choices[0].finish_reason
        if is_finished != None:
            break

        a_chunk = chunk.choices[0].delta.content

        last_few_chunks.append(a_chunk)
        if len(last_few_chunks) > max_chunks_size:
            last_few_chunks.pop(0)

        compiled_response += a_chunk
        rectified_JSON = parser.parse(compiled_response)
        if not rectified_JSON:
            print('json not rectified: ', rectified_JSON)
            continue

        if "\n" in a_chunk:
            current_line.append(a_chunk)
            end_of_line = True

        if end_of_line == False:
            current_line.append(a_chunk)

        if end_of_line == True:
            current_line_text  = "".join(current_line)
            handle_line(current_line_text, rectified_JSON, document)
            end_of_line = False
            current_line = []

    rectified_JSON["user_ID"] = user_ID
    rectified_JSON["document_id"] = document_id

    push_to_firestore(file_durations, document_durations)
    push_to_firestore(rectified_JSON, document)
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
