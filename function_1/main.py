from firebase_functions import https_fn, options
from firebase_admin import initialize_app
import openai
import json

initialize_app()

@https_fn.on_request(
    cors=options.CorsOptions(
      cors_origins=["*"],
      cors_methods=["GET", "POST"],
  )
)

@https_fn.on_request()
def on_request_example(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response("Hello world!")


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



class GPT_MODEL(Enum):
    GPT_4_TURBO_P = "gpt-4-1106-preview" # Supports JSON mode. Preview model.
    GPT_4_TURBO_V = "gpt-4-turbo-2024-04-09" # Supports vision and JSON mode. The default points to this one as of today.
    GPT_4_TURBO = "gpt-4-turbo" # Supports JSON mode. This points to some other one.
    # GPT_3_5 = "gpt-3.5-turbo-1106" # Supports JSON mode, results were not good.

gpt_model = GPT_MODEL.GPT_4_TURBO.value

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

    if not all([requested_scenario, native_language, target_language, language_level, username, length]):
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
