from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import json
import datetime
import time
import re
from utils.prompts import prompt_dialogue, prompt_big_JSON, prompt_dialogue_w_transliteration, prompt_generate_lesson_topic, prompt_suggest_custom_lesson, prompt_translate_keywords, prompt_grammar_lesson, prompt_suggest_grammar_lesson, prompt_grammar_podcast_part_1, prompt_grammar_podcast_part_2
from utils.utilities import TTS_PROVIDERS, GPT_MODEL, remove_user_from_active_creation_by_id
from utils.chatGPT_API_call import chatGPT_API_call
from utils.mock_responses import mock_response_first_API, mock_response_second_API
from utils.google_tts.gcloud_text_to_speech_api import language_to_language_code, create_google_voice, google_synthesize_text, google_synthesize_multi_speaker_text, voice_finder_google
from utils.openai_tts.openai_tts import language_to_language_code_openai
from models.pydantic_models import FirstAPIRequest, SecondAPIRequest, FirstGrammarAPIRequest, SecondGrammarAPIRequest
from services.api_calls import APICalls
from google.cloud import storage
from google.cloud import texttospeech


import os

options.set_global_options(region="europe-west1", memory=512, timeout_sec=1000)
now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
app = initialize_app()
today = datetime.datetime.now().strftime("%Y-%m-%d")


def _parse_chatgpt_json_response(response):
    raw_content = response.choices[0].message.content
    if not isinstance(raw_content, str):
        raise ValueError("ChatGPT response content is not a string.")

    candidates = []
    stripped = raw_content.strip()
    candidates.append(stripped)

    if stripped.startswith("```"):
        fenced = re.sub(r"^```(?:json)?\s*", "", stripped)
        fenced = re.sub(r"\s*```$", "", fenced)
        candidates.append(fenced.strip())

    first_brace = stripped.find("{")
    last_brace = stripped.rfind("}")
    if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
        extracted = stripped[first_brace:last_brace + 1]
        candidates.append(extracted)
        candidates.append(re.sub(r",(\s*[}\]])", r"\1", extracted))

    seen = set()
    for candidate in candidates:
        normalized = candidate.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        try:
            return json.loads(normalized)
        except json.JSONDecodeError:
            continue

    print("Failed to parse ChatGPT JSON response. Raw content:")
    print(raw_content)
    raise ValueError("Model returned invalid JSON.")


def _grammar_podcast_prompt(native_language, target_language, language_level):
    return (
        f"You are producing an educational grammar podcast. "
        f"Speaker1 is a warm teacher speaking mostly in {native_language}. "
        f"Speaker2 speaks only in {target_language} examples and drills. "
        f"Keep pacing learner-friendly for level {language_level}. "
        f"Speaker2 must speak at a learner pace appropriate for level {language_level}: "
        f"slower, clearer, and more deliberate for beginners; still clear but more natural for higher levels. "
        f"Speaker2 should never rush target-language examples or drills. "
        f"Do not literally speak punctuation marks like comma, period, colon, semicolon, question mark, or exclamation mark. "
        f"Do not improvise beyond the provided script."
    )


def _grammar_part_audio_name(part_number):
    return f"grammar_part_{part_number}"


def _to_audio_part_ids(paths):
    return [path.split("/")[-1].replace(".mp3", "") for path in (paths or [])]


def _split_enclosed_target_snippets(text):
    parts = (text or "").split("||")
    out = []
    is_enclosed = False
    for part in parts:
        part = (part or "").strip()
        if part and not _is_punctuation_only_text(part):
            out.append({"text": part, "enclosed": is_enclosed})
        is_enclosed = not is_enclosed
    return out


def _sanitize_target_voice_text(text):
    return re.sub(r'\s+', ' ', (text or '').strip())


def _is_punctuation_only_text(text):
    normalized = (text or "").strip()
    if not normalized:
        return True
    return re.fullmatch(r"[\s\.,;:!?\-\(\)\[\]\"'`“”‘’/\\…]+", normalized) is not None


