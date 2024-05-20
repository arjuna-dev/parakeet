import json
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from elevenlabs.elevenlabs_api import elevenlabs_tts
import google_tts.gcloud_text_to_speech_api as gcloud_tts

narrator_voice = gcloud_tts.choose_voice('en-US', "f", "en-US-Standard-C")

with open('_local_narrator_pool.json', 'r') as file:
    narrator_pool = json.load(file)

for section_key, section in narrator_pool.items():
    for key, value in section.items():
        file_name = f"{section_key}_{key}.mp3"
        # elevenlabs_tts(value, f"audio/{file_name}")
        gcloud_tts.synthesize_text(value, narrator_voice, f"google_tts/narrator_english/{file_name}",  bucket_name="narrator_audio_files")

# narrator_voice = "GoZIEyk9z3H2szw545o8" 
# elevenlabs_tts("Text to generate",narrator_voice, f"audio/{"file_name"}.mp3")