from main import chatGPT_API_call
import datetime
import os
import json

now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

user = input("Enter the user name: ")
requested_scenario = input("Requested scenario: ")
native_language = input("Native language: ")
target_language = input("Target language: ")
language_level = input("Language level: ")
length = input("Length: ")
keywords = input("Keywords: ")

response = chatGPT_API_call(requested_scenario, native_language, target_language, language_level, "user_ID", length, keywords)

print("response: ",response)

# Create directory
directory = f"other/{user}_{now}"
os.makedirs(directory, exist_ok=True)

with open(f"{directory}/chatGPT_response.json", "w") as file:
    json.dump(response, file)
