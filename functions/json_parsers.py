
import os
import random
import script_sequences as sequences
from google_tts_language_codes import language_codes
from elevenlabs_api import elevenlabs_tts
import gcloud_text_to_speech_api as gcloud_tts
from enum import Enum
import concurrent.futures
from elevenlabs_api_voices import elevenlabs_voices

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2

def extract_and_classify_enclosed_words(input_string):
    parts = input_string.split('||')
    
    result = []
    
    is_enclosed = False
    
    for part in parts:
        if part:
            result.append({'text': part, 'enclosed': is_enclosed})
        is_enclosed = not is_enclosed
    
    return result

def parse_and_create_script (data):
    script = []

    index = random.randint(0, len(sequences.intro_sequences) - 1)
    intro_sequence = sequences.intro_sequences[index]()
    script.extend(intro_sequence)

    for i, sentence in enumerate(data["dialogue"]):
        script.append(f"dialogue_{i}_{"target_language"}")

    # Process each turn in the dialogue
    for i, sentence in enumerate(data["dialogue"]):

        native_sentence = f"dialogue_{i}_{"native_language"}"
        target_sentence = f"dialogue_{i}_{"target_language"}"

        narrator_explanation = f"dialogue_{i}_{"narrator_explanation"}"
        narrator_fun_fact = f"dialogue_{i}_{"narrator_fun_fact"}"
        
        index = random.randint(0, len(sequences.sentence_sequences) - 1)
        sentence_sequence = sequences.sentence_sequences[index](native_sentence, target_sentence, narrator_explanation, narrator_fun_fact)
        script.extend(sentence_sequence)
        print("Sentence sequence: ", index+1)

        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):
            text = split_sentence["narrator_translation"]

            # Classify and process the text into parts enclosed by || (target_language text)
            classified_text = extract_and_classify_enclosed_words(text)
            narrator_translations = []
            for index, part in enumerate(classified_text):
                narrator_translation = f"dialogue_{i}_split_sentence_{j}_narrator_translation_{index}"
                narrator_translations.append(narrator_translation)

            split_native = f"dialogue_{i}_split_sentence_{j}_{"native_language"}"
            split_target = f"dialogue_{i}_split_sentence_{j}_{"target_language"}"

            word_objects = []
            for index, words in enumerate(split_sentence['words']):
                word = f"dialogue_{i}_split_sentence_{j}_words_{index}_target_language"

                # Classify and process the text into parts enclosed by || (target_language text)
                classified_text = extract_and_classify_enclosed_words(text)
                narrator_translations = []
                for index2, part in enumerate(classified_text):
                    narrator_translation = f"dialogue_{i}_split_sentence_{j}_words_{index}_narrator_translation_{index2}"
                    narrator_translations.append(narrator_translation)

                word_objects.append({"word": word, "translation": narrator_translations})

            index = random.randint(0, len(sequences.chunk_sequences) - 1)
            chunk_sequence = sequences.chunk_sequence_3rep_new(narrator_translations, split_native, split_target, word_objects)
            script.extend(chunk_sequence)
            print("Chunk sequence: ", index+1)

    return script

def language_to_language_code(language):
    print('language: ', language)
    if language in language_codes:
        return language_codes[language]
    else:
        return "Language not found"

def find_voice_elevenlabs(voices, language, gender, exclude_voice_id=None):
    for voice in voices:
        print('voice[language]: ', voice['language'])
        print('language : ', language )
        print('voice[gender]: ', voice['gender'])
        print('gender: ', gender)
        if (voice['language'] == language and voice['gender'] == gender and
                voice['voice_id'] != exclude_voice_id):
            return voice['voice_id']
    return None

