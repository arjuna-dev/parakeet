import os
import random
import script_sequences as sequences
from elevenlabs_api import elevenlabs_tts, find_voice_elevenlabs
from google_tts_voices import google_tts_voices, sleep_time_according_to_rate_limit
from gcloud_text_to_speech_api import find_matching_voice_google, google_synthesize_text, create_google_voice
import concurrent.futures
from elevenlabs_api_voices import elevenlabs_voices
from utilities import TTS_PROVIDERS


def extract_and_classify_enclosed_words(input_string):
    parts = input_string.split('||')
    
    result = []
    
    is_enclosed = False
    
    for part in parts:
        if part:
            result.append({'text': part, 'enclosed': is_enclosed})
        is_enclosed = not is_enclosed
    
    return result

def parse_and_create_script(data, words_to_repeat):
    script = []

    random_i = random.randint(0, len(sequences.intro_sequences) - 1)
    intro_sequence = sequences.intro_sequences[random_i]()
    script.extend(intro_sequence)

    for i, sentence in enumerate(data["dialogue"]):
        script.append(f"dialogue_{i}_target_language")

    script.extend(sequences.intro_outro_sequence_1())

    # Process each turn in the dialogue
    for i, sentence in enumerate(data["dialogue"]):

        native_sentence = f"dialogue_{i}_native_language"
        target_sentence = f"dialogue_{i}_target_language"

        narrator_explanation = f"dialogue_{i}_narrator_explanation"
        narrator_fun_fact = f"dialogue_{i}_narrator_fun_fact"
        
        sentence_sequence = sequences.sentence_sequence_1(native_sentence, target_sentence, narrator_explanation, narrator_fun_fact, is_first_sentence=True) if i == 0 else sequences.sentence_sequence_1(native_sentence, target_sentence, narrator_explanation, narrator_fun_fact)
        script.extend(sentence_sequence)

        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):
            text = split_sentence["narrator_translation"]

            # Classify and process the text into parts enclosed by || (target_language text)
            classified_text_1 = extract_and_classify_enclosed_words(text)
            narrator_translations_chunk = []
            for index, part in enumerate(classified_text_1):
                narrator_translation = f"dialogue_{i}_split_sentence_{j}_narrator_translation_{index}"
                narrator_translations_chunk.append(narrator_translation)

            split_native = f"dialogue_{i}_split_sentence_{j}_native_language"
            split_target = f"dialogue_{i}_split_sentence_{j}_target_language"

            word_objects = []
            for index, word in enumerate(split_sentence['words']):
                word_file = f"dialogue_{i}_split_sentence_{j}_words_{index}_target_language"
                text = word["narrator_translation"]

                # Classify and process the text into parts enclosed by || (target_language text)
                classified_text_2 = extra_filect_and_classify_enclosed_words(text)
                narrator_translations = []
                for index2, part in enumerate(classified_text_2):
                    narrator_translation = f"dialogue_{i}_split_sentence_{j}_words_{index}_narrator_translation_{index2}"
                    narrator_translations.append(narrator_translation)

                if word["target_language"] in words_to_repeat:
                    word_objects.append({"word": word_file, "translation": narrator_translations})

            chunk_sequence = sequences.chunk_sequence_1(narrator_translations_chunk, split_native, split_target, word_objects, j)
            script.extend(chunk_sequence)

        random_sentence_i = random.randint(0, i)
        number_of_chunks = len(data["dialogue"][random_sentence_i]["split_sentence"])-1
        random_chunk_i = random.randint(0, number_of_chunks)
        target = f"dialogue_{random_sentence_i}_split_sentence_{random_chunk_i}_target_language"
        native = f"dialogue_{random_sentence_i}_split_sentence_{random_chunk_i}_native_language"
        active_recall_sequence = sequences.active_recall_sequence_1(native, target)
        script.extend(active_recall_sequence)

    return script

def language_to_language_code(language):
    for voice in google_tts_voices:
        if voice['language'] == language:
            return voice['language_code']
    raise Exception(f"Language code not found for {language}")

def parse_and_convert_to_speech(data, directory, tts_provider, native_language, target_language, speakers, title, number_of_audio_files, local_run=False, use_concurrency=True):

    speaker_1_gender = speakers["speaker_1"]["gender"].lower()
    speaker_2_gender = speakers["speaker_2"]["gender"].lower()

    if tts_provider == TTS_PROVIDERS.GOOGLE.value:

        target_language_code = language_to_language_code(target_language)
        native_language_code = language_to_language_code(native_language)

        speaker_1_voice_id = find_matching_voice_google(target_language, speaker_1_gender)
        speaker_2_voice_id = find_matching_voice_google(target_language, speaker_2_gender, exclude_voice_id=speaker_1_voice_id)
        narrator_voice_id = find_matching_voice_google(native_language, "f")

        speaker_1_voice = create_google_voice(target_language_code, speaker_1_voice_id)
        speaker_2_voice = create_google_voice(target_language_code, speaker_2_voice_id)
        narrator_voice = create_google_voice(native_language_code, narrator_voice_id)

        # TODO: Implement rate limiting if needed
        # sleep_time = sleep_time_according_to_rate_limit(speaker_1_voice, number_of_audio_files)

        tts_function = google_synthesize_text

    elif tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
        narrator_voice = "GoZIEyk9z3H2szw545o8" #Ava - Calm and slow

        speaker_1_voice = find_voice_elevenlabs(elevenlabs_voices, target_language, speaker_1_gender)
        speaker_2_voice = find_voice_elevenlabs(elevenlabs_voices, target_language, speaker_2_gender, exclude_voice_id=speaker_1_voice)

        if speaker_1_voice is None:
            speaker_1_voice = find_voice_elevenlabs(elevenlabs_voices, "English (United States)", speaker_1_gender)

        if speaker_2_voice is None:
            speaker_2_voice = find_voice_elevenlabs(elevenlabs_voices, "English (United States)", speaker_2_gender, exclude_voice_id=speaker_1_voice)

        tts_function = elevenlabs_tts


    # add a subdirectory to the directory
    os.makedirs(f"{directory}", exist_ok=True)
    fileDurations = {}
    
    if (tts_provider == TTS_PROVIDERS.GOOGLE.value):
        fileDurations.update(tts_function(title, narrator_voice, f"{directory}/title.mp3", local_run))
        fileDurations.update(tts_function(native_language, narrator_voice, f"{directory}/native_language.mp3", local_run))
        fileDurations.update(tts_function(target_language, narrator_voice, f"{directory}/target_language.mp3", local_run))
    else:
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
    for speaker_key, speaker_info in speakers.items():
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
                    futures.append(execute_task(tts_function, text, current_speaker_voice, f"{directory}/{narrator_translation}.mp3", local_run))
                elif not part['enclosed']:
                    text = part['text']
                    narrator_translation = f"dialogue_{i}_split_sentence_{j}_narrator_translation_{index}"
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
                fileDurations.update(result)
            executor.shutdown()
        else:
            result = "Parsed without concurrency"

    print (result)
    return fileDurations
