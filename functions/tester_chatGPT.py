from enum import Enum
from main import prompt
import os
import json
import openai
import datetime


class GPT_MODEL(Enum):
    GPT_4_TURBO = "gpt-4-1106-preview" # Supports JSON mode
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode. The default points to this
    # GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode

now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

client = openai.OpenAI(api_key='sk-proj-tSgG8JbXLbsQ3pTkVAnzT3BlbkFJxThD8az2IkfsWN6lodsM')

user_name = input("Enter the user name: ")
requested_scenario = input("Enter the requested scenario: ")
keywords = input("Enter the keywords: ")
native_language = input("Enter the native language: ")
target_language = input("Enter the target language: ")
language_level = input("Enter the language level: ")
length = input("Enter number of sentences: ")
# gpt_model = input("Enter the GPT model number \n 1: GPT_4_TURBO, 2: GPT_4_TURBO_V: ")

# if gpt_model == "1":
#     gpt_model = GPT_MODEL.GPT_4_TURBO.value
# elif gpt_model == "2":
#     gpt_model = GPT_MODEL.GPT_4_TURBO_V.value
# else:
#     gpt_model = GPT_MODEL.GPT_3_5.value

def chatGPT_API_call(gpt_model, request_data):

    requested_scenario = request_data.get("requested_scenario")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    length = request_data.get("length")
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

    return data

gpt_model = GPT_MODEL.GPT_4_TURBO_V.value

# Create directory
directory = f"{user_name}_{gpt_model}_{now}"
os.makedirs(directory, exist_ok=True)

language_levels = ["A1", "B2", "C2", "Advanced"]
for level in language_levels:
    chatGPT_response = chatGPT_API_call(gpt_model,
                                        {
                                        "requested_scenario": requested_scenario,
                                        "keywords": keywords,
                                        "native_language": native_language,
                                        "target_language": target_language,
                                        "language_level": level
                                        })

    chatGPT_response["model_used"] = gpt_model

    with open(f"{directory}/{gpt_model}_{level}_response.json", "w") as file:
        json.dump(chatGPT_response, file)

with open(f"{directory}/prompt.txt", "w") as file:
    file.write(prompt(requested_scenario, native_language, target_language, language_level, keywords, length))