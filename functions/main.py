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
            - split_sentence: ( An object that for sentence with German as target language and English as native language where the target sentence is: "Danke, Dr. Müller. Ich habe schon immer ein großes Interesse an alten Zivilisationen gehabt." would  like this: 

            {{
                    "1": {{
                      "target_language": "Danke",
                      "native_language": "thank you",
                      "narrator_fun_fact": "The German word 'danke' is closely related to the English word thank. Both words share the same Proto-Germanic root which means 'thought' or 'gratitude.'"
                    }},
                    "2": {{
                      "target_language": "Ich habe schon immer",
                      "native_language": "I have always",
                      "narrator_fun_fact": "The phrase 'schon immer' emphasizes a long-standing interest or condition. It literally already always"
                    }},
                    "3": {{
                      "target_language": "ein großes Interesse",
                      "native_language": "a great interest",
                      "narrator_fun_fact": "The phrase 'ein großes Interesse' is a common way to express a strong interest in German."
                    }},
                    "4": {{
                      "target_language": "an alten Zivilisationen",
                      "native_language": "in ancient civilizations",
                      "narrator_fun_fact": "The preposition 'an' is used here to indicate an interest in or towards ancient civilizations."
                    }},
                    "5": {{
                      "target_language": "gehabt",
                      "native_language": "had",
                      "narrator_fun_fact": "The verb 'gehabt' is the past participle of 'haben' and is used in the perfect tense construction in German."
                    }}
                  }}

                    Where target_language values are the target_language_sentence split into sets of words that make sense together and have grammatical cohesion in {target_language}. For example, if the target_language was German and the sentence  "Hallo, fangen wir mit der Leiterplatte an?" the keys would be "Hallo", "fangen wir mit" and "der Leiterplatte an".

                    The native_language values are the direct translations of the native_language values into {target_language}. Stick to the direct translation of the phrase. For example, in the German phrase "Toll! Ich habe viel darüber gehört." the key-value pair should NOT be "Ich habe viel": "Means 'I have heard a lot'" but rather "Ich habe viel": "I have a lot".

                    The narrator_fun_fact values are fun facts about the translation, etymology, history or the grammar of the target_language. Enclose words in {target_language} in single quotes. Leave words in {native_language} always without quotes.
                )

            For the specifications in parenthesis you must generate the content. The keys shall remain exactly the same. If no keywords are provided for the keywords key field add your own keywords to be used in the conversation and that match the conversation topic.
            '''
          }
      ],
      response_format={'type': 'json_object'}
  )

  chatGPT_JSON_response = completion.choices[0].message.content

  data = json.loads(chatGPT_JSON_response)
  return data

# conversation_JSON = parakeetAPI({
#   "requested_scenario": "A woman collects her package from a package shop", 
#   "keywords": "package, collect, ID, passport", 
#   "native_language": "English", 
#   "target_language": "German", 
#   "language_level": "A2"
# })

# print(conversation_JSON)

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


def elevenlabs_tts(text, output_path):
    
    # Define constants for the script
    CHUNK_SIZE = 1024  # Size of chunks to read/write at a time
    VOICE_FOR_NARRATOR = "JBFqnCBsd6RMkjVDRZzb"
    VOICE_FOR_EVEN_SENTENCE = "LcfcDJNUP1GQjkzn1xUU"
    VOICE_FOR_ODD_SENTENCE = "5Q0t7uMcjvnagumLfvZi"
    # if the output_path contains narrator, the voice id should be JBFqnCBsd6RMkjVDRZzb
    if "narrator" in output_path:
        voice_id = VOICE_FOR_NARRATOR
    elif "sentence_" in output_path:
      # Extract the number from the output_path
      sentence_number = int(''.join(filter(str.isdigit, output_path)))
      # If the sentence number is odd, use one voice id
      if sentence_number % 2 != 0:
        voice_id = VOICE_FOR_ODD_SENTENCE
      # If the sentence number is even or zero, use another voice id
      else:
        voice_id = VOICE_FOR_EVEN_SENTENCE

    TEXT_TO_SPEAK = text  # Text you want to convert to speech
    OUTPUT_PATH = output_path  # Path to save the output audio file

    # Construct the URL for the Text-to-Speech API request
    tts_url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream"

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
    text_for_tts["native_language_narrator"] = conversation_JSON['native_language']
    text_for_tts["target_language_narrator"] = conversation_JSON['target_language']
    text_for_tts["lesson_title_narrator"] = conversation_JSON['title']
    sentence_counter = 0
    for sentence in conversation_JSON['conversation']:
        native_language_sentence = sentence['native_language_sentence']
        target_language_sentence = sentence['target_language_sentence']
        narrator_explanation = sentence['narrator_explanation']
        target_language_split_sentence = list (sentence['split_sentence'].values())

        text_for_tts["sentence_"+str(sentence_counter)+"_narrator_explanation"] = narrator_explanation
        text_for_tts["sentence_"+str(sentence_counter)+"_native"] = native_language_sentence
        text_for_tts["sentence_"+str(sentence_counter)+"_target"] = target_language_sentence
        for index, value in enumerate(target_language_split_sentence):
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
    # create a json file and store it there
    with open('text_for_tts.json', 'w') as file:
        json.dump(text_for_tts, file)

        
        
filename = 'text_for_tts.json'

# Open the JSON file for reading
with open(filename, 'r') as file:
    text_for_tts = json.load(file)


# get_text_for_tts(conversation_JSON) 

counter = 30
for key, text in text_for_tts.items():
        if counter < 31:
          elevenlabs_tts(text, f"audio/{key}.mp3")
        counter += 1
