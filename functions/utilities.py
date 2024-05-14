import os
from enum import Enum

def is_running_locally():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, '_local_tester_chatGPT.py')
    return os.path.isfile(file_path)

class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode.
    GPT_4_TURBO = "gpt-4-turbo" # Supports vision and JSON mode. This points to GPT_4_TURBO_V as of today
    GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2