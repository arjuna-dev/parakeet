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