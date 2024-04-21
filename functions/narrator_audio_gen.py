import json
from elevenlabs_api import elevenlabs_tts

with open('narrator_pool.json', 'r') as file:
    narrator_pool = json.load(file)

for section_key, section in narrator_pool.items():
    for key, value in section.items():
        # Generate a custom file name based on section and key
        file_name = f"{section_key}_{key}.mp3"  # Creates a name like "opening_phrases_5_0.mp3"
        
        elevenlabs_tts(value, f"audio/{file_name}")