import datetime
import json
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from prompts import prompt_dialogue
import chatGPT_API_call
from llm_parametrizer import LLMParametrizer

# user = input("Enter the user name: ")
# requested_scenario = input("Requested scenario: ")
# native_language = input("Native language: ")
# target_language = input("Target language: ")
# language_level = input("Language level: ")
# length = input("Length: ")
# keywords = input("Keywords: ")
user = "Arjuna"
requested_scenario = "Mother complimenting cereal selection"
native_language = "English (UK)"
target_language = "German"
language_level = "A1"
length = "4"
keywords = "shark, roller coaster, ants, ping-pong, shaquille oneal, heavy investments"

prompt1 = prompt_dialogue(requested_scenario, native_language, target_language, "Absolute Beginner", keywords, length)
prompt2 = prompt_dialogue(requested_scenario, native_language, target_language, "Intermediate", keywords, length)
prompt3 = prompt_dialogue(requested_scenario, native_language, target_language, "Advanced", keywords, length)

prmtrzr = LLMParametrizer()
prmtrzr.initialize_OpenAI()
prmtrzr.add_prompts(prompt1, prompt2, prompt3)
results = prmtrzr.run(output_json=True)
print(results)
