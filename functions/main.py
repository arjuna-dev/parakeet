# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

# The Cloud Functions for Firebase SDK to create Cloud Functions and set up triggers.
from firebase_functions import firestore_fn, https_fn, options

# The Firebase Admin SDK to access Cloud Firestore.
from firebase_admin import initialize_app, firestore
import google.cloud.firestore

app = initialize_app()


import os
import openai
import json



@https_fn.on_request(
    cors=options.CorsOptions(
      cors_origins=["*"],

      cors_methods=["GET", "POST"],
  )
)
@https_fn.on_request()
def parakeetAPI(req: https_fn.Request) -> https_fn.Response:

  request_data = json.loads(req.data)
  topic = request_data.get("topic")
  keywords = request_data.get("keywords")
  native_language = request_data.get("native_language")
  learning_language = request_data.get("learning_language")

  if not all([topic, keywords, native_language, learning_language]):
      return {'error': 'Missing required parameters in request data'}

    
  # Initialize OpenAI client
  client = openai.OpenAI(api_key='sk-proj-tSgG8JbXLbsQ3pTkVAnzT3BlbkFJxThD8az2IkfsWN6lodsM')

  # Create the chat completion
  completion = client.chat.completions.create(
      model="gpt-4-turbo",
      messages=[
          {"role": "system", "content": "You are a helpful assistant."},
          # {"role": "user", "content": f"Give me a json with a name and last name {topic}."},
          {"role": "user", "content": f'''Please create a JSON file for a conversation for a language learnin app. It should contain 10 sentences, 5 for each character.It should include exactly the following keys for the key value pair in JSON:

title: (Create a title for the conversation.)
topic: {topic}.
keywords: {keywords}.
native_language: {native_language}
learning_language: {learning_language}
conversation: (An array of dictionaries with 10 items. Each dictionary containing these keys:)

- speaker_name: (create a name for each of the speakers)
- order: (order in the overall sentences)
- sentence_native: (sentence in {native_language})
- sentence_transaltion: (sentence in {learning_language})
- keywords_native: (an array of keywords of the sentence in {native_language})
- keywords_translations: (an array of keywords in {learning_language} with matching index of {native_language} keywords list)

For the specifications in parenthesis you must generate the content. The keys shall remain exactly the same.
'''
}
      ],
      response_format={'type': 'json_object'}
  )

  chatGPT_JSON_response = completion.choices[0].message.content

  data = json.loads(chatGPT_JSON_response)
  return data
  # return https_fn.Response(data)


# The 'requests' and 'json' libraries are imported. 
# 'requests' is used to send HTTP requests, while 'json' is used for parsing the JSON data that we receive from the API.
import requests
import json

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
get_voices()


def generate_to_voice(text, voice_id, output_path):
    
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


generate_to_voice("hello how are you", "21m00Tcm4TlvDq8ikWAM", "output.mp3")
