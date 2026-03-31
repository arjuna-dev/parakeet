import os
import re
import sys
import time
from pathlib import Path
from google.api_core.client_options import ClientOptions
from google.cloud import texttospeech, storage, firestore
from mutagen.mp3 import MP3
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from utilities import push_to_firestore
from .language_names import LANGUAGE_NAMES
from .tts_rate_limiter import tts_synthesis_slot


def language_to_language_code(language):
    # get the key from LANGUAGE_NAMES that has the value equal to the language
    for key, value in LANGUAGE_NAMES.items():
        if value == language:
            return key
    raise Exception(f"Language code not found for {language}")

def find_matching_voice_google(gender, exclude_voice_id=None, narrator_voice = False):
    if narrator_voice == False:
        voice_id = None
        gemini_voices = [{'gender': 'f', 'voice_id': 'Achernar'}, {'gender': 'm', 'voice_id': 'Achird'}, {'gender': 'f', 'voice_id': 'Despina'}, {'gender': 'm', 'voice_id': 'Alnilam'}]
        for voice in gemini_voices:
            if voice.get('gender') == gender and voice.get('voice_id') != exclude_voice_id:
                voice_id = voice.get('voice_id')
                return voice_id
        raise Exception("No matching voice found")
    else:
        voice_id = 'Zephyr'
        return voice_id

def create_google_voice(language_code, voice_id):
    
    voice = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_id, model_name='gemini-2.5-flash-lite-preview-tts')
    return voice


def voice_finder_google(gender, target_language, exclude_voice_id=None, narrator_voice=False):
    
    target_language_code = language_to_language_code(target_language)
    speaker_voice_id = find_matching_voice_google(gender, exclude_voice_id, narrator_voice)
    speaker_voice = create_google_voice(target_language_code, speaker_voice_id)

    return speaker_voice, speaker_voice_id


def _utf8_size(text):
    return len((text or "").encode("utf-8"))


def _split_long_token(token, max_bytes):
    words = token.split()
    if not words:
        return [token]
    chunks = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if _utf8_size(candidate) <= max_bytes:
            current = candidate
        else:
            chunks.append(current.strip())
            current = word
    if current.strip():
        chunks.append(current.strip())
    return chunks


def _split_text_for_tts(text, max_bytes=260):
    text = " ".join((text or "").split())
    if not text:
        return []
    if _utf8_size(text) <= max_bytes:
        return [text]

    pieces = re.split(r'(?<=[.!?;:])\s+', text)
    if len(pieces) == 1:
        pieces = re.split(r'(?<=[,])\s+', text)

    normalized_pieces = []
    for piece in pieces:
        piece = piece.strip()
        if not piece:
            continue
        if _utf8_size(piece) <= max_bytes:
            normalized_pieces.append(piece)
        else:
            normalized_pieces.extend(_split_long_token(piece, max_bytes))

    chunks = []
    current = ""
    for piece in normalized_pieces:
        candidate = piece if not current else f"{current} {piece}"
        if _utf8_size(candidate) <= max_bytes:
            current = candidate
        else:
            if current:
                chunks.append(current.strip())
            current = piece
    if current.strip():
        chunks.append(current.strip())
    return chunks


def _split_multi_speaker_turns(turns, max_bytes=3200, max_turns=12):
    batches = []
    current_batch = []
    current_bytes = 0

    for turn in turns:
        speaker = "Speaker1" if turn.get("speaker") == "speaker_1" else "Speaker2"
        text = (turn.get("text") or "").strip()
        if not text:
            continue

        turn_bytes = _utf8_size(text) + _utf8_size(speaker) + 16

        if current_batch and (
            len(current_batch) >= max_turns or current_bytes + turn_bytes > max_bytes
        ):
            batches.append(current_batch)
            current_batch = []
            current_bytes = 0

        current_batch.append({
            "speaker": turn.get("speaker"),
            "text": text,
        })
        current_bytes += turn_bytes

    if current_batch:
        batches.append(current_batch)

    return batches


def _speaking_rate_for_language_level(language_level, narrator_voice=False, first_API_call=False):
    if narrator_voice:
        return 1.0
    if first_API_call:
        return 1.0

    normalized = (language_level or "").strip().lower()
    if normalized in {"absolute beginner", "a0", "pre-a1", "a1"}:
        return 0.72
    if normalized in {"beginner", "a2"}:
        return 0.8
    if normalized in {"intermediate", "b1"}:
        return 0.9
    if normalized in {"upper intermediate", "b2"}:
        return 0.96
    return 1.0

