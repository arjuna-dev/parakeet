import os
import requests
import json
import openai
from firebase_functions import firestore_fn, https_fn, options
from firebase_admin import initialize_app, firestore
import google.cloud.firestore
import string
from elevenlabs_api import elevenlabs_tts
import datetime
from lesson_generator import generate_lesson
from enum import Enum
from script_sequences import sentence_sequence_1, chunk_sequence_1, intro_sequence_1
import gcloud_text_to_speech_api as gcloud_tts


now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

def prompt(requested_scenario, native_language, target_language, language_level, keywords, length):
   return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 characters. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the dialogue. If no keywords are provided leave the field empty. If there are spelling mistakes in the content request, fix them. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The more advanced language levels could have more than one sentence per turn. The sentence of each turn should be split in chunks of maximum 4 words that have grammatical cohesion and make sense. The main original dialogue happens in the target_language, the translations of it should be as literal as possible as well as in the  the split sentences. Skip introductions between speakers unless specified and go straight to the topic of conversation. The narrator_explanation and narrator_fun_fact keys are always in native_language, when quoting the target language the text should be enclosed in double vertical bars (||). The following is an example of a JSON file enclosed in triple equals symbols:

JSON: ===
{{
    "title": "Learning Electrical Engineering",
    "all_turns": [
        {{
            "target_language": "Primero, coloca el pcb con cuidado.",
            "native_language": "First, place the pcb carefully."
        }},
        {{
            "target_language": "¿Debo conectar los cables ahora?",
            "native_language": "Should I connect the wires now?"
        }},
        {{
            "target_language": "Sí, sigue el diagrama para el cableado.",
            "native_language": "Yes, follow the diagram for the wiring."
        }},
        {{
            "target_language": "¿Está esta la orientación correcta?",
            "native_language": "Is this the correct orientation?"
        }},
        {{
            "target_language": "Ajústalo un poco a la izquierda.",
            "native_language": "Adjust it slightly to the left."
        }},
        {{
            "target_language": "¿Así?",
            "native_language": "Like this?"
        }}
    ],
    "requested_scenario": "I am being taught electrical engineering",
    "keywords": [
        "instructions",
        "pcb"
    ],
    "native_language": "English",
    "target_language": "Spanish",
    "language_level": "A1",
    "speakers": {{
        "speaker_1": {{
            "name": "Carlos",
            "gender": "m"
        }},
        "speaker_2": {{
            "name": "Elena",
            "gender": "f"
        }}
    }},
    "dialogue": [
        {{
            "speaker": "speaker_1",
            "turn_nr": 1,
            "target_language": "Primero, coloca el pcb con cuidado.",
            "native_language": "First, place the pcb carefully.",
            "narrator_explanation": "Carlos is giving instructions on how to handle the pcb.",
            "narrator_fun_fact": "PCB stands for 'printed circuit board', which is called ||placa de circuito impreso|| in Spanish.",
            "split_sentence": [
                {{
                    "target_language": "Primero",
                    "native_language": "First",
                    "narrator_fun_fact": "||Primero|| is commonly used to begin a series of instructions."
                }},
                {{
                    "target_language": "coloca",
                    "native_language": "place",
                    "narrator_fun_fact": "||Coloca|| is an imperative form of ||colocar||, meaning to place or put."
                }},
                {{
                    "target_language": "el pcb",
                    "native_language": "the pcb",
                    "narrator_fun_fact": "In Spanish, ||el pcb|| directly translates to 'the pcb', maintaining the abbreviation."
                }},
                {{
                    "target_language": "con cuidado",
                    "native_language": "carefully",
                    "narrator_fun_fact": "||Con cuidado|| is a phrase used to indicate that something should be done with care."
                }}
            ]
        }},
        {{
            "speaker": "speaker_2",
            "turn_nr": 2,
            "target_language": "¿Debo conectar los cables ahora?",
            "native_language": "Should I connect the wires now?",
            "narrator_explanation": "Elena is asking for further instructions about wiring.",
            "narrator_fun_fact": "Asking questions is crucial in learning, ensuring clarity and proper process.",
            "split_sentence": [
                {{
                    "target_language": "¿Debo",
                    "native_language": "Should I",
                    "narrator_fun_fact": "||¿Debo|| is from the verb ||deber|| which means 'should' or 'must' in this context."
                }},
                {{
                    "target_language": "conectar",
                    "native_language": "connect",
                    "narrator_fun_fact": "||Conectar|| means to connect, commonly used in technical and everyday contexts."
                }},
                {{
                    "target_language": "los cables",
                    "native_language": "the wires",
                    "narrator_fun_fact": "||Los cables|| directly translates to 'the wires'."
                }},
                {{
                    "target_language": "ahora",
                    "native_language": "now",
                    "narrator_fun_fact": "||Ahora|| translates directly to 'now', indicating immediate or current action."
                }}
            ]
        }}
    ]
}}
===
'''

app = initialize_app()

class GPT_MODEL(Enum):
    GPT_4_TURBO = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode. The default points to this
    # GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode

class TTS_PROVIDERS(Enum):
    GOOGLE = 1
    ELEVENLABS = 2

@https_fn.on_request(
    cors=options.CorsOptions(
      cors_origins=["*"],
      cors_methods=["GET", "POST"],
  )
)
@https_fn.on_request()
def full_API_workflow(gpt_model, req: https_fn.Request) -> https_fn.Response:
    chatGPT_response = chatGPT_API_call(gpt_model, req)
    # parse_and_convert_to_speech(chatGPT_response, directory, tts_functions)
    # parse_and_create_script(chatGPT_response, directory)

def chatGPT_API_call(gpt_model, req):
    request_data = json.loads(req.data)
    requested_scenario = request_data.get("requested_scenario")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    length = request_data.get("length")
    username = request_data.get("username")
    try:
        language_level = request_data.get("language_level")
    except:
        language_level = "A1"
    try:
        keywords = request_data.get("keywords")
    except:
        keywords = ""

    if not all([requested_scenario, native_language, target_language, language_level]):
        return {'error': 'Missing required parameters in request data'}

    client = openai.OpenAI(api_key='sk-proj-tSgG8JbXLbsQ3pTkVAnzT3BlbkFJxThD8az2IkfsWN6lodsM')

    # Create the chat completion
    completion = client.chat.completions.create(
        model=gpt_model,
        #   stream=True,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt(requested_scenario, native_language, target_language, language_level, keywords, length)}
        ],
        response_format={'type': 'json_object'}
    )

    chatGPT_JSON_response = completion.choices[0].message.content
    try:
        data = json.loads(chatGPT_JSON_response)
    except Exception as e:
        print(chatGPT_JSON_response)
        print(f"Error parsing JSON response from chatGPT: {e}")
        #TODO: log error and failed JSON in DB and ask the user to try again
        return

    data["username"] = username
    return data

def split_words(sentence):
  additional_chars = '“”‘’—–…«»„©®™£€¥×÷°'
  punctuation = string.punctuation + additional_chars
  words = sentence.split()
  words = [word.strip(punctuation) for word in words]
  return words

def parse_and_create_script(data):
    script = []

    intro_sequence = intro_sequence_1("title")
    script.extend(intro_sequence)

    for i, sentence in enumerate(data["dialogue"]):
        script.append(f"dialogue_{i}_{"target_language"}")

    # Process each turn in the dialogue
    for i, sentence in enumerate(data["dialogue"]):

        native_sentence = f"dialogue_{i}_{"native_language"}"
        target_sentence = f"dialogue_{i}_{"target_language"}"

        narrator_explanation = f"dialogue_{i}_{"narrator_explanation"}"
        narrator_fun_fact = f"dialogue_{i}_{"narrator_fun_fact"}"
        
        sentence_sequence = sentence_sequence_1(native_sentence, target_sentence, narrator_explanation, narrator_fun_fact)
        script.extend(sentence_sequence)

        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):
            split_narrator_fun_fact = f"dialogue_{i}_split_sentence_{j}_{"narrator_fun_fact"}"
            split_native = f"dialogue_{i}_split_sentence_{j}_{"native_language"}"
            split_target = f"dialogue_{i}_split_sentence_{j}_{"target_language"}"

            words = []
            for index, value in enumerate(split_words(split_sentence['target_language'])):
                target_word = f"dialogue_{i}_split_sentence_{j}_target_language_{index}"
                words.append(target_word)

            chunk_sequence = chunk_sequence_1(split_narrator_fun_fact, split_native, split_target, words)
            script.extend(chunk_sequence)

    return script

# matching language to language code
from google_tts_language_codes import language_codes

def language_to_language_code(language):
    print('language: ', language)
    if language in language_codes:
        return language_codes[language]
    else:
        return "Language not found"

def parse_and_convert_to_speech(data, directory, tts_provider):

    if tts_provider == TTS_PROVIDERS.GOOGLE:
        target_language = data["target_language"]
        speaker_1_gender = data["speakers"]["speaker_1"]["gender"].lower()
        speaker_2_gender = data["speakers"]["speaker_2"]["gender"].lower()

        target_language = data["target_language"]

        language_code = language_to_language_code(target_language)

        speaker_1_voice = gcloud_tts.choose_voice(language_code, speaker_1_gender)
        speaker_2_voice = gcloud_tts.choose_voice(language_code, speaker_2_gender)
        narrator_voice = gcloud_tts.choose_voice('en-US', "f", "en-US-Standard-C")

        tts_function = gcloud_tts.synthesize_text

    elif tts_provider == TTS_PROVIDERS.ELEVENLABS:
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
        mp3_title = f"speakers_{speaker_key}_name"
        tts_function(text, narrator_voice, f"{directory}/audio/{mp3_title}.mp3")

    # Process each turn in the dialogue
    for i, sentence in enumerate(data["dialogue"]):
        current_speaker_voice = speaker_1_voice if i % 2 == 0 else speaker_2_voice

        text = sentence["native_language"]
        mp3_title = f"dialogue_{i}_{"native_language"}"
        tts_function(text, narrator_voice, f"{directory}/audio/{mp3_title}.mp3")

        text = sentence["target_language"]
        mp3_title = f"dialogue_{i}_{"target_language"}"
        tts_function(text, current_speaker_voice, f"{directory}/audio/{mp3_title}.mp3")

        for key in ["narrator_explanation", "narrator_fun_fact"]:
            text = sentence[key]
            mp3_title = f"dialogue_{i}_{key}"
            tts_function(text, narrator_voice, f"{directory}/audio/{mp3_title}.mp3")

        # Process split_sentence items
        for j, split_sentence in enumerate(sentence["split_sentence"]):
            text = split_sentence["narrator_fun_fact"]
            mp3_title = f"dialogue_{i}_split_sentence_{j}_{"narrator_fun_fact"}"
            tts_function(text, narrator_voice, f"{directory}/audio/{mp3_title}.mp3")
            
            text = split_sentence["native_language"]
            mp3_title = f"dialogue_{i}_split_sentence_{j}_{"native_language"}"
            tts_function(text, narrator_voice, f"{directory}/audio/{mp3_title}.mp3")
            
            text = split_sentence["target_language"]
            mp3_title = f"dialogue_{i}_split_sentence_{j}_{"target_language"}"
            tts_function(text, current_speaker_voice, f"{directory}/audio/{mp3_title}.mp3")
            
            for index, value in enumerate(split_words(split_sentence['target_language'])):
                text = value
                mp3_title = f"dialogue_{i}_split_sentence_{j}_target_language_{index}"
                tts_function(text, current_speaker_voice, f"{directory}/audio/{mp3_title}.mp3")