def _expand_embedded_target_voice_turns(turns):
    expanded = []
    for turn in turns or []:
        if not isinstance(turn, dict):
            continue
        speaker = turn.get("speaker")
        text = (turn.get("text") or "").strip()
        if not text or _is_punctuation_only_text(text):
            continue
        if speaker != "speaker_1" or "||" not in text:
            cleaned_text = (
                _sanitize_target_voice_text(text.replace("||", "").strip())
                if speaker == "speaker_2"
                else text.replace("||", "").strip()
            )
            if cleaned_text and not _is_punctuation_only_text(cleaned_text):
                expanded.append({
                    "speaker": speaker,
                    "text": cleaned_text,
                })
            continue

        parts = _split_enclosed_target_snippets(text)
        for part in parts:
            target_speaker = "speaker_2" if part["enclosed"] else "speaker_1"
            cleaned_text = (
                _sanitize_target_voice_text(part["text"])
                if target_speaker == "speaker_2"
                else part["text"]
            )
            if not cleaned_text or _is_punctuation_only_text(cleaned_text):
                continue
            expanded.append({
                "speaker": target_speaker,
                "text": cleaned_text,
            })

    merged = []
    for turn in expanded:
        if not merged or merged[-1]["speaker"] != turn["speaker"]:
            merged.append(turn)
        else:
            merged[-1]["text"] = f'{merged[-1]["text"]} {turn["text"]}'.strip()
    return merged


