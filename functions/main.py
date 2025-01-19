from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import json
import datetime
import time
from utils.prompts import prompt_dialogue, prompt_big_JSON, prompt_dialogue_w_transliteration
from utils.utilities import TTS_PROVIDERS
from utils.chatGPT_API_call import chatGPT_API_call
from utils.mock_responses import mock_response_first_API, mock_response_second_API
from utils.google_tts.gcloud_text_to_speech_api import language_to_language_code, create_google_voice, google_synthesize_text
from utils.openai_tts.openai_tts import language_to_language_code_openai
from models.pydantic_models import FirstAPIRequest, SecondAPIRequest
from services.api_calls import APICalls
from google.cloud import storage
from google.cloud import texttospeech
from utils.google_tts.google_tts_voices import google_tts_voices


import os

options.set_global_options(region="europe-west1", memory=512, timeout_sec=1000)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()
today = datetime.datetime.now().strftime("%Y-%m-%d")




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
    assert tts_provider in [TTS_PROVIDERS.ELEVENLABS.value, TTS_PROVIDERS.GOOGLE.value, TTS_PROVIDERS.OPENAI.value]
    try:
        language_level = request_data.get("language_level")
    except:
        language_level = "A1"
    try:
        keywords = request_data.get("keywords")
    except:
        keywords = ""

    db = firestore.client()
    # Reference to the user's document in the 'users' collection
    user_doc_ref = db.collection('users').document(user_ID).collection('api_call_count').document('first_API_calls')

    # Transaction to check and update the user's API call count
    @firestore.transactional
    def check_and_update_call_count(transaction, user_doc_ref):
        user_doc_snapshot = user_doc_ref.get(transaction=transaction)
        if not user_doc_snapshot.exists:
            # If the document doesn't exist, create it with the current call count set to 1
            transaction.set(user_doc_ref, {'last_call_date': today, 'call_count': 1})
        else:
            # If the document exists, check the call count and date
            if user_doc_snapshot.get('last_call_date') == today:
                if user_doc_snapshot.get('call_count') >= 5:
                    # If the call count for today is 5 or more, return False
                    return False
                else:
                    # If the call count is less than 5, increment it
                    transaction.update(user_doc_ref, {'call_count': firestore.Increment(1)})
            else:
                # If the last call was not made today, reset the count and date
                transaction.set(user_doc_ref, {'last_call_date': today, 'call_count': 1})
        return True

    # Start the transaction
    transaction = db.transaction()
    if not check_and_update_call_count(transaction, user_doc_ref):
        # If the user has reached their limit, return an error response
        return https_fn.Response(
            json.dumps({"error": "API call limit reached for today"}),
            status=429,  # HTTP status code for Too Many Requests
        )



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

    if target_language in ["Mandarin Chinese", "Korean", "Arabic", "Japanese"]:
        prompt = prompt_dialogue_w_transliteration(requested_scenario, native_language, target_language, language_level, keywords, length)


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

    return final_response


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
        second_API_calls.remove_user_from_active_creation_by_id(user_ID, document_id)
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
    assert tts_provider in [TTS_PROVIDERS.ELEVENLABS.value, TTS_PROVIDERS.GOOGLE.value, TTS_PROVIDERS.OPENAI.value]

    print("request_data:", request_data)

    is_mock = False

    if is_mock == True:
        document = "Mock doc"
        document_durations = "Mock doc 2"
    else:
        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document(document_id)
        subcollection_ref = doc_ref.collection('all_breakdowns')
        subcollection_ref_target_phrases = doc_ref.collection('target_phrases')
        document = subcollection_ref.document('updatable_big_json')
        document_target_phrases = subcollection_ref_target_phrases.document('updatable_target_phrases')

        subcollection_ref_durations = doc_ref.collection('file_durations')
        document_durations = subcollection_ref_durations.document('file_durations')

    if tts_provider == TTS_PROVIDERS.GOOGLE.value:
        language_code = language_to_language_code(target_language)

        voice_1 = create_google_voice(language_code, voice_1_id)
        voice_2 = create_google_voice(language_code, voice_2_id)
    elif tts_provider == TTS_PROVIDERS.OPENAI.value:
        language_code = language_to_language_code_openai(target_language)
        voice_1 = voice_1_id
        voice_2 = voice_2_id

    second_API_calls = APICalls(native_language,
                                tts_provider,
                                document_id,
                                document,
                                target_language,
                                document_durations,
                                words_to_repeat,
                                document_target_phrases,
                                voice_1,
                                voice_2,
                                mock=is_mock
                                )
    second_API_calls.line_handler = second_API_calls.handle_line_2nd_API


    if target_language in ["Mandarin Chinese", "Korean", "Arabic", "Japanese"]:
        for turn in dialogue:
            if '||' in turn["target_language"]:
                turn["target_language"] = turn["target_language"].split('||')[0]

    prompt = prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers)

    if second_API_calls.mock == True:
        chatGPT_response = mock_response_second_API
    else:
        chatGPT_response = chatGPT_API_call(prompt, use_stream=True)

    final_response = second_API_calls.process_response(chatGPT_response)

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

    second_API_calls.executor.shutdown(wait=True)

    # remove user ID from active_creation db in the firebase
    second_API_calls.remove_user_from_active_creation_by_id(user_ID, document_id)

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


