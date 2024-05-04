
import os
import random
import string
import script_sequences as sequences
from google_tts_language_codes import language_codes
from elevenlabs_api import elevenlabs_tts
import gcloud_text_to_speech_api as gcloud_tts
from enum import Enum

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2

def split_words(sentence):
  additional_chars = '“”‘’—–…«»„©®™£€¥×÷°'
  punctuation = string.punctuation + additional_chars
  words = sentence.split()
  words = [word.strip(punctuation) for word in words]
  return words

def parse_and_create_script(data):
    script = []

    index = random.randint(0, len(sequences.intro_sequences) - 1)
    intro_sequence = sequences.intro_sequences[index]("title", "target_language")
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
            split_narrator_fun_fact = f"dialogue_{i}_split_sentence_{j}_{"narrator_fun_fact"}"
            split_native = f"dialogue_{i}_split_sentence_{j}_{"native_language"}"
            split_target = f"dialogue_{i}_split_sentence_{j}_{"target_language"}"

            words = []
            for index, value in enumerate(split_words(split_sentence['target_language'])):
                target_word = f"dialogue_{i}_split_sentence_{j}_target_language_{index}"
                words.append(target_word)

            index = random.randint(0, len(sequences.chunk_sequences) - 1)
            chunk_sequence = sequences.chunk_sequences[index](split_narrator_fun_fact, split_native, split_target, words)
            script.extend(chunk_sequence)
            print("Chunk sequence: ", index+1)

    return script

def language_to_language_code(language):
    print('language: ', language)
    if language in language_codes:
        return language_codes[language]
    else:
        return "Language not found"

def parse_and_convert_to_speech(data, directory, tts_provider):

    if tts_provider == TTS_PROVIDERS.GOOGLE.value:
        target_language = data["target_language"]
        speaker_1_gender = data["speakers"]["speaker_1"]["gender"].lower()
        speaker_2_gender = data["speakers"]["speaker_2"]["gender"].lower()

        target_language = data["target_language"]

        language_code = language_to_language_code(target_language)

        speaker_1_voice = gcloud_tts.choose_voice(language_code, speaker_1_gender)
        speaker_2_voice = gcloud_tts.choose_voice(language_code, speaker_2_gender)
        narrator_voice = gcloud_tts.choose_voice('en-US', "f", "en-US-Standard-C")

        tts_function = gcloud_tts.synthesize_text

    elif tts_provider == TTS_PROVIDERS.ELEVENLABS.value:
        narrator_voice = "GoZIEyk9z3H2szw545o8" #Ava - Calm and slow
        speaker_1_voice = "LcfcDJNUP1GQjkzn1xUU"
        speaker_2_voice = "5Q0t7uMcjvnagumLfvZi"

        tts_function = elevenlabs_tts


    # add a subdirectory to the directory
    os.makedirs(f"{directory}/audio", exist_ok=True)

    text = data["title"]
    tts_function(text, narrator_voice, f"{directory}/audio/{"title"}.mp3")

    # Process speaker names
    for speaker_key, speaker_info in data["speakers"].items():
        text = speaker_info["name"]
        speaker = f"speakers_{speaker_key}_name"
        tts_function(text, narrator_voice, f"{directory}/audio/{speaker}.mp3")

    # Process each turn in the dialogue
    for i, sentence in enumerate(data["dialogue"]):
        current_speaker_voice = speaker_1_voice if i % 2 == 0 else speaker_2_voice

        text = sentence["native_language"]
        native = f"dialogue_{i}_{"native_language"}"
        tts_function(text, narrator_voice, f"{directory}/audio/{native}.mp3")

        text = sentence["target_language"]
        target = f"dialogue_{i}_{"target_language"}"
        tts_function(text, current_speaker_voice, f"{directory}/audio/{target}.mp3")

        for key in ["narrator_explanation", "narrator_fun_fact"]:
            text = sentence[key]
            narrator = f"dialogue_{i}_{key}"
            tts_function(text, narrator_voice, f"{directory}/audio/{narrator}.mp3")

        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):
            text = split_sentence["narrator_fun_fact"]
            fun_fact = f"dialogue_{i}_split_sentence_{j}_{"narrator_fun_fact"}"
            tts_function(text, narrator_voice, f"{directory}/audio/{fun_fact}.mp3")
            
            text = split_sentence["native_language"]
            native_chunk = f"dialogue_{i}_split_sentence_{j}_{"native_language"}"
            tts_function(text, narrator_voice, f"{directory}/audio/{native_chunk}.mp3")
            
            text = split_sentence["target_language"]
            target_chunk = f"dialogue_{i}_split_sentence_{j}_{"target_language"}"
            tts_function(text, current_speaker_voice, f"{directory}/audio/{target_chunk}.mp3")
            
            for index, value in enumerate(split_words(split_sentence['target_language'])):
                text = value
                word = f"dialogue_{i}_split_sentence_{j}_target_language_{index}"
                tts_function(text, current_speaker_voice, f"{directory}/audio/{word}.mp3")
