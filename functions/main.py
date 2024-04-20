import requests
import json
import openai
from firebase_functions import firestore_fn, https_fn, options
from firebase_admin import initialize_app, firestore
import google.cloud.firestore
import string


app = initialize_app()



# @https_fn.on_request(
#     cors=options.CorsOptions(
#       cors_origins=["*"],
#       cors_methods=["GET", "POST"],
#   )
# )
# @https_fn.on_request()
# def parakeetAPI(req: https_fn.Request) -> https_fn.Response:
def parakeetAPI(request_data):

#   request_data = json.loads(req.data)
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

    
  # Initialize OpenAI client
  client = openai.OpenAI(api_key='sk-proj-tSgG8JbXLbsQ3pTkVAnzT3BlbkFJxThD8az2IkfsWN6lodsM')

  # Create the chat completion
  completion = client.chat.completions.create(
      model="gpt-4-turbo",
      messages=[
          {"role": "system", "content": "You are a helpful assistant."},
          # {"role": "user", "content": f"Give me a json with a name and last name {requested_scenario}."},
          {"role": "user", "content": f'''Please create a JSON file for a conversation for a language learning app. The language level will be {language_level}. It should contain 10 short sentences alternating for each of two characters. It should include exactly the following keys for the key-value pairs in JSON:

title: (Create a title for the conversation.)
requested_scenario: {requested_scenario}.
keywords: {keywords}.
native_language: {native_language}
target_language: {target_language}
language_level: {language_level}
conversation: (An array of dictionaries with 10 items, that is 10 sentences. Each of the 10 dictionaries contains the following keys:)

- speaker_name: (create a name for each of the speakers)
- order: (order in the overall sentences from 1 to 10)
- native_language_sentence: (sentence in {native_language}. Do NOT include the name of any speaker in the sentence.)
- target_language_sentence: (A translation of the {native_language} sentence to {target_language})
- narrator_explanation: (
        A sentence by the narrator of the language lesson explaining the what is going on in this sentence and who is talking, include the name of the speaker in the sentence. For example, "Ben is asking a question about the PCB board."
        )
- target_language_split_sentence: ( An object that for a sentence "Danke, Dr. Müller. Ich habe schon immer ein großes Interesse an alten Zivilisationen gehabt." would  like this: 

{{
        "1": {{
          "native_language": "Danke",
          "target_language": "thank you",
          "narrator_fun_fact": "The German word 'danke' is closely related to the English word thank. Both words share the same Proto-Germanic root which means 'thought' or 'gratitude.'"
        }},
        "2": {{
          "native_language": "Ich habe schon immer",
          "target_language": "I have always",
          "narrator_fun_fact": "The phrase 'schon immer' emphasizes a long-standing interest or condition. It literally already always"
        }},
        "3": {{
          "native_language": "ein großes Interesse",
          "target_language": "a great interest",
          "narrator_fun_fact": "The phrase 'ein großes Interesse' is a common way to express a strong interest in German."
        }},
        "4": {{
          "native_language": "an alten Zivilisationen",
          "target_language": "in ancient civilizations",
          "narrator_fun_fact": "The preposition 'an' is used here to indicate an interest in or towards ancient civilizations."
        }},
        "5": {{
          "native_language": "gehabt",
          "target_language": "had",
          "narrator_fun_fact": "The verb 'gehabt' is the past participle of 'haben' and is used in the perfect tense construction in German."
        }}
      }}

        Where native_language values are the target_language_sentence split into sets of words that make sense together and have grammatical cohesion in {target_language}. For example, if the target_language was German and the sentence  "Hallo, fangen wir mit der Leiterplatte an?" the keys would be "Hallo", "fangen wir mit" and "der Leiterplatte an".

        The target_language values are the direct translations of the native_language values into {target_language}. Stick to the direct translation of the phrase. For example, in the German phrase "Toll! Ich habe viel darüber gehört." the key-value pair should NOT be "Ich habe viel": "Means 'I have heard a lot'" but rather "Ich habe viel": "I have a lot".

        The narrator_fun_fact values are fun facts about the translation, etymology history or the grammar of the target_language. Enclose words in {target_language} in single quotes. Leave words in {native_language} always without quotes.
    )

For the specifications in parenthesis you must generate the content. The keys shall remain exactly the same. If no keywords are provided for the keywords key field add your own keywords to be used in the conversation.
'''
}
      ],
      response_format={'type': 'json_object'}
  )

  chatGPT_JSON_response = completion.choices[0].message.content

  data = json.loads(chatGPT_JSON_response)
  return data

conversation_JSON = parakeetAPI({
        "requested_scenario": "A mother talks to her 10 year old son about the importance of recycling and how to do it properly.", 
        "keywords": "", 
        "native_language": "English", 
        "target_language": "German", 
        "language_level": "A2"
   })

print(conversation_JSON)

