from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
from google.cloud import storage
import json
import datetime
from utils.prompts import prompt_dialogue, prompt_big_JSON
from utils.utilities import TTS_PROVIDERS, push_to_firestore, convert_string_to_JSON
from utils.chatGPT_API_call import chatGPT_API_call
from partialjson.json_parser import JSONParser
from utils.simulated_response import simulated_response
from utils.google_tts.gcloud_text_to_speech_api import voice_finder_google, google_synthesize_text
from utils.elevenlabs.elevenlabs_api import elevenlabs_tts

options.set_global_options(region="europe-west1", memory=512, timeout_sec=499)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()

class API_call_1:
    def __init__(self, native_language, tts_provider, document_id, document, target_language, document_durations, mock=False):
        self.turn_nr = 0
        self.generating_turns = False
        self.narrator_voice, self.narrator_voice_id = voice_finder_google("f", native_language)
        self.voice_1 = None
        self.voice_2 = None
        self.voice_1_id = None
        self.tts_function = None
        self.tts_provider = tts_provider
        self.document_id = document_id
        self.target_language = target_language
        self.document = document
        self.document_durations = document_durations
        self.select_tts_provider()
        self.push_to_firestore = push_to_firestore
        if mock:
            self.tts_function = self.mock_tts
            self.push_to_firestore = self.mock_push_to_firestore

    def select_tts_provider(self):
        if self.tts_provider == TTS_PROVIDERS.GOOGLE.value:
            self.tts_function = google_synthesize_text
        elif self.tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
            self.tts_function = elevenlabs_tts
        else:
            raise Exception("Invalid TTS provider")
        
    def handle_line(self, current_line, full_json):
        if '"all_turns": ' in current_line:
            self.generating_turns = True
        elif "}" in current_line:
            if self.generating_turns:
                print('full_json_0: ', full_json)
                native_sentence = full_json["all_turns"][self.turn_nr]["native_language"]
                filename = f"{self.document_id}/dialogue_{self.turn_nr}_native_language.mp3"
                self.tts_function(native_sentence, self.narrator_voice, filename, self.document_durations)
                voice_to_use = self.voice_1 if self.turn_nr % 2 == 0 else self.voice_2
                print('full_json_1: ', full_json)
                target_sentence = full_json["all_turns"][self.turn_nr]["target_language"]
                filename = f"{self.document_id}/dialogue_{self.turn_nr}_target_language.mp3"
                self.tts_function(target_sentence, voice_to_use, filename, self.document_durations)
                self.turn_nr += 1
                self.push_to_firestore(full_json, self.document, operation="overwrite")
        elif '"title": ' in current_line:
            print('full_json_2: ', full_json)
            self.tts_function(full_json["title"], self.narrator_voice, f"{self.document_id}/title.mp3", self.document_durations)
            if self.generating_turns:
                self.generating_turns = False
            self.push_to_firestore(full_json, self.document, operation="overwrite")
        elif '"speakers": ' in current_line:
            if self.generating_turns:
                self.generating_turns = False
        elif '"gender": ' in current_line:
            if self.generating_turns:
                gender = full_json["all_turns"][self.turn_nr]["gender"]
                if self.turn_nr == 0:
                    self.voice_1, self.voice_1_id = voice_finder_google(gender, self.target_language)
                    print('self.voice_1: ', self.voice_1)
                if self.turn_nr == 1:
                    self.voice_2, self.voice_2_id = voice_finder_google(gender, self.target_language, self.voice_1_id)
                    print('self.voice_2: ', self.voice_2)

    def mock_tts(self, text, voice_to_use, filename, document_durations):
        print('mock_tts called')
        print('text: ', text)
        print('voice_to_use: ', voice_to_use)
        print('filename: ', filename)
        print('document_durations: ', document_durations)

    def mock_push_to_firestore(self, full_json, document, operation="update"):
        print('mock_push_to_firestore called')
        print('full_json: ', full_json)
        print('document: ', document)
        print('operation: ', operation)


def process_response_1(chatGPT_response, handle_line):
    parser = JSONParser()
    compiled_response = ""
    end_of_line = False
    current_line = []

    for chunk in chatGPT_response:
        is_finished = chunk.choices[0].finish_reason
        if is_finished != None:
            break

        a_chunk = chunk.choices[0].delta.content
        compiled_response += a_chunk
        rectified_JSON = parser.parse(compiled_response)
        if not rectified_JSON:
            continue

        if "\n" in a_chunk:
            current_line.append(a_chunk)
            end_of_line = True

        if end_of_line == False:
            current_line.append(a_chunk)

        if end_of_line == True:
            current_line_text  = "".join(current_line)
            handle_line(current_line_text, rectified_JSON)
            end_of_line = False
            current_line = []
    return rectified_JSON

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
    

    api_call_1 = API_call_1(native_language, tts_provider, document_id, document, target_language, document_durations, mock=False)

    if api_call_1.mock == True:
        document = "Mock doc"
        document_durations = "Mock doc 2"
    else:
        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document(document_id)
        subcollection_ref = doc_ref.collection('only_target_sentences')
        document = subcollection_ref.document('updatable_json')

        subcollection_ref_durations = doc_ref.collection('file_durations')
        document_durations = subcollection_ref_durations.document('file_durations')



    prompt = prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length)
    
    if api_call_1.mock == True: 
        chatGPT_response = simulated_response
    else:
        chatGPT_response = chatGPT_API_call(prompt, use_stream=True)

    final_response = process_response_1(chatGPT_response, api_call_1.handle_line)

    final_response["user_ID"] = user_ID
    final_response["document_id"] = document_id

    api_call_1.push_to_firestore(final_response, document, operation="overwrite")
    return final_response


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