def _check_and_increment_daily_limit(user_id, counter_doc_name):
    db = firestore.client()
    user_doc_ref = db.collection('users').document(user_id)
    api_call_count_ref = user_doc_ref.collection('api_call_count').document(counter_doc_name)

    @firestore.transactional
    def check_daily_limit_and_update_call_count(transaction, user_doc_ref, api_call_count_ref):
        user_doc_snapshot = user_doc_ref.get(transaction=transaction)
        api_call_snapshot = api_call_count_ref.get(transaction=transaction)

        is_premium = False
        if user_doc_snapshot.exists:
            user_data = user_doc_snapshot.to_dict()
            is_premium = user_data.get('premium', False)

        daily_limit = 10 if is_premium else 2
        current_count = 0
        if api_call_snapshot.exists:
            api_call_data = api_call_snapshot.to_dict()
            last_call_date = api_call_data.get('last_call_date', '')
            current_count = api_call_data.get('call_count', 0)
            if last_call_date != today:
                current_count = 0

        if current_count >= daily_limit:
            return False

        if not user_doc_snapshot.exists:
            transaction.set(user_doc_ref, {'premium': False})

        transaction.set(api_call_count_ref, {
            'last_call_date': today,
            'call_count': current_count + 1
        })
        return True

    transaction = db.transaction()
    return check_daily_limit_and_update_call_count(transaction, user_doc_ref, api_call_count_ref)




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
    category = request_data.get("category")
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

    if not _check_and_increment_daily_limit(user_ID, 'first_API_calls'):
        # If the user has reached daily limit, return an error response
        return https_fn.Response(
            json.dumps({"error": "Daily lesson limit reached"}),
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
                            language_level,
                            document_durations,
                            words_to_repeat=[],
                            mock=is_mock,
                            lesson_type="conversation")
    first_API_calls.line_handler = first_API_calls.handle_line_1st_API

    prompt = prompt_dialogue(requested_scenario, category, native_language, target_language, language_level, keywords, length)

    if target_language in ["Mandarin Chinese", "Korean", "Arabic", "Japanese"]:
        prompt = prompt_dialogue_w_transliteration(requested_scenario, category, native_language, target_language, language_level, keywords, length)


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
    final_response["lesson_type"] = "conversation"
    # Client + completion checks use this; do not let the model override with a different count.
    final_response["length"] = str(length)

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
        body = req.get_json(silent=True) or {}
        uid = body.get("user_ID")
        did = body.get("document_id")
        if uid and did:
            remove_user_from_active_creation_by_id(uid, did)
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )
    api_runner = None
    user_ID = None
    document_id = None
    try:
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

        api_runner = APICalls(native_language,
                                    tts_provider,
                                    document_id,
                                    document,
                                    target_language,
                                    language_level,
                                    document_durations,
                                    words_to_repeat,
                                    document_target_phrases,
                                    voice_1,
                                    voice_2,
                                    mock=is_mock,
                                    lesson_type="conversation"
                                    )
        api_runner.line_handler = api_runner.handle_line_2nd_API

        # Spoken target text only (before ||); transliteration/pinyin must not go into big-JSON prompt.
        for turn in dialogue:
            if isinstance(turn, dict) and "target_language" in turn and "||" in turn["target_language"]:
                turn["target_language"] = turn["target_language"].split("||", 1)[0].strip()

        prompt = prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers)

        if api_runner.mock == True:
            chatGPT_response = mock_response_second_API
        else:
            chatGPT_response = chatGPT_API_call(prompt, use_stream=True)

        final_response = api_runner.process_response(chatGPT_response)

        final_response["user_ID"] = user_ID
        final_response["document_id"] = document_id
        final_response["native_language"] = native_language
        final_response["target_language"] = target_language
        final_response["language_level"] = language_level
        final_response["title"] = title
        final_response["speakers"] = speakers
        final_response["lesson_type"] = "conversation"
        final_response["timestamp"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        print("final_response: ", final_response)
        api_runner.push_to_firestore(final_response, document, operation="overwrite")

        return https_fn.Response(
            final_response,
            status=200,
        )
    except Exception as e:
        print(f"second_API_calls error: {e}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
        )
    finally:
        if api_runner is not None:
            api_runner.executor.shutdown(wait=True)
        if user_ID and document_id:
            remove_user_from_active_creation_by_id(user_ID, document_id)


@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def first_API_calls_grammar(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = FirstGrammarAPIRequest.parse_obj(req.get_json()).dict()
        print(request_data)
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )

    requested_topic = request_data.get("requested_topic")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    user_ID = request_data.get("user_ID")
    document_id = request_data.get("document_id")
    language_level = request_data.get("language_level")
    length_minutes = request_data.get("length_minutes") or "7"
    tts_provider = TTS_PROVIDERS.GOOGLE.value

    if not _check_and_increment_daily_limit(user_ID, 'first_API_calls'):
        return https_fn.Response(
            json.dumps({"error": "Daily lesson limit reached"}),
            status=429,
        )

    db = firestore.client()
    doc_ref = db.collection('chatGPT_responses').document(document_id)
    subcollection_ref = doc_ref.collection('only_target_sentences')
    document = subcollection_ref.document('updatable_json')
    subcollection_ref_durations = doc_ref.collection('file_durations')
    document_durations = subcollection_ref_durations.document('file_durations')

    language_code = language_to_language_code(target_language)
    narrator_language_code = language_to_language_code(native_language)
    narrator_voice = create_google_voice(narrator_language_code, 'Zephyr')

    prompt = prompt_grammar_podcast_part_1(
        requested_topic, native_language, target_language, language_level, length_minutes
    )
    response = chatGPT_API_call(prompt, use_stream=False)
    final_response = _parse_chatgpt_json_response(response)

    title = final_response.get("title", requested_topic)
    segments = _expand_embedded_target_voice_turns(
        final_response.get("segments", [])
    )
    speakers = final_response.get("speakers", {
        "speaker_1": {"name": "Narrator", "role": "narrator", "language": native_language},
        "speaker_2": {"name": "Target Voice", "role": "target_language_speaker", "language": target_language},
    })

    final_response["user_ID"] = user_ID
    final_response["document_id"] = document_id
    final_response["requested_topic"] = requested_topic
    final_response["speakers"] = speakers
    final_response["segments"] = segments
    final_response["dialogue"] = segments
    final_response["audio_parts"] = []
    final_response["part_1_segment_count"] = len(segments)
    final_response["lesson_type"] = "grammar"
    final_response["podcast_format"] = True
    final_response["length_minutes"] = str(length_minutes)
    final_response["title_audio_ready"] = False
    final_response["part_1_complete"] = False
    final_response["part_2_complete"] = False

    # Save the transcript immediately so the UI can render the lesson
    # while audio synthesis is still running.
    document.set(final_response)

    def _update_part_1_audio_parts(created_paths):
        incremental_response = dict(final_response)
        incremental_response["title_audio_ready"] = True
        incremental_response["audio_parts"] = _to_audio_part_ids(created_paths)
        document.set(incremental_response)

    google_synthesize_text(
        title,
        narrator_voice,
        f"{document_id}/title.mp3",
        document_durations,
        narrator_voice=True,
    )
    part_1_paths = google_synthesize_multi_speaker_text(
        segments,
        f"{document_id}/{_grammar_part_audio_name(1)}.mp3",
        language_code,
        document_durations,
        prompt_text=_grammar_podcast_prompt(native_language, target_language, language_level),
        speaker_1_id="Zephyr",
        speaker_2_id="Charon",
        progress_callback=_update_part_1_audio_parts,
    )

    final_response["audio_parts"] = _to_audio_part_ids(part_1_paths)
    final_response["title_audio_ready"] = True
    final_response["part_1_complete"] = True

    document.set(final_response)
    return https_fn.Response(
        json.dumps(final_response),
        status=200,
    )


@https_fn.on_request(
        cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def second_API_calls_grammar(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = SecondGrammarAPIRequest.parse_obj(req.get_json()).dict()
    except Exception as e:
        body = req.get_json(silent=True) or {}
        uid = body.get("user_ID")
        did = body.get("document_id")
        if uid and did:
            remove_user_from_active_creation_by_id(uid, did)
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )

    user_ID = request_data.get("user_ID")
    document_id = request_data.get("document_id")
    try:
        requested_topic = request_data.get("requested_topic")
        title = request_data.get("title")
        existing_segments = request_data.get("segments") or []
        speakers = request_data.get("speakers") or {}
        existing_audio_parts = request_data.get("audio_parts") or []
        native_language = request_data.get("native_language")
        target_language = request_data.get("target_language")
        language_level = request_data.get("language_level")
        length_minutes = request_data.get("length_minutes") or "7"

        db = firestore.client()
        doc_ref = db.collection('chatGPT_responses').document(document_id)
        document = doc_ref.collection('only_target_sentences').document('updatable_json')
        document_durations = doc_ref.collection('file_durations').document('file_durations')

        prompt = prompt_grammar_podcast_part_2(
            requested_topic,
            existing_segments,
            native_language,
            target_language,
            language_level,
            length_minutes,
        )
        response = chatGPT_API_call(prompt, use_stream=False)
        part_2_json = _parse_chatgpt_json_response(response)
        part_2_segments = _expand_embedded_target_voice_turns(
            part_2_json.get("segments", [])
        )

        merged_segments = list(existing_segments) + list(part_2_segments)
        transcript_response = {
            "title": title,
            "lesson_type": "grammar",
            "podcast_format": True,
            "requested_topic": requested_topic,
            "speakers": speakers,
            "segments": merged_segments,
            "dialogue": merged_segments,
            "audio_parts": list(existing_audio_parts),
            "part_1_segment_count": len(existing_segments),
            "title_audio_ready": True,
            "user_ID": user_ID,
            "document_id": document_id,
            "native_language": native_language,
            "target_language": target_language,
            "language_level": language_level,
            "length_minutes": str(length_minutes),
            "part_1_complete": True,
            "part_2_complete": False,
        }

        document.set(transcript_response)

        def _update_part_2_audio_parts(created_paths):
            incremental_response = dict(transcript_response)
            incremental_response["audio_parts"] = (
                list(existing_audio_parts) + _to_audio_part_ids(created_paths)
            )
            document.set(incremental_response)

        language_code = language_to_language_code(target_language)
        part_2_paths = google_synthesize_multi_speaker_text(
            part_2_segments,
            f"{document_id}/{_grammar_part_audio_name(2)}.mp3",
            language_code,
            document_durations,
            prompt_text=_grammar_podcast_prompt(native_language, target_language, language_level),
            speaker_1_id="Zephyr",
            speaker_2_id="Charon",
            progress_callback=_update_part_2_audio_parts,
        )

        final_response = dict(transcript_response)
        final_response["audio_parts"] = (
            list(existing_audio_parts) + _to_audio_part_ids(part_2_paths)
        )
        final_response["part_2_complete"] = True
        final_response["timestamp"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        document.set(final_response)

        return https_fn.Response(
            json.dumps(final_response),
            status=200,
        )
    except Exception as e:
        print(f"second_API_calls_grammar error: {e}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
        )
    finally:
        if user_ID and document_id:
            remove_user_from_active_creation_by_id(user_ID, document_id)



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
        user_id = request_data.get("user_id")
    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=400,
        )
    bucket_name = "conversations_audio_files"

    # delete the script document to remove it from users lesson collection
    db = firestore.client()
    col_ref = db.collection('chatGPT_responses').document(document_id).collection(f'script-{user_id}')
    for doc in col_ref.get():
        doc.reference.delete()

    # get all the word card audio file names and skip it from deletion
    col_ref_word_card_audio_urls = db.collection('chatGPT_responses').document(document_id).collection('word_card_audio_urls')
    docs = col_ref_word_card_audio_urls.get()
    word_card_audio_files = []
    if docs:
        for doc in docs:
            word_card_audio_files.append(document_id + '/' + doc.get("nativeChunkKey"))
            word_card_audio_files.append(document_id + '/' + doc.get("targetChunkKey"))


    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    blobs = bucket.list_blobs(prefix=document_id + '/')
    print(blobs)
    print(word_card_audio_files)

    for blob in blobs:
        try:
            if blob.name in word_card_audio_files:
                print(f"Blob {blob.name} not deleted.")
            else:
                blob.delete()
                print(f"Blob {blob.name} deleted.")
        except Exception as e:
            print(f"Blob {blob.name} not found.")

    return https_fn.Response(status=200)


def generate_audio_and_store(text, user_id_N, language):
    file_name = f"{user_id_N}_nickname.mp3"
    narrator_voice, _ = voice_finder_google("f", language, narrator_voice=True)  # Use female voice as default for nickname

    google_synthesize_text(text, narrator_voice, file_name, bucket_name="user_nicknames", narrator_voice=True)

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
    narrator_voice, _ = voice_finder_google("f", language, narrator_voice=True)  # Use female voice as default for nickname

    google_synthesize_text(text, narrator_voice, file_name, bucket_name="user_nicknames", narrator_voice=True)

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
        selected_words = request_data.get("selectedWords")
        target_language = request_data.get("target_language")
        native_language = request_data.get("native_language")
        if "level_number" in request_data:
            level_number = request_data.get("level_number")
        else:
            level_number = 1

        print(category, selected_words, target_language, native_language)

        if not all(param is not None for param in [category, selected_words, target_language, native_language]):
            return https_fn.Response(
                json.dumps({"error": "Missing required parameters"}),
                status=400
            )

        recent_topics = request_data.get("recent_topics") or []
        prompt = prompt_generate_lesson_topic(category, selected_words, target_language, native_language, level_number, recent_topics)

        response = chatGPT_API_call(prompt, use_stream=False, model=GPT_MODEL.GPT_5_nano.value)

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
def suggest_grammar_lesson_topic(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        target_language = request_data.get("target_language")
        native_language = request_data.get("native_language")
        language_level = request_data.get("language_level")
        recent_topics = request_data.get("recent_topics")

        if not all(param is not None for param in [target_language, native_language, language_level]):
            return https_fn.Response(
                json.dumps({"error": "Missing required parameters"}),
                status=400
            )

        prompt = prompt_suggest_grammar_lesson(
            target_language,
            native_language,
            language_level,
            recent_topics,
        )
        response = chatGPT_API_call(prompt, use_stream=False)
        response_text = response.choices[0].message.content
        return https_fn.Response(
            response_text,
            status=200,
            headers={'Content-Type': 'application/json'}
        )
    except Exception as e:
        print(f"Error in suggest_grammar_lesson_topic: {str(e)}")
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
def translate_keywords(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        keywords = request_data.get("keywords")
        target_language = request_data.get("target_language")
        native_language = request_data.get("native_language")

        prompt = prompt_translate_keywords(keywords, target_language, native_language)

        response = chatGPT_API_call(prompt, use_stream=False)

        result = json.loads(response.choices[0].message.content)

        return https_fn.Response(
            json.dumps(result),
            status=200
        )

    except Exception as e:
        print(f"Error in translate_keywords: {str(e)}")
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

        recent_topics = request_data.get("recent_topics") or []
        prompt = prompt_suggest_custom_lesson(target_language, native_language, recent_topics)

        response = chatGPT_API_call(prompt, use_stream=False, model=GPT_MODEL.GPT_5_nano.value)

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
