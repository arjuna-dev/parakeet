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
  "title": "A Delicious Dinner",
  "requested_scenario": "A man orders a duck dish in a restaurant.",
  "keywords": ["restaurant", "ordering", "food", "duck"],
  "native_language": "English",
  "target_language": "French",
  "language_level": "A2",
  "speakers": {{
    "speaker_1": {{
      "name": "Pier",
      "gender": "male"
    }},
    "speaker_2": {{
      "name": "Jerome",
      "gender": "male"
    }}
  }},
  "conversation": [
    {{
      "speaker": "speaker_1",
      "sentence_nr": 1,
      "native_language_sentence": "Good evening, I would like a table for one, please.",
      "target_language_sentence": "Bonsoir, je voudrais une table pour une personne, s'il vous pla\u00eet.",
      "narrator_explanation": "Pier is greeting the Jerome and requesting a table.",
      "narrator_fun_fact": (generate a one sentence fun fact here),
      "split_sentence": [
        {{
          "target_language": "Bonsoir",
          "native_language": "Good evening",
          "narrator_fun_fact": "The word 'Bonsoir' is used in French to greet someone in the evening."
        }},
        {{
          "target_language": "je voudrais",
          "native_language": "I would like",
          "narrator_fun_fact": "The verb 'voudrais' is conditional of 'vouloir', meaning 'to want'. It is polite when making requests."
        }},
        {{
          "target_language": "une table pour une personne",
          "native_language": "a table for one",
          "narrator_fun_fact": "'Une table pour une' translates directly but is specifically phrased for requesting seating in a restaurant."
        }},
        {{
          "target_language": "s'il vous pla\u00eet",
          "native_language": "please",
          "narrator_fun_fact": "\u2018S\u2019il vous pla\u00eet\u2019 is the formal 'please' in French, used here to show politeness."
        }}
      ]
    }},
    {{
      "speaker": "speaker_2",
      "sentence_nr": 2,
      "native_language_sentence": "Of course, right this way please.",
      "target_language_sentence": "Bien s\u00fbr, suivez-moi, s'il vous pla\u00eet.",
      "narrator_explanation": "The Jerome is welcoming Pier and leading him to a table.",
      "narrator_fun_fact": (generate a one sentence fun fact here),
      "split_sentence": [
        {{
          "target_language": "Bien s\u00fbr",
          "native_language": "Of course",
          "narrator_fun_fact": "'Bien s\u00fbr' shows agreement and straightforwardness in response."
        }},
        {{
          "target_language": "suivez-moi",
          "native_language": "follow me",
          "narrator_fun_fact": "'Suivez-moi' is an imperative form directing someone to follow."
        }},
        {{
          "target_language": "s'il vous pla\u00eet",
          "native_language": "please",
          "narrator_fun_fact": "Repeating \u2018s\u2019il vous pla\u00eet\u2019 emphasizes politeness in French culture."
        }}
      ]
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