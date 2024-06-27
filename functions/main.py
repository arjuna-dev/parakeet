from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import json
import datetime
from utils.prompts import prompt_dialogue, prompt_big_JSON
from utils.utilities import TTS_PROVIDERS
from utils.chatGPT_API_call import chatGPT_API_call
from utils.mock_responses import mock_response_first_API, mock_response_second_API
from utils.google_tts.gcloud_text_to_speech_api import language_to_language_code, create_google_voice
from models.pydantic_models import FirstAPIRequest, SecondAPIRequest
from services.api_calls import APICalls
from google.cloud import storage


import os

options.set_global_options(region="europe-west1", memory=512, timeout_sec=1000)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()



@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def first_API_calls(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = FirstAPIRequest.parse_obj(req.get_json()).dict()
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )
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


    is_mock = False

    if is_mock == True:
        document = "Mock doc"
        document_durations = "Mock doc 2"
    else:
        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document(document_id)
        subcollection_ref = doc_ref.collection('only_target_sentences')
        document = subcollection_ref.document('updatable_json')

        subcollection_ref_durations = doc_ref.collection('file_durations')
        document_durations = subcollection_ref_durations.document('file_durations')

    first_API_calls = APICalls(native_language,
                            tts_provider,
                            document_id,
                            document,
                            target_language,
                            document_durations,
                            words_to_repeat=[],
                            mock=is_mock)
    first_API_calls.line_handler = first_API_calls.handle_line_1st_API

    prompt = prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length)
    
    if first_API_calls.mock == True: 
        chatGPT_response = mock_response_first_API
    else:
        chatGPT_response = chatGPT_API_call(prompt, use_stream=True)

    final_response = first_API_calls.process_response(chatGPT_response)

    first_API_calls.executor.shutdown(wait=True)

    final_response["user_ID"] = user_ID
    final_response["document_id"] = document_id
    final_response["voice_1_id"] = first_API_calls.voice_1_id
    final_response["voice_2_id"] = first_API_calls.voice_2_id

    first_API_calls.push_to_firestore(final_response, document, operation="overwrite")

    # if first_API_calls.mock == True:
    #     return final_response
    # else:
    #     return
    return https_fn.Response(
        final_response,
        status=200
    )


@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def second_API_calls(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = SecondAPIRequest.parse_obj(req.get_json()).dict()
        print(type(request_data))
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )
    dialogue = request_data.get("dialogue")
    document_id = request_data.get("document_id")
    user_ID = request_data.get("user_ID")
    title = request_data.get("title")
    speakers = request_data.get("speakers")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    language_level = request_data.get("language_level")
    length = request_data.get("length")
    voice_1_id = request_data.get("voice_1_id")
    voice_2_id = request_data.get("voice_2_id")
    words_to_repeat = request_data.get("words_to_repeat")
    tts_provider = request_data.get("tts_provider")
    tts_provider = int(tts_provider)
    assert tts_provider in [TTS_PROVIDERS.ELEVENLABS.value, TTS_PROVIDERS.GOOGLE.value]

    print("request_data:", request_data)

    is_mock = False

    if is_mock == True:
        document = "Mock doc"
        document_durations = "Mock doc 2"
    else:
        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document(document_id)
        subcollection_ref = doc_ref.collection('all_breakdowns')
        document = subcollection_ref.document('updatable_big_json')

        subcollection_ref_durations = doc_ref.collection('file_durations')
        document_durations = subcollection_ref_durations.document('file_durations')

    language_code = language_to_language_code(target_language)

    voice_1 = create_google_voice(language_code, voice_1_id)
    voice_2 = create_google_voice(language_code, voice_2_id)

    second_API_calls = APICalls(native_language,
                                tts_provider,
                                document_id,
                                document,
                                target_language,
                                document_durations,
                                words_to_repeat,
                                voice_1,
                                voice_2,
                                mock=is_mock
                                )
    second_API_calls.line_handler = second_API_calls.handle_line_2nd_API

    prompt = prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers)

    if second_API_calls.mock == True: 
        chatGPT_response = mock_response_second_API
    else:
        chatGPT_response = chatGPT_API_call(prompt, use_stream=True)

    final_response = second_API_calls.process_response(chatGPT_response)

    second_API_calls.executor.shutdown(wait=True)

    final_response["user_ID"] = user_ID
    final_response["document_id"] = document_id
    final_response["native_language"] = native_language
    final_response["target_language"] = target_language
    final_response["language_level"] = language_level
    final_response["title"] = title
    final_response["speakers"] = speakers
    final_response["timestamp"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("final_response: ", final_response)

    second_API_calls.push_to_firestore(final_response, document, operation="overwrite")
    return https_fn.Response(
        final_response,
        status=200,
    )
@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def delete_audio_file (req: https_fn.Request) -> https_fn.Response:
    try:
        print(req)
        request_data = req.get_json()
        print(request_data)
        document_id = request_data.get("document_id")
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )
    bucket_name = "conversations_audio_files"
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    blobs = bucket.list_blobs(prefix=document_id + '/')

    for blob in blobs:
        try:
            blob.delete()
            print(f"Blob {blob.name} deleted.")
        except Exception as e:
            print(f"Blob {blob.name} not found.")
    # delete the folder as well
    
    
    return https_fn.Response(status=200)
