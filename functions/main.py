import os
import requests
import json
import openai # type: ignore
from firebase_functions import firestore_fn, https_fn, options # type: ignore
from firebase_admin import initialize_app, firestore # type: ignore
import google.cloud.firestore # type: ignore
import string
from elevenlabs_api import elevenlabs_tts, get_voices
import datetime # type: ignore
from lesson_generator import generate_lesson
import re
from time import sleep

conversation_assistant_ID = "asst_elhm6Fq9uVWEWJ6Lo6oEy0sk"
sentence_assistant_ID = "asst_L9TI47AwdQ0qX9tBnJyFC8mP"
sentence_splitter_assistant_ID = "asst_lSFyjlZQZ6Q47DXQ0l9WVV9M"

client = openai.OpenAI(api_key='sk-proj-tSgG8JbXLbsQ3pTkVAnzT3BlbkFJxThD8az2IkfsWN6lodsM')

user_name = input("Enter the user name: ")
requested_scenario = input("Enter the requested scenario: ")
keywords = input("Enter the keywords: ")
native_language = input("Enter the native language: ")
target_language = input("Enter the target language: ")
language_level = input("Enter the language level: ")
length = input("Enter conversation length: ")

app = initialize_app()

# @https_fn.on_request(
#     cors=options.CorsOptions(
#       cors_origins=["*"],
#       cors_methods=["GET", "POST"],
#   )
# )
# @https_fn.on_request()
# def chatGPT_API_call(req: https_fn.Request) -> https_fn.Response:
def chatGPT_API_call(request_data):
  # request_data = json.loads(req.data)
  requested_scenario = request_data.get("requested_scenario")
  native_language = request_data.get("native_language")
  target_language = request_data.get("target_language")
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
      model="gpt-4-turbo",
      messages=[
          {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
          {"role": "user", "content": f'''This is an example of the JSON file you must generate enclosed in triple minus symbols:

---
{{
  "title": "Learning Electrical Engineering",
  "all_turns": [
    "Primero, coloca el pcb con cuidado.",
    "¿Debo conectar los cables ahora?",
    "Sí, sigue el diagrama para el cableado.",
    "¿Está esta la orientación correcta?",
    "Ajustalo un poco a la izquierda.",
    "¿Así?"
  ],
  "requested_scenario": "I am being taught electrical engineering",
  "keywords": ["instructions", "pcb"],
  "translate_to_language": "English",
  "original_language": "Spanish",
  "language_level": "A1",
  "speakers": {{ "speaker_1": {{ "name": "Carlos", "gender": "m" }}, "speaker_2": {{ "name": "Elena", "gender": "f" }} }},
  "conversation": [
    {{
      "speaker": "speaker_1",
      "turn_nr": 1,
      "original_language": "Primero, coloca el pcb con cuidado.",
      "translate_to_language": "First, place the pcb carefully.",
      "narrator_explanation": "Carlos is giving instructions on how to handle the pcb.",
      "narrator_fun_fact": "PCB stands for 'printed circuit board', which is called <placa de circuito impreso> in Spanish.",
      "turn_sentences": [
        {{
          "sentence": "Primero, coloca el pcb con cuidado.",
          "translation": "First, place the pcb carefully.",
          "sentence_parts": [
            {{
              "target_language": "Primero",
              "native_language": "First",
              "narrator_fun_fact": "<Primero> is commonly used to begin a series of instructions.",
            }},
            {{
              "target_language": "coloca",
              "native_language": "place",
              "narrator_fun_fact": "<Coloca> is an imperative form of <colocar>, meaning to place or put.",
            }},
            {{
              "target_language": "el pcb",
              "native_language": "the pcb",
              "narrator_fun_fact": "In Spanish, <el pcb> directly translates to 'the pcb', maintaining the abbreviation.",
            }},
            {{
              "target_language": "con cuidado",
              "native_language": "carefully",
              "narrator_fun_fact": "<Con cuidado> is a phrase used to indicate that something should be done with care.",
            }}
          ]
        }}
      ]
    }},
    {{
      "speaker": "speaker_2",
      "turn_nr": 2,
      "original_language": "¿Debo conectar los cables ahora?",
      "translate_to_language": "Should I connect the wires now?",
      "narrator_explanation": "Elena is asking for further instructions about wiring.",
      "narrator_fun_fact": "Asking questions is crucial in learning, ensuring clarity and proper process.",
      "turn_sentences": [
        {{
          "sentence": "¿Debo conectar los cables ahora?",
          "translation": "Should I connect the wires now?",
          "sentence_parts": [
            {{
              "target_language": "¿Debo",
              "native_language": "Should I",
              "narrator_fun_fact": "<¿Debo> is from the verb <deber> which means 'should' or 'must' in this context.",
            }},
            {{
              "target_language": "conectar",
              "native_language": "connect",
              "narrator_fun_fact": "<Conectar> means to connect, commonly used in technical and everyday contexts.",
            }},
            {{
              "target_language": "los cables",
              "native_language": "the wires",
              "narrator_fun_fact": "<Los cables> directly translates to 'the wires'.",
            }},
            {{
              "target_language": "ahora",
              "native_language": "now",
              "narrator_fun_fact": "<Ahora> translates directly to 'now', indicating immediate or current action.",
            }}
          ]
        }}
      ]
    }},
    {{
      "speaker": "speaker_1",
      "turn_nr": 3,
      (continued...)
    }}
    ]
}}
---

Please generate a JSON file with {length} sentences, so that sentence_nr should go from 1 to {length}, but using the the following:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the conversation. If no keywords are provided there is no need to generate them. The split sentence should split it in chunks that have grmatical cohesion and make sense. 
'''}
      ],
      response_format={'type': 'json_object'}
)

  chatGPT_JSON_response = completion.choices[0].message.content

  data = json.loads(chatGPT_JSON_response)
  return data


