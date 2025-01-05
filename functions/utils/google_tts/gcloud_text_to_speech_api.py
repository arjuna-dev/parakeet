import os
import sys
from google.cloud import texttospeech, storage
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

def find_matching_voice_google(language, gender, exclude_voice_id=None):
    voice_id = None
    for voice in google_tts_voices:
        if voice.get('language') == language and voice.get('gender') == gender and voice.get('voice_id') != exclude_voice_id:
            voice_id = voice.get('voice_id')
            return voice_id
    raise Exception("No matching voice found")

def create_google_voice(language_code, voice_id):
    voice = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_id)
    return voice

def voice_finder_google(gender, target_language, exclude_voice_id=None):
    target_language_code = language_to_language_code(target_language)
    speaker_voice_id = find_matching_voice_google(target_language, gender, exclude_voice_id)
    speaker_voice = create_google_voice(target_language_code, speaker_voice_id)

    return speaker_voice, speaker_voice_id

def google_synthesize_text(text, voice, output_path, doc_ref = None, local_run=False, bucket_name="conversations_audio_files", make_public=True):
    client = texttospeech.TextToSpeechClient()
    synthesis_input = texttospeech.SynthesisInput(text=text)
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        # reduce the speed of the audio
        speaking_rate=0.9
    )

    try:
        response = client.synthesize_speech(
            input=synthesis_input, voice=voice, audio_config=audio_config
        )
    except Exception as e:
        print(f'Error synthesizing text: {e}')

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