def generate_audio_and_store(text, user_id_N, language):
    file_name = f"{user_id_N}_nickname.mp3"
    language_code = language_to_language_code(language)
    for voice in google_tts_voices:
        if voice['language_code'] == language_code:
            narrator_voice = create_google_voice(language_code, voice['voice_id'])
            break
    else:
        raise Exception(f"No matching voice found for language: {language}")

    google_synthesize_text(text, narrator_voice, file_name, bucket_name="user_nicknames", make_public= False)

    return f"Audio content written to and uploaded to bucket."

@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def generate_nickname_audio(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        text = request_data.get("text")
        user_id = request_data.get("user_id")
        user_id_N = request_data.get("user_id_N")
        language = request_data.get("language", "English (US)")
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )

    file_name = f"{user_id_N}_nickname.mp3"
    language_code = language_to_language_code(language)
    for voice in google_tts_voices:
        if voice['language_code'] == language_code:
            narrator_voice = create_google_voice(language_code, voice['voice_id'])
            break
    else:
        raise Exception(f"No matching voice found for language: {language}")

    google_synthesize_text(text, narrator_voice, file_name, bucket_name="user_nicknames", make_public= False)

    return https_fn.Response(
        json.dumps({"message": "Audio content written to and uploaded to bucket."}),
        status=200,
    )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def plottwist_story(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        post_id = request_data.get("post_id")
        data = request_data.get("data")
        
        if not post_id or not data:
            return https_fn.Response(
                json.dumps({"error": "Missing required fields: post_id or data"}),
                status=400,
            )

        db = firestore.client()
        doc_ref = db.collection('plotTwistStories').document(f'story_{post_id}')
        doc_ref.set(data, merge=True)

        return https_fn.Response(
            json.dumps({
                "message": "Document written successfully",
                "document_id": f'story_{post_id}'
            }),
            status=200,
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET"]
    )
)
def get_openai_key(req: https_fn.Request) -> https_fn.Response:
    try:

        # Validate the API key
        api_key = req.headers.get("Authorization")
        expected_api_key = "amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-"
        if api_key != f"Bearer {expected_api_key}":
            return https_fn.Response(
                json.dumps({"error": "Unauthorized"}),
                status=401
            )

        db = firestore.client()
        doc_ref = db.collection('plotTwistStories').document('openai')
        doc = doc_ref.get()

        if not doc.exists:
            return https_fn.Response(
                json.dumps({"error": "OpenAI key document not found"}),
                status=404
            )

        key = doc.get('key')
        if not key:
            return https_fn.Response(
                json.dumps({"error": "OpenAI key not found in document"}),
                status=404
            )

        return https_fn.Response(
            json.dumps({"key": key}),
            status=200
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def check_rate_limit(req: https_fn.Request) -> https_fn.Response:
    try:
        # Get username from request body
        request_data = req.get_json()
        username = request_data.get('username')
        
        if not username:
            return https_fn.Response(
                json.dumps({"error": "Username is required"}),
                status=400
            )

        db = firestore.client()
        user_ref = db.collection('plotTwistUsers').document(username)
        user_doc = user_ref.get()

        now = time.time()
        one_minute_ago = now - 60
        one_hour_ago = now - 3600
        one_day_ago = now - 86400
        one_month_ago = now - 2592000  # 30 days in seconds

        if user_doc.exists:
            timestamps = user_doc.get('timestamps', [])
            # Remove timestamps older than 31 days
            timestamps = [ts for ts in timestamps if ts > one_month_ago]
            
            # Count API calls in different time windows
            last_minute = sum(1 for ts in timestamps if ts > one_minute_ago)
            last_hour = sum(1 for ts in timestamps if ts > one_hour_ago)
            last_day = sum(1 for ts in timestamps if ts > one_day_ago)
            last_month = len(timestamps)

            # Check rate limits
            if last_minute >= 1:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Please wait a minute before your next request"
                    }),
                    status=200
                )
            if last_hour >= 20:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Hourly limit reached (20 requests)"
                    }),
                    status=200
                )
            if last_day >= 40:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Daily limit reached (40 requests)"
                    }),
                    status=200
                )
            if last_month >= 280:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Monthly limit reached (280 requests)"
                    }),
                    status=200
                )

            # Update timestamps array (remove old ones)
            user_ref.update({'timestamps': timestamps})

        return https_fn.Response(
            json.dumps({"allowed": True}),
            status=200
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def record_api_call(req: https_fn.Request) -> https_fn.Response:
    try:
        # Get username from request body
        request_data = req.get_json()
        username = request_data.get('username')
        
        if not username:
            return https_fn.Response(
                json.dumps({"error": "Username is required"}),
                status=400
            )

        db = firestore.client()
        user_ref = db.collection('plotTwistUsers').document(username)
        user_doc = user_ref.get()

        now = time.time()
        one_month_ago = now - 2592000  # 30 days in seconds

        if user_doc.exists:
            timestamps = user_doc.get('timestamps', [])
            # Remove timestamps older than 31 days
            timestamps = [ts for ts in timestamps if ts > one_month_ago]
            # Add new timestamp
            timestamps.append(now)
            user_ref.update({'timestamps': timestamps})
        else:
            # Create new user document
            user_ref.set({'timestamps': [now]})

        return https_fn.Response(
            json.dumps({"success": True}),
            status=200
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )