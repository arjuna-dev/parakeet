import json
from datetime import datetime
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from prompt import prompt
import chatGPT_API_call


now = datetime.now().strftime("%m.%d.%H.%M.%S")

user_name = input("Enter the user name: ")
native_language = input("Enter the native language: ")
target_language = input("Enter the target language: ")
language_level = input("Enter the language level: ")
length = input("Enter number of sentences: ")

dialogue = {"all_turns":[{"native_language":"Albert, I am curious to better understand how you conceived the theory of relativity.","speaker":"speaker_1","target_language":"Albert, tengo curiosidad por entender mejor c\u00f3mo concebiste la teor\u00eda de la relatividad.","turn_nr":"1"},{"native_language":"The basic idea is that space and time are not absolute, but depend on the motion of the observer.","speaker":"speaker_2","target_language":"La idea b\u00e1sica es que el espacio y el tiempo no son absolutos, sino que dependen del movimiento del observador.","turn_nr":"2"},{"native_language":"So, does this suggest that reality can vary for different observers?","speaker":"speaker_1","target_language":"Entonces, \u00bfesto sugiere que la realidad puede variar para diferentes observadores?","turn_nr":"3"},{"native_language":"Exactly, each observer can experience different versions of space-time depending on their state of motion.","speaker":"speaker_2","target_language":"Exactamente, cada observador puede experimentar diferentes versiones del espacio-tiempo dependiendo de su estado de movimiento.","turn_nr":"4"},{"native_language":"How has this discovery influenced current physics?","speaker":"speaker_1","target_language":"\u00bfC\u00f3mo influy\u00f3 este descubrimiento en la f\u00edsica actual?","turn_nr":"5"},{"native_language":"It has completely transformed our understanding of the universe, allowing us to explore everything from black holes to string theories.","speaker":"speaker_2","target_language":"Ha transformado completamente nuestra comprensi\u00f3n del universo, permiti\u00e9ndonos explorar desde agujeros negros hasta teor\u00edas de cuerdas.","turn_nr":"6"}],"speakers":{"speaker_1":{"gender":"m","name":"Shiva"},"speaker_2":{"gender":"m","name":"Albert Einstein"}},"title":"Conversaci\u00f3n sobre la Relatividad","user_ID":"2"}



# Create directory
directory = f"other/{user_name}_{now}"
os.makedirs(directory, exist_ok=True)

language_levels = ["A1"]
for level in language_levels:
    chatGPT_response = chatGPT_API_call(dialogue, native_language, target_language, language_level, length)

    with open(f"{directory}/chatGPT_response.json", "w") as file:
        json.dump(chatGPT_response, file)

with open(f"{directory}/prompt.txt", "w") as file:
    file.write(prompt(dialogue, native_language, target_language, language_level, length))