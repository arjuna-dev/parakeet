import requests
from google.cloud import storage
from utilities import is_running_locally
import os

#       ___                                   ___             __                
#      /\_ \                                 /\_ \           /\ \               
#    __\//\ \      __   __  __     __    ___ \//\ \      __  \ \ \____    ____  
#  /'__`\\ \ \   /'__`\/\ \/\ \  /'__`\/' _ `\ \ \ \   /'__`\ \ \ '__`\  /',__\ 
# /\  __/ \_\ \_/\  __/\ \ \_/ |/\  __//\ \/\ \ \_\ \_/\ \L\.\_\ \ \L\ \/\__, `\
# \ \____\/\____\ \____\\ \___/ \ \____\ \_\ \_\/\____\ \__/.\_\\ \_,__/\/\____/
#  \/____/\/____/\/____/ \/__/   \/____/\/_/\/_/\/____/\/__/\/_/ \/___/  \/___/ 


if is_running_locally():
    from dotenv import load_dotenv
    load_dotenv()
    ELEVENLABS_API_KEY = os.getenv('ELEVENLABS_API_KEY')
else:
    ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY")

# Function to get the list of available voices from the Eleven Labs
def get_voices():
  url = "https://api.elevenlabs.io/v1/voices"

  headers = {
    "Accept": "application/json",
    "xi-api-key": ELEVENLABS_API_KEY,
    "Content-Type": "application/json"
  }

  response = requests.get(url, headers=headers)
  data = response.json()

  for voice in data['voices']:
    print(f"{voice['name']}; {voice['voice_id']}")


def elevenlabs_tts(text, voice_id, output_path, local_run=False, bucket_name="conversations_audio_files"):

    CHUNK_SIZE = 1024

    tts_url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream"

    headers = {
    "Accept": "application/json",
    "xi-api-key": ELEVENLABS_API_KEY
    }

    data = {
    "text": text,
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.8,
            "style": 0.0,
            "use_speaker_boost": True
        }
    }

    if os.path.exists(output_path):
        print(f"File {output_path} already exists")
        return

    response = requests.post(tts_url, headers=headers, json=data, stream=True)

    if response.ok:
        with open(output_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                f.write(chunk)
        if local_run:
            print(f"Audio content written to file {output_path}")
            return
        else:
            blob_name = f"{output_path}"
            storage_client = storage.Client()
            bucket = storage_client.get_bucket(bucket_name)
            bucket.reload(timeout=300)
            blob = bucket.blob(blob_name)
            blob.upload_from_filename(output_path)
            blob.make_public()
    else:
        print(response.text)

# narrator_voice = "GoZIEyk9z3H2szw545o8"
# elevenlabs_tts("German", narrator_voice, "target_language.mp3", local_run=True)