def google_synthesize_text(text, voice, output_path, doc_ref = None, local_run=False, bucket_name="conversations_audio_files", first_API_call=False, language_level="A1", narrator_voice=False, max_retries=5):
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    client = texttospeech.TextToSpeechClient(
        client_options=ClientOptions(
            api_endpoint="us-central1-texttospeech.googleapis.com",
        ),
    )
    if narrator_voice == False:
        print("speaker_voice: ", voice)
        prompt_text = 'Speak naturally, clearly, and in a friendly tone.'
    else:
        prompt_text = 'Speak naturally and in a friendly tone with a narrator voice.'
        print("narrator_voice: ", voice)
    speaking_rate = _speaking_rate_for_language_level(
        language_level,
        narrator_voice=narrator_voice,
        first_API_call=first_API_call,
    )
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        speaking_rate=speaking_rate,
    )
    text_chunks = _split_text_for_tts(text, max_bytes=260)
    if not text_chunks:
        text_chunks = [text]

    combined_audio = bytearray()

    for chunk in text_chunks:
        synthesis_input = texttospeech.SynthesisInput(text=chunk, prompt=prompt_text)
        response = None
        retry_count = 0

        while retry_count < max_retries:
            try:
                with tts_synthesis_slot():
                    response = client.synthesize_speech(
                        input=synthesis_input, voice=voice, audio_config=audio_config
                    )
                break
            except Exception as e:
                retry_count += 1
                if retry_count >= max_retries:
                    print(f'Error synthesizing text after {max_retries} retries: {e}')
                    raise
                wait_time = 2 ** retry_count
                print(f'Error synthesizing text (attempt {retry_count}/{max_retries}): {e}')
                print(f'Retrying in {wait_time} seconds...')
                time.sleep(wait_time)

        if response is not None:
            combined_audio.extend(response.audio_content)

    with open(f"{output_path}", "wb") as out:
        out.write(bytes(combined_audio))

    if local_run:
        return {output_path:0}
    else:
        # Load audio file
        audio = MP3(output_path)

        # Get duration of audio file
        duration = audio.info.length

        # Upload the audio file to the bucket
        blob_name = f"{output_path}"
        storage_client = storage.Client()
        bucket = storage_client.get_bucket(bucket_name)
        blob = bucket.blob(blob_name)
        try:
            blob.upload_from_filename(output_path, timeout = 600)
        except Exception as e:
            print(f'Error uploading file: {e}')

        blob.patch()
        blob.make_public()

        if doc_ref:
            filename_duration = {output_path.split("/")[-1].replace('.mp3', ''): duration}
            push_to_firestore(filename_duration, doc_ref)


def google_synthesize_multi_speaker_text(
    turns,
    output_path,
    language_code,
    doc_ref=None,
    local_run=False,
    bucket_name="conversations_audio_files",
    prompt_text="Create a warm educational grammar podcast.",
    speaker_1_id="Zephyr",
    speaker_2_id="Charon",
    max_retries=5,
    progress_callback=None,
):
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    client = texttospeech.TextToSpeechClient(
        client_options=ClientOptions(
            api_endpoint="us-texttospeech.googleapis.com",
        ),
    )

    multi_speaker_voice_config = texttospeech.MultiSpeakerVoiceConfig(
        speaker_voice_configs=[
            texttospeech.MultispeakerPrebuiltVoice(
                speaker_alias="Speaker1",
                speaker_id=speaker_1_id,
            ),
            texttospeech.MultispeakerPrebuiltVoice(
                speaker_alias="Speaker2",
                speaker_id=speaker_2_id,
            ),
        ]
    )

    voice = texttospeech.VoiceSelectionParams(
        language_code=language_code,
        model_name="gemini-2.5-flash-tts",
        multi_speaker_voice_config=multi_speaker_voice_config,
    )

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
    )
    turn_batches = _split_multi_speaker_turns(turns)
    created_files = []
    storage_client = None if local_run else storage.Client()
    bucket = None if local_run else storage_client.get_bucket(bucket_name)

    for batch_index, turn_batch in enumerate(turn_batches):
        batch_output_path = output_path.replace(
            ".mp3", f"_batch_{batch_index}.mp3"
        )
        synthesis_input = texttospeech.SynthesisInput(
            multi_speaker_markup=texttospeech.MultiSpeakerMarkup(
                turns=[
                    texttospeech.MultiSpeakerMarkup.Turn(
                        speaker="Speaker1" if turn.get("speaker") == "speaker_1" else "Speaker2",
                        text=(turn.get("text") or "").strip(),
                    )
                    for turn in turn_batch
                    if (turn.get("text") or "").strip()
                ]
            ),
            prompt=prompt_text,
        )

        response = None
        retry_count = 0
        while retry_count < max_retries:
            try:
                with tts_synthesis_slot():
                    response = client.synthesize_speech(
                        input=synthesis_input,
                        voice=voice,
                        audio_config=audio_config,
                    )
                break
            except Exception as e:
                retry_count += 1
                if retry_count >= max_retries:
                    print(
                        f'Error synthesizing multi-speaker batch {batch_index + 1}/{len(turn_batches)} after {max_retries} retries: {e}'
                    )
                    raise
                wait_time = min(3 ** retry_count, 30)
                print(
                    f'Error synthesizing multi-speaker text batch {batch_index + 1}/{len(turn_batches)} '
                    f'(attempt {retry_count}/{max_retries}): {e}'
                )
                print(f'Retrying in {wait_time} seconds...')
                time.sleep(wait_time)

        if response is not None:
            with open(batch_output_path, "wb") as out:
                out.write(response.audio_content)
            created_files.append(batch_output_path)

            if local_run:
                continue

            audio = MP3(batch_output_path)
            duration = audio.info.length

            blob_name = f"{batch_output_path}"
            blob = bucket.blob(blob_name)
            try:
                blob.upload_from_filename(batch_output_path, timeout=600)
            except Exception as e:
                print(f'Error uploading file: {e}')

            blob.patch()
            blob.make_public()

            if doc_ref:
                filename_duration = {batch_output_path.split("/")[-1].replace('.mp3', ''): duration}
                push_to_firestore(filename_duration, doc_ref)
            if progress_callback:
                progress_callback(list(created_files))

    if local_run:
        return {
            path: 0 for path in created_files
        }

    return created_files
