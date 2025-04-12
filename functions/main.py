from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import json
import datetime
import time
from utils.prompts import prompt_dialogue, prompt_big_JSON, prompt_dialogue_w_transliteration, prompt_generate_lesson_topic, prompt_suggest_custom_lesson
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
        print(request_data)
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

    print(keywords)

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

    google_synthesize_text(text, narrator_voice, file_name, bucket_name="user_nicknames")

    return https_fn.Response(
        json.dumps({"message": "Audio content written to and uploaded to bucket."}),
        status=200,
    )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def generate_lesson_topic(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        category = request_data.get("category")
        all_words = request_data.get("allWords")
        target_language = request_data.get("target_language")
        native_language = request_data.get("native_language")

        print(category, all_words, target_language, native_language)

        if not all(param is not None for param in [category, all_words, target_language, native_language]):
            return https_fn.Response(
                json.dumps({"error": "Missing required parameters"}),
                status=400
            )

        if not isinstance(all_words, list) or len(all_words) < 5:
            return https_fn.Response(
                json.dumps({"error": "allWords must be a list with at least 5 words"}),
                status=400
            )

        prompt = prompt_generate_lesson_topic(category, all_words, target_language, native_language)

        response = chatGPT_API_call(prompt, use_stream=False)

        # Since we're not using streaming, we need to get the content directly
        result = json.loads(response.choices[0].message.content)

        return https_fn.Response(
            json.dumps(result),
            status=200
        )

    except Exception as e:
        print(f"Error in generate_lesson_topic: {str(e)}")
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

def suggest_custom_lesson(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        target_language = request_data.get("target_language")
        native_language = request_data.get("native_language")


        if not all(param is not None for param in [target_language, native_language]):
            return https_fn.Response(
                json.dumps({"error": "Missing required parameters"}),
                status=400
            )

        prompt = prompt_suggest_custom_lesson(target_language, native_language)

        response = chatGPT_API_call(prompt, use_stream=False)

        result = json.loads(response.choices[0].message.content)

        return https_fn.Response(
            json.dumps(result),
            status=200
        )

    except Exception as e:
        print(f"Error in suggest_custom_lesson: {str(e)}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )