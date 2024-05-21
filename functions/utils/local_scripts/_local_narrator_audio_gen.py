import json
import sys
import os
from google.cloud import firestore
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from elevenlabs.elevenlabs_api import elevenlabs_tts
from google_tts.gcloud_text_to_speech_api import google_synthesize_text, create_google_voice

narrator_voice = create_google_voice("en-US", "en-US-Journey-F")
narrator_file_durations = {}

with open('_local_narrator_pool.json', 'r') as file:
    narrator_pool = json.load(file)

for section_key, section in narrator_pool.items():
    for key, value in section.items():
        file_name = f"{section_key}_{key}.mp3"
        # elevenlabs_tts(value, f"audio/{file_name}")
        narrator_file_durations.update(google_synthesize_text(value, narrator_voice, f"google_tts/narrator_english/{file_name}",  bucket_name="narrator_audio_files"))
narrator_file_durations.update({"one_second_break": 1.0, "five_second_break": 5.0})

db = firestore.Client()
doc_ref = db.collection('narrator_audio_files_durations/google_tts/narrator_english').document()
doc_ref.set(narrator_file_durations, merge=True)


# narrator_voice = "GoZIEyk9z3H2szw545o8" 
# elevenlabs_tts("Text to generate",narrator_voice, f"audio/{"file_name"}.mp3")