import os
import datetime
from _local_lesson_generator import generate_lesson
from json_parsers import parse_and_convert_to_speech, parse_and_create_script
import json
from utilities import TTS_PROVIDERS

now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")
dir_name = "Andrew_05.06.21.16.43"

# Load JSON files
with open(f'other/{dir_name}/chatGPT_response.json', 'r') as file:
    chatGPT_response = json.load(file)

with open(f'other/{dir_name}/dialogue.json', 'r') as file:
    dialogue = json.load(file)


selected_tts = input(f"Which TTS provider do you want to use? ({TTS_PROVIDERS.GOOGLE.value}: {TTS_PROVIDERS.GOOGLE.name}, {TTS_PROVIDERS.ELEVENLABS.value}: {TTS_PROVIDERS.ELEVENLABS.name}): ")
selected_tts = int(selected_tts)

assert selected_tts in [TTS_PROVIDERS.GOOGLE.value, TTS_PROVIDERS.ELEVENLABS.value], "Invalid TTS provider"

# Create needed directories
if selected_tts == TTS_PROVIDERS.GOOGLE.value:
  if not os.path.exists(f"other/{dir_name}/audio_google"):
    os.mkdir(f"other/{dir_name}/audio_google")
  audio_files_directory = f"other/{dir_name}/audio_google"

elif selected_tts == TTS_PROVIDERS.ELEVENLABS.value:
  if not os.path.exists(f"other/{dir_name}/audio_elevenlabs"):
    os.mkdir(f"other/{dir_name}/audio_elevenlabs")
  audio_files_directory = f"other/{dir_name}/audio_elevenlabs"

use_concurrency = False if selected_tts == TTS_PROVIDERS.ELEVENLABS.value else True

# Convert to speech
# parse_and_convert_to_speech(chatGPT_response, audio_files_directory, selected_tts, "English (United States)", "German (Germany)", dialogue, local_run=True, use_concurrency=use_concurrency)

# Create script
script = parse_and_create_script(chatGPT_response)
print(script)

# Create needed directories
if not os.path.exists("other/narrator_audio_files"):
  os.mkdir("other/narrator_audio_files")
narrator_audio_files_directory = "other/narrator_audio_files"

# Generate lesson
save_directory = f"other/{dir_name}"
save_as = f"lesson_{now}"
generate_lesson(script, save_directory, save_as, audio_files_directory, narrator_audio_files_directory)
