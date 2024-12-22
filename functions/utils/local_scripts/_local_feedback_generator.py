import json
import sys
import os
import asyncio
from google.cloud import firestore
from mutagen.mp3 import MP3
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from elevenlabs.elevenlabs_api import elevenlabs_tts
from google_tts.gcloud_text_to_speech_api import google_synthesize_text, create_google_voice
from google_tts.google_tts_voices import google_tts_voices

def load_transcripts():
    with open(os.path.join(os.path.dirname(__file__), '_local_feedback_transcripts'), 'r', encoding='utf-8') as f:
        return json.load(f)

def get_voice_details(language):
    for voice in google_tts_voices:
        if voice["language"].lower() == language.lower():
            return voice["language_code"], voice["voice_id"]
    return None, None

def generate_feedback_audio(text, language, index, feedback, bucket_name="pronunciation_feedback"):
    language_code, voice_name = get_voice_details(language)
    if not language_code:
        print(f"Unsupported language: {language}")
        return None

    voice = create_google_voice(language_code, voice_name)
    file_name = f"feedback_{language}_{feedback}_{index}.mp3"

    try:
        google_synthesize_text(text, voice, file_name, bucket_name=bucket_name)
        print(f"Generated audio for {language} - {text}")
        return
    except Exception as e:
        print(f"Error generating audio for {language}: {str(e)}")
        return None

def generate_all_feedback():
    transcripts = load_transcripts()
    results = {}

    for language, phrases in transcripts.items():
        language_results = []
        for i, phrase in enumerate(phrases):
            if i > 2:
                feedback = "negative"
            else:
                feedback = "positive"
            audio_path = generate_feedback_audio(phrase, language, i, feedback)

if __name__ == "__main__":
    generate_all_feedback()