def split_words(sentence):
  additional_chars = '“”‘’—–…«»„©®™£€¥×÷°'
  punctuation = string.punctuation + additional_chars
  words = sentence.split()
  words = [word.strip(punctuation) for word in words]
  return words

def get_text_for_tts(conversation_JSON):
    text_for_tts = {}
    text_for_tts["native_language_narrator"] = conversation_JSON['native_language']
    text_for_tts["target_language_narrator"] = conversation_JSON['target_language']
    text_for_tts["lesson_title_narrator"] = conversation_JSON['title']
    sentence_counter = 0
    for sentence in conversation_JSON['conversation']:
          native_language_sentence = sentence['native_language_sentence']
          target_language_sentence = sentence['target_language_sentence']
          narrator_explanation = sentence['narrator_explanation']
          # target_language_split_sentence = list (sentence['split_sentence'].values())

          text_for_tts["sentence_"+str(sentence_counter)+"_narrator_explanation"] = narrator_explanation
          text_for_tts["sentence_"+str(sentence_counter)+"_native"] = native_language_sentence
          text_for_tts["sentence_"+str(sentence_counter)+"_target"] = target_language_sentence
          for index, value in enumerate(sentence['split_sentence']):
              native_language_chunk = value["native_language"]
              target_language_chunk = value["target_language"]
              narrator_fun_fact_chunk = value["narrator_fun_fact"]
              phrase = "sentence_"+str(sentence_counter)+"_split_sentence_" + str(index)

              text_for_tts[phrase + "_native"] = native_language_chunk
              text_for_tts[phrase + "_target"] = target_language_chunk
              text_for_tts[phrase + "_narrator_fun_fact"] = narrator_fun_fact_chunk
              for index, value in enumerate(split_words(target_language_chunk)):
                  text_for_tts[phrase + "_target_"+ str(index)] = value
          sentence_counter += 1
    return text_for_tts

chatGPT_response = chatGPT_API_call({
  "requested_scenario": requested_scenario, 
  "keywords": keywords, 
  "native_language": native_language, 
  "target_language": target_language, 
  "language_level": language_level
})

now = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

#create a directory name with the title of the conversation
directory = f"{user_name}_{now}"
os.makedirs(directory, exist_ok=True)

#save the chatGPT response to a json file
filename = 'chatGPT_response.json'
with open(f"{directory}/{filename}", 'w') as file:
  json.dump(chatGPT_response, file)

#save the text for tts to a json file
text_for_tts = get_text_for_tts(chatGPT_response)
filename = 'text_for_tts.json'
with open(f"{directory}/{filename}", 'w') as file:
  json.dump(text_for_tts, file)


# pattern = r"^sentence_\d+_target$"

# loop through the text_for_tts dictionary and generate audio files for each key
for key, text in text_for_tts.items():
  elevenlabs_tts(text, f"audio/{key}.mp3")

# call generate_lesson function
generate_lesson(directory)