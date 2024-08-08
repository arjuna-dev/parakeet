import os
from pathlib import Path
import openai
from mutagen.mp3 import MP3
from google.cloud import storage
from .google_tts_voices import google_tts_voices
from utilities import push_to_firestore

openai.api_key = 'YOUR_OPENAI_API_KEY'

# OpenAI voices mapping for Azerbaijani (hypothetical, replace with actual if different)
openai_voices = {
    "Azerbaijani": {
        "f": ["alloy", "fable"],
        "m": ["echo", "onyx"]
    }
}

def find_matching_voice_openai(language, gender, exclude_voice_id=None):
    voices = openai_voices.get(language, {}).get(gender, [])
    for voice_id in voices:
        if voice_id != exclude_voice_id:
            return voice_id
    raise Exception("No matching voice found")

def language_to_language_code_openai(language):
    # OpenAI does not require a separate language code mapping
    return language

def voice_finder_openai(gender, target_language, exclude_voice_id=None):
    voice_id = find_matching_voice_openai(target_language, gender, exclude_voice_id)
    return voice_id


def openai_synthesize_text(text, voice_id, output_path, doc_ref=None, local_run=False, bucket_name="conversations_audio_files"):
    speech_file_path = Path(output_path)
    response = openai.Audio.create(
        model="tts-1",
        voice=voice_id,
        input=text
    )

    response.stream_to_file(speech_file_path)
    
    if local_run:
        return {output_path: 0}
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
            blob.upload_from_filename(output_path, timeout=600)
        except Exception as e:
            print(f'Error uploading file: {e}')    

        blob.patch()
        blob.make_public()

        if doc_ref:
            filename_duration = {output_path.split("/")[-1].replace('.mp3', ''): duration}
            push_to_firestore(filename_duration, doc_ref)

# Example usage:
# list_openai_voices()
# voice_id = voice_finder_openai("f", "Azerbaijani")
# openai_synthesize_text("Salam Dünya!", voice_id, "output_az_f.mp3")
