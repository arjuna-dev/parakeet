import os
from enum import Enum
import json
from google_tts.gcloud_text_to_speech_api import find_matching_voice_google, create_google_voice

class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode.
    GPT_4_TURBO = "gpt-4-turbo" # Supports vision and JSON mode. This points to GPT_4_TURBO_V as of today
    GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode
    GPT_4o = "gpt-4o"

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2

def check_if_running_locally():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, 'local_scripts')
    return os.path.isdir(file_path)

is_running_locally = check_if_running_locally()

def convert_string_to_JSON(string):
    try:
        json_object = json.loads(string)
    except Exception as e:
        raise Exception(f"Error converting string to JSON: {e}")
    return json_object

def voice_finder(gender, target_language, tts_provider, exclude_voice_id=None):

    if tts_provider == TTS_PROVIDERS.GOOGLE.value:

        target_language_code = language_to_language_code(target_language)
        speaker_voice_id = find_matching_voice_google(target_language, gender, exclude_voice_id)
        speaker_voice = create_google_voice(target_language_code, speaker_voice_id)

        return speaker_voice, speaker_voice_id

    elif tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
        # TODO: Implement for elevenlabs

        speaker_voice = find_voice_elevenlabs(elevenlabs_voices, target_language, gender, exclude_voice_id)
