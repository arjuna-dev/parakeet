from enum import Enum
from prompt import prompt
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
native_language = input("Enter the native language: ")
target_language = input("Enter the target language: ")
language_level = input("Enter the language level: ")
length = input("Enter number of sentences: ")

def chatGPT_API_call(gpt_model, request_data):

    dialogue = request_data.get("dialogue")
    native_language = request_data.get("native_language")
    target_language = request_data.get("target_language")
    length = request_data.get("length")
    try:
        language_level = request_data.get("language_level")
    except:
        language_level = "A1"

    if not all([dialogue, native_language, target_language, language_level]):
        return {'error': 'Missing required parameters in request data'}

    # Create the chat completion
    completion = client.chat.completions.create(
        model=gpt_model,
    #   stream=True,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt(dialogue, native_language, target_language, language_level, length)}
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

dialogue = {"all_turns":[{"native_language":"Albert, I am curious to better understand how you conceived the theory of relativity.","speaker":"speaker_1","target_language":"Albert, tengo curiosidad por entender mejor c\u00f3mo concebiste la teor\u00eda de la relatividad.","turn_nr":"1"},{"native_language":"The basic idea is that space and time are not absolute, but depend on the motion of the observer.","speaker":"speaker_2","target_language":"La idea b\u00e1sica es que el espacio y el tiempo no son absolutos, sino que dependen del movimiento del observador.","turn_nr":"2"},{"native_language":"So, does this suggest that reality can vary for different observers?","speaker":"speaker_1","target_language":"Entonces, \u00bfesto sugiere que la realidad puede variar para diferentes observadores?","turn_nr":"3"},{"native_language":"Exactly, each observer can experience different versions of space-time depending on their state of motion.","speaker":"speaker_2","target_language":"Exactamente, cada observador puede experimentar diferentes versiones del espacio-tiempo dependiendo de su estado de movimiento.","turn_nr":"4"},{"native_language":"How has this discovery influenced current physics?","speaker":"speaker_1","target_language":"\u00bfC\u00f3mo influy\u00f3 este descubrimiento en la f\u00edsica actual?","turn_nr":"5"},{"native_language":"It has completely transformed our understanding of the universe, allowing us to explore everything from black holes to string theories.","speaker":"speaker_2","target_language":"Ha transformado completamente nuestra comprensi\u00f3n del universo, permiti\u00e9ndonos explorar desde agujeros negros hasta teor\u00edas de cuerdas.","turn_nr":"6"}],"speakers":{"speaker_1":{"gender":"m","name":"Shiva"},"speaker_2":{"gender":"m","name":"Albert Einstein"}},"title":"Conversaci\u00f3n sobre la Relatividad","user_ID":"2"}


# Create directory
directory = f"other/{user_name}_{GPT_MODEL.GPT_4_TURBO_V.name}_{now}"
os.makedirs(directory, exist_ok=True)

language_levels = ["A1"]
for level in language_levels:
    chatGPT_response = chatGPT_API_call(gpt_model,
                                        {
                                        "dialogue": dialogue,
                                        "native_language": native_language,
                                        "target_language": target_language,
                                        "language_level": level,
                                        "length": length,
                                        })

    chatGPT_response["model_used"] = gpt_model

    with open(f"{directory}/chatGPT_response.json", "w") as file:
        json.dump(chatGPT_response, file)

with open(f"{directory}/prompt.txt", "w") as file:
    file.write(prompt(dialogue, native_language, target_language, language_level, length))