#       ___                                   ___             __                
#      /\_ \                                 /\_ \           /\ \               
#    __\//\ \      __   __  __     __    ___ \//\ \      __  \ \ \____    ____  
#  /'__`\\ \ \   /'__`\/\ \/\ \  /'__`\/' _ `\ \ \ \   /'__`\ \ \ '__`\  /',__\ 
# /\  __/ \_\ \_/\  __/\ \ \_/ |/\  __//\ \/\ \ \_\ \_/\ \L\.\_\ \ \L\ \/\__, `\
# \ \____\/\____\ \____\\ \___/ \ \____\ \_\ \_\/\____\ \__/.\_\\ \_,__/\/\____/
#  \/____/\/____/\/____/ \/__/   \/____/\/_/\/_/\/____/\/__/\/_/ \/___/  \/___/ 

# An API key is defined here. You'd normally get this from the service you're accessing. It's a form of authentication.
XI_API_KEY = "b9a5cc8dfd7e9ffa3f8e7451f1713ae0"

def get_voices():

  # This is the URL for the API endpoint we'll be making a GET request to.
  url = "https://api.elevenlabs.io/v1/voices"

  # Here, headers for the HTTP request are being set up. 
  # Headers provide metadata about the request. In this case, we're specifying the content type and including our API key for authentication.
  headers = {
    "Accept": "application/json",
    "xi-api-key": XI_API_KEY,
    "Content-Type": "application/json"
  }

  # A GET request is sent to the API endpoint. The URL and the headers are passed into the request.
  response = requests.get(url, headers=headers)

  # The JSON response from the API is parsed using the built-in .json() method from the 'requests' library. 
  # This transforms the JSON data into a Python dictionary for further processing.
  data = response.json()

  # A loop is created to iterate over each 'voice' in the 'voices' list from the parsed data. 
  # The 'voices' list consists of dictionaries, each representing a unique voice provided by the API.
  for voice in data['voices']:
    # For each 'voice', the 'name' and 'voice_id' are printed out. 
    # These keys in the voice dictionary contain values that provide information about the specific voice.
    print(f"{voice['name']}; {voice['voice_id']}")

# The function is called to execute the code.
# get_voices()


def elevenlabs_tts(text, output_path, voice_id="21m00Tcm4TlvDq8ikWAM"):
    
    # Define constants for the script
    CHUNK_SIZE = 1024  # Size of chunks to read/write at a time
    VOICE_ID = voice_id  # ID of the voice model to use
    TEXT_TO_SPEAK = text  # Text you want to convert to speech
    OUTPUT_PATH = output_path  # Path to save the output audio file

    # Construct the URL for the Text-to-Speech API request
    tts_url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}/stream"

    # Set up headers for the API request, including the API key for authentication
    headers = {
    "Accept": "application/json",
    "xi-api-key": XI_API_KEY
    }

    # Set up the data payload for the API request, including the text and voice settings
    data = {
    "text": TEXT_TO_SPEAK,
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.8,
            "style": 0.0,
            "use_speaker_boost": True
        }
    }

    # Make the POST request to the TTS API with headers and data, enabling streaming response
    response = requests.post(tts_url, headers=headers, json=data, stream=True)

    # Check if the request was successful
    if response.ok:
        # Open the output file in write-binary mode
        with open(OUTPUT_PATH, "wb") as f:
            # Read the response in chunks and write to the file
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                f.write(chunk)
        # Inform the user of success
        print("Audio stream saved successfully.")
    else:
        # Print the error message if the request was not successful
        print(response.text)


def split_words(sentence):
  additional_chars = '“”‘’—–…«»„©®™£€¥×÷°'
  punctuation = string.punctuation + additional_chars
  words = sentence.split()
  words = [word.strip(punctuation) for word in words]
  return words

text_for_tts = {}
def get_text_for_tts(conversation_JSON):
    sentence_counter = 0
    for sentence in conversation_JSON['conversation']:
        native_language_sentence = sentence['native_language_sentence']
        target_language_sentence = sentence['target_language_sentence']
        text_for_tts["native_language_sentence_"+str(sentence_counter)] = native_language_sentence
        text_for_tts["target_language_sentence_"+str(sentence_counter)] = target_language_sentence
        
        sentence_native_list = split_words(native_language_sentence)
        sentence_translation_list = split_words(target_language_sentence)
        # Iterate sentence_native_list and sentence_translation_list to get the individual words and store them in the text_for_tts dictionary
        for i in range(len(sentence_native_list)):
            text_for_tts["native_"+str(sentence_counter)+"_word_"+str(i)] = sentence_native_list[i]
        
        for i in range(len(sentence_translation_list)):
            text_for_tts["translation_"+str(sentence_counter)+"_word_"+str(i)] = sentence_translation_list[i]
        sentence_counter += 1

filename = 'example_JSON.json'

# Open the JSON file for reading
with open(filename, 'r') as file:
    example_JSON = json.load(file)


get_text_for_tts(example_JSON)

# counter = 0
# for key, text in text_for_tts.items():
#     if counter < 10:
#         print(text)
#         elevenlabs_tts(text, f"audio/{key}.mp3")
#     counter += 1
