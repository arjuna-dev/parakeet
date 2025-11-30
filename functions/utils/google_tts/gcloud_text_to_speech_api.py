import os
import sys
import time
from pathlib import Path
from google.cloud import texttospeech, storage, firestore
from mutagen.mp3 import MP3
from .google_tts_voices import google_tts_voices
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from utilities import push_to_firestore

def list_voices(language_code=None):
    client = tts.TextToSpeechClient()
    response = client.list_voices(language_code=language_code)
    voices = sorted(response.voices, key=lambda voice: voice.name)

    print(f" Voices: {len(voices)} ".center(60, "-"))
    for voice in voices:
        languages = ", ".join(voice.language_codes)
        name = voice.name
        gender = tts.SsmlVoiceGender(voice.ssml_gender).name
        rate = voice.natural_sample_rate_hertz
        print(f"{languages:<8} | {name:<24} | {gender:<8} | {rate:,} Hz")

def language_to_language_code(language):
    for voice in google_tts_voices:
        if voice['language'] == language:
            return voice['language_code']
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
    
    voice = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_id, model_name='gemini-2.5-flash-tts')
    return voice


def voice_finder_google(gender, target_language, exclude_voice_id=None, narrator_voice=False):
    
    target_language_code = language_to_language_code(target_language)
    speaker_voice_id = find_matching_voice_google(gender, exclude_voice_id, narrator_voice)
    speaker_voice = create_google_voice(target_language_code, speaker_voice_id)

    return speaker_voice, speaker_voice_id

def google_synthesize_text(text, voice, output_path, doc_ref = None, local_run=False, bucket_name="conversations_audio_files", first_API_call=False, language_level="A1", narrator_voice=False, max_retries=5):
    client = texttospeech.TextToSpeechClient()
    if narrator_voice == False:
        print("speaker_voice: ", voice)
        if first_API_call == False:
            synthesis_input = texttospeech.SynthesisInput(text=text, prompt=f'This is for practicing conversation while learning languages, so speak clearly and at a {language_level} pace. Also adjust the speed according to the number of words in the text.')
        else:
            synthesis_input = texttospeech.SynthesisInput(text=text, prompt=f'This is for practicing conversation while learning languages, it is part of conversation between two speakers so speak naturally, slowly and in a friendly tone.')
    else:
        synthesis_input = texttospeech.SynthesisInput(text=text, prompt='This is narrator voice guiding the user through the language lesson. Speak naturally and in a friendly tone.')
        print("narrator_voice: ", voice)
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = None
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            response = client.synthesize_speech(
                input=synthesis_input, voice=voice, audio_config=audio_config
            )
            break  # Success, exit retry loop
        except Exception as e:
            retry_count += 1
            if retry_count >= max_retries:
                print(f'Error synthesizing text after {max_retries} retries: {e}')
                raise
            wait_time = 2 ** retry_count  # Exponential backoff: 2, 4, 8, 16, 32 seconds
            print(f'Error synthesizing text (attempt {retry_count}/{max_retries}): {e}')
            print(f'Retrying in {wait_time} seconds...')
            time.sleep(wait_time)

    with open(f"{output_path}", "wb") as out:
        out.write(response.audio_content)

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