def parse_and_convert_to_speech(data, directory, tts_provider, native_language, target_language, metadata, local_run=False, use_concurrency=True):

    speaker_1_gender = metadata["speakers"]["speaker_1"]["gender"].lower()
    speaker_2_gender = metadata["speakers"]["speaker_2"]["gender"].lower()

    if tts_provider == TTS_PROVIDERS.GOOGLE.value:
        # Check if native_language and target_language are keys in the language_codes dictionary
        if native_language not in language_codes:
            print(f"Native language {native_language} not found in language codes")
            return
        if target_language not in language_codes:
            print(f"Target language {target_language} not found in language codes")
            return

        language_code = language_to_language_code(target_language)

        speaker_1_voice = gcloud_tts.choose_voice(language_code, speaker_1_gender)
        speaker_2_voice = gcloud_tts.choose_voice(language_code, speaker_2_gender)
        narrator_voice = gcloud_tts.choose_voice('en-US', "f", "en-US-Standard-C")

        tts_function = gcloud_tts.synthesize_text

    elif tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
        narrator_voice = "GoZIEyk9z3H2szw545o8" #Ava - Calm and slow

        speaker_1_voice = find_voice_elevenlabs(elevenlabs_voices, target_language, speaker_1_gender)
        speaker_2_voice = find_voice_elevenlabs(elevenlabs_voices, target_language, speaker_2_gender, exclude_voice_id=speaker_1_voice)

        if speaker_1_voice is None:
            speaker_1_voice = find_voice_elevenlabs(elevenlabs_voices, "English (United States)", speaker_1_gender)

        if speaker_2_voice is None:
            speaker_2_voice = find_voice_elevenlabs(elevenlabs_voices, "English (United States)", speaker_2_gender, exclude_voice_id=speaker_1_voice)

        tts_function = elevenlabs_tts

    title = metadata["title"]

    # add a subdirectory to the directory
    os.makedirs(f"{directory}", exist_ok=True)

    tts_function(title, narrator_voice, f"{directory}/title.mp3", local_run)
    tts_function(native_language, narrator_voice, f"{directory}/native_language.mp3", local_run)
    tts_function(target_language, narrator_voice, f"{directory}/target_language.mp3", local_run)


    futures = []
    executor = concurrent.futures.ThreadPoolExecutor() if use_concurrency else None

    def execute_task(func, *args):
        nonlocal executor
        if use_concurrency:
            if executor._shutdown:
                executor = concurrent.futures.ThreadPoolExecutor()
            return executor.submit(func, *args)
        else:
            return func(*args)  # Execute the function directly

    # Process speaker names
    for speaker_key, speaker_info in metadata["speakers"].items():
        text = speaker_info["name"]
        speaker = f"speakers_{speaker_key}_name"
        futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{speaker}.mp3", local_run))

    for i, sentence in enumerate(data["dialogue"]):
        current_speaker_voice = speaker_1_voice if i % 2 == 0 else speaker_2_voice
        text = sentence["native_language"]
        native = f"dialogue_{i}_native_language"
        futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{native}.mp3", local_run))
        text = sentence["target_language"]
        target = f"dialogue_{i}_target_language"
        futures.append(execute_task(tts_function, text, current_speaker_voice, f"{directory}/{target}.mp3", local_run))
        for key in ["narrator_explanation", "narrator_fun_fact"]:
            text = sentence[key]
            narrator = f"dialogue_{i}_{key}"
            futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{narrator}.mp3", local_run))
        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):

            text = split_sentence["narrator_translation"]
            # Classify and process the text into parts enclosed by || (target_language text)
            classified_text = extract_and_classify_enclosed_words(text)
            for index, part in enumerate(classified_text):
                if part['enclosed']:
                    text = part['text']
                    narrator_translation = f"dialogue_{i}_split_sentence_{j}_narrator_translation_{index}"
                    print("narrator_translation1: ", narrator_translation)
                    futures.append(execute_task(tts_function, text, current_speaker_voice, f"{directory}/{narrator_translation}.mp3", local_run))
                elif not part['enclosed']:
                    text = part['text']
                    narrator_translation = f"dialogue_{i}_split_sentence_{j}_narrator_translation_{index}"
                    print("narrator_translation2: ", narrator_translation)
                    futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{narrator_translation}.mp3", local_run))

            text = split_sentence["native_language"]
            native_chunk = f"dialogue_{i}_split_sentence_{j}_native_language"
            futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{native_chunk}.mp3", local_run))

            text = split_sentence["target_language"]
            target_chunk = f"dialogue_{i}_split_sentence_{j}_target_language"
            futures.append(execute_task(tts_function, text, current_speaker_voice, f"{directory}/{target_chunk}.mp3", local_run))

            for index, word in enumerate(split_sentence['words']):
                word_text = word["target_language"]
                narrator_translation_text = word["narrator_translation"]
                word_file_name = f"dialogue_{i}_split_sentence_{j}_words_{index}_target_language"
                narrator_translation_file_name = f"dialogue_{i}_split_sentence_{j}_words_{index}_narrator_translation"

                # Classify and process the text into parts enclosed by || (target_language text)
                classified_text = extract_and_classify_enclosed_words(narrator_translation_text)
                for index2, part in enumerate(classified_text):
                    if part['enclosed']:
                        text = part['text']
                        narrator_translation = f"dialogue_{i}_split_sentence_{j}_words_{index}_narrator_translation_{index2}"
                        futures.append(execute_task(tts_function, text, current_speaker_voice, f"{directory}/{narrator_translation}.mp3", local_run))
                    elif not part['enclosed']:
                        text = part['text']
                        narrator_translation = f"dialogue_{i}_split_sentence_{j}_words_{index}_narrator_translation_{index2}"
                        futures.append(execute_task(tts_function, text, narrator_voice, f"{directory}/{narrator_translation}.mp3", local_run))

                futures.append(execute_task(tts_function, word_text, current_speaker_voice, f"{directory}/{word_file_name}.mp3", local_run))

        if use_concurrency:
            # If concurrency is used, wait for all futures to complete
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
            executor.shutdown()
        else:
            result = "Parsed without concurrency"

    print (result)
