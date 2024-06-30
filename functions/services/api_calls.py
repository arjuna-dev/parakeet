from partialjson.json_parser import JSONParser
from utils.google_tts.gcloud_text_to_speech_api import voice_finder_google, google_synthesize_text
from utils.elevenlabs.elevenlabs_api import elevenlabs_tts
from utils.utilities import push_to_firestore, remove_user_from_active_creation_by_id
from utils.utilities import TTS_PROVIDERS
import concurrent.futures
import os
import re
import time
from threading import Timer, Lock

class APICalls:
    def __init__(self, native_language, tts_provider, document_id, document, target_language, document_durations, words_to_repeat_without_punctuation, voice_1=None, voice_2=None, mock=False):
        self.turn_nr = 0
        self.generating_turns = False
        self.narrator_voice, self.narrator_voice_id = voice_finder_google("f", native_language)
        self.voice_1 = voice_1
        self.voice_2 = voice_2
        self.voice_1_id = None
        self.voice_2_id = None
        self.pending_voice_1 = None
        self.pending_voice_2 = None
        self.tts_function = None
        self.tts_provider = tts_provider
        self.document_id = document_id
        self.target_language = target_language
        self.document = document
        self.document_durations = document_durations
        self.words_to_repeat_without_punctuation = words_to_repeat_without_punctuation
        self.select_tts_provider()
        self.push_to_firestore = push_to_firestore
        self.remove_user_from_active_creation_by_id = remove_user_from_active_creation_by_id
        self.mock = mock
        self.line_handler = None
        self.futures = []
        self.executor = concurrent.futures.ThreadPoolExecutor()
        self.request_count = 0
        self.waiting_time = 60
        self.max_concurrent_files = 40
        os.makedirs(document_id, exist_ok=True)
        if self.mock:
            self.tts_function = self.mock_tts
            self.push_to_firestore = self.mock_push_to_firestore
            self.mock_voice_1, self.voice_1_id = voice_finder_google("m", "German")
            self.mock_voice_2, self.voice_2_id = voice_finder_google("f", "German", self.voice_1_id)
            self.mock_narrator_voice, voice_3_id = voice_finder_google("f", "English")

    def select_tts_provider(self):
        if self.tts_provider == TTS_PROVIDERS.GOOGLE.value:
            self.tts_function = google_synthesize_text
        elif self.tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
            self.tts_function = elevenlabs_tts
        else:
            raise Exception("Invalid TTS provider")
        
    def handle_line_1st_API(self, current_line, full_json):

        last_value_path = self.get_last_value_path(full_json)
        last_value = self.get_value_from_path(full_json, last_value_path)
        last_value_path_string = "_".join(map(str, last_value_path))
        filename = self.document_id + "/" + last_value_path_string + ".mp3"

        if '"dialogue":' in current_line:
            self.generating_turns = True
        # Turn increments
        if self.turn_nr + 1 < len(full_json.get('dialogue', [])) and self.generating_turns == True:
            self.turn_nr += 1
            self.push_to_firestore(full_json, self.document, operation="overwrite")
        # Last turn increment
        if any(item in current_line for item in ['"speakers":', '"title":']) and self.generating_turns == True:
            self.generating_turns = False
            self.turn_nr += 1
            self.push_to_firestore(full_json, self.document, operation="overwrite")

        if '"native_language":' in current_line:
            self.futures.append(self.executor.submit(self.tts_function, last_value, self.narrator_voice, filename, self.document_durations))
        elif '"target_language":' in current_line:
            if self.turn_nr % 2 == 0:
                if self.voice_1:
                    self.futures.append(self.executor.submit(self.tts_function, last_value, self.voice_1, filename, self.document_durations))
                else:
                    self.pending_voice_1 = {"text": last_value, "filename": filename}
            else:
                if self.voice_2:
                    self.futures.append(self.executor.submit(self.tts_function, last_value, self.voice_2, filename, self.document_durations))
                else:
                    self.pending_voice_2 = {"text": last_value, "filename": filename}
        if '"title":' in current_line:
            self.futures.append(self.executor.submit(self.tts_function, last_value, self.narrator_voice, filename, self.document_durations))
            self.push_to_firestore(full_json, self.document, operation="overwrite")
        elif '"gender":' in current_line:
            if self.generating_turns:
                if self.turn_nr == 0:
                    self.voice_1, self.voice_1_id = voice_finder_google(last_value, self.target_language)
                    print('self.voice_1: ', self.voice_1)
                    if self.pending_voice_1:
                        self.futures.append(self.executor.submit(self.tts_function, self.pending_voice_1['text'], self.voice_1, self.pending_voice_1['filename'], self.document_durations))
                        self.pending_voice_1 = None
                if self.turn_nr == 1:
                    self.voice_2, self.voice_2_id = voice_finder_google(last_value, self.target_language, self.voice_1_id)
                    print('self.voice_2: ', self.voice_2)
                    if self.pending_voice_2:
                        self.futures.append(self.executor.submit(self.tts_function, self.pending_voice_2['text'], self.voice_2, self.pending_voice_2['filename'], self.document_durations))
                        self.pending_voice_2 = None
        
    def handle_line_2nd_API(self, current_line, full_json):

        if self.request_count >= self.max_concurrent_files:
            print("sleeping")
            time.sleep(self.waiting_time)
            self.request_count = 0

        if self.mock:
            self.use_mock_voices()

        last_value_path = self.get_last_value_path(full_json)
        last_value = self.get_value_from_path(full_json, last_value_path)
        last_value_path_string = "_".join(map(str, last_value_path))
        filename = self.document_id + "/" + last_value_path_string + ".mp3"

        if self.turn_nr + 1 < len(full_json.get('dialogue', [])):
            self.turn_nr += 1
            print("full_json: ", full_json)
            self.push_to_firestore(full_json, self.document, operation="overwrite")

        if '"narrator_translation":' in current_line:
            enclosed_words_objects = self.extract_and_classify_enclosed_words(last_value)
            for index, text_part in enumerate(enclosed_words_objects):
                filename = self.document_id + "/" + last_value_path_string + f'_{index}' + ".mp3"
                if text_part['enclosed']:
                    if not any(element.lower() in text_part['text'].lower().split(' ') for element in self.words_to_repeat_without_punctuation):
                        break
                    voice_to_use = self.voice_1 if self.turn_nr % 2 == 0 else self.voice_2
                    self.futures.append(self.executor.submit(self.tts_function, text_part['text'], voice_to_use, filename, self.document_durations))
                    self.request_count += 1
                else:
                    self.futures.append(self.executor.submit(self.tts_function, text_part['text'], self.narrator_voice, filename, self.document_durations))
                    self.request_count += 1
        elif any(phrase in current_line for phrase in ['"narrator_explanation":', '"narrator_fun_fact":', '"native_language":']):
            self.futures.append(self.executor.submit(self.tts_function, last_value, self.narrator_voice, filename, self.document_durations))
            self.request_count += 1
        elif '"target_language":' in current_line:
            words = [re.sub(r'[^\w\s]', '', word) for word in last_value.split()]
            if not any(word in self.words_to_repeat_without_punctuation for word in words):
                return
            voice_to_use = self.voice_1 if self.turn_nr % 2 == 0 else self.voice_2
            self.futures.append(self.executor.submit(self.tts_function, last_value, voice_to_use, filename, self.document_durations))
            self.request_count += 1

    def get_last_value_path(self, json_obj, path=None):
        """
        Recursively find the path to the last value in a JSON object.
        Args:
        - json_obj: The JSON object (dict or list).
        Returns:
        - A list representing the path to the last value.
        """
        if path is None:
            path = []

        if isinstance(json_obj, dict):
            if not json_obj:
                return path
            last_key = list(json_obj.keys())[-1]
            path.append(last_key)
            return self.get_last_value_path(json_obj[last_key], path)
        
        elif isinstance(json_obj, list):
            if not json_obj:
                return path
            last_index = len(json_obj) - 1
            path.append(last_index)
            return self.get_last_value_path(json_obj[last_index], path)
        else:
            return path

    def get_value_from_path(self, json_obj, path):
        """
        Access the value in a JSON object using the provided path.
        
        Args:
        - json_obj: The JSON object (dict or list).
        - path: The path to the value (list of keys and indexes).
        
        Returns:
        - The value at the specified path.
        """
        value = json_obj
        for key in path:
            value = value[key]
        return value

    def process_response(self, chatGPT_response):
        parser = JSONParser()
        compiled_response = ""
        end_of_line = False
        current_line = []

        for chunk in chatGPT_response:
            is_finished = chunk.choices[0].finish_reason
            if is_finished is not None:
                print("is finished reason: ", is_finished)
                break

            a_chunk = chunk.choices[0].delta.content

            compiled_response += a_chunk
            try:
                rectified_JSON = parser.parse(compiled_response)
            except Exception as e:
                print("json not parsed: ", e)
                continue
            if not rectified_JSON:
                continue

            if "\n" in a_chunk:
                current_line.append(a_chunk)
                end_of_line = True

            if end_of_line == False:
                current_line.append(a_chunk)

            if end_of_line == True:
                current_line_text  = "".join(current_line)
                self.line_handler(current_line_text, rectified_JSON)
                end_of_line = False
                current_line = []
        return rectified_JSON
    
    def extract_and_classify_enclosed_words(self, input_string):
        parts = input_string.split('||')
        result = []
        is_enclosed = False
        
        for part in parts:
            if part:
                result.append({'text': part, 'enclosed': is_enclosed})
            is_enclosed = not is_enclosed
        
        return result
    
    def use_mock_voices(self):
        self.voice_1 = self.mock_voice_1
        self.voice_2 = self.mock_voice_2
        self.narrator_voice = self.mock_narrator_voice

    def mock_tts(self, text, voice_to_use, filename, document_durations):
        print('mock_tts called')
        print('text: ', text)
        print('filename: ', filename)
        print('document_durations: ', document_durations)
        print('voice_to_use: ', voice_to_use, "\n")
        pass

    def mock_push_to_firestore(self, full_json, document, operation="update"):
        print('mock_push_to_firestore called')
        print('full_json: ', full_json)
        print('document: ', document)
        print('operation: ', operation, "\n")
        pass