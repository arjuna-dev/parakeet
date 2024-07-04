import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from prompts import prompt_big_JSON
from llm_parametrizer import LLMParametrizer

# user_name = input("Enter the user name: ")
# native_language = input("Enter the native language: ")
# target_language = input("Enter the target language: ")
# language_level = input("Enter the language level: ")
# length = input("Enter number of sentences: ")

# dialogue = {"all_turns":[{"native_language":"Albert, I am curious to better understand how you conceived the theory of relativity.","speaker":"speaker_1","target_language":"Albert, tengo curiosidad por entender mejor c\u00f3mo concebiste la teor\u00eda de la relatividad.","turn_nr":"1"},{"native_language":"The basic idea is that space and time are not absolute, but depend on the motion of the observer.","speaker":"speaker_2","target_language":"La idea b\u00e1sica es que el espacio y el tiempo no son absolutos, sino que dependen del movimiento del observador.","turn_nr":"2"},{"native_language":"So, does this suggest that reality can vary for different observers?","speaker":"speaker_1","target_language":"Entonces, \u00bfesto sugiere que la realidad puede variar para diferentes observadores?","turn_nr":"3"},{"native_language":"Exactly, each observer can experience different versions of space-time depending on their state of motion.","speaker":"speaker_2","target_language":"Exactamente, cada observador puede experimentar diferentes versiones del espacio-tiempo dependiendo de su estado de movimiento.","turn_nr":"4"},{"native_language":"How has this discovery influenced current physics?","speaker":"speaker_1","target_language":"\u00bfC\u00f3mo influy\u00f3 este descubrimiento en la f\u00edsica actual?","turn_nr":"5"},{"native_language":"It has completely transformed our understanding of the universe, allowing us to explore everything from black holes to string theories.","speaker":"speaker_2","target_language":"Ha transformado completamente nuestra comprensi\u00f3n del universo, permiti\u00e9ndonos explorar desde agujeros negros hasta teor\u00edas de cuerdas.","turn_nr":"6"}],"speakers":{"speaker_1":{"gender":"m","name":"Shiva"},"speaker_2":{"gender":"m","name":"Albert Einstein"}},"title":"Conversaci\u00f3n sobre la Relatividad","user_ID":"2"}

dialogue = {
  "all_turns": [
    {
      "native_language": "Thomas, I would like to learn more about compliance regulations in Germany.",
      "speaker": "speaker_1",
      "target_language": "Thomas, ich möchte mehr über die Einhaltung der Vorschriften in Deutschland erfahren.",
      "turn_nr": "1"
    },
    {
      "native_language": "Sure, compliance in Germany includes various legal and ethical standards that companies must adhere to.",
      "speaker": "speaker_2",
      "target_language": "Gerne, Compliance umfasst in Deutschland verschiedene rechtliche und ethische Standards, die Unternehmen einhalten müssen.",
      "turn_nr": "2"
    },
    {
      "native_language": "How does the German compliance system differ from other countries?",
      "speaker": "speaker_1",
      "target_language": "Wie unterscheidet sich das deutsche Compliance-System von anderen Ländern?",
      "turn_nr": "3"
    },
    {
      "native_language": "The German system places great emphasis on prevention and self-regulation, whereas other countries might have stricter government controls.",
      "speaker": "speaker_2",
      "target_language": "Das deutsche System legt großen Wert auf Prävention und Selbstregulierung, während andere Länder möglicherweise strengere staatliche Kontrollen haben.",
      "turn_nr": "4"
    },
    {
      "native_language": "What role does the GDPR play in the German compliance landscape?",
      "speaker": "speaker_1",
      "target_language": "Welche Rolle spielt die DSGVO in der deutschen Compliance-Landschaft?",
      "turn_nr": "5"
    },
    {
      "native_language": "The GDPR is a key component, as it imposes strict requirements on data protection and security that companies must comply with.",
      "speaker": "speaker_2",
      "target_language": "Die DSGVO ist ein zentraler Bestandteil, da sie strenge Vorgaben zum Datenschutz und zur Datensicherheit macht, die Unternehmen erfüllen müssen.",
      "turn_nr": "6"
    },
    {
      "native_language": "Are there specific industries that are particularly heavily regulated?",
      "speaker": "speaker_1",
      "target_language": "Gibt es spezifische Branchen, die besonders stark reguliert sind?",
      "turn_nr": "7"
    },
    {
      "native_language": "Yes, especially the financial sector, healthcare, and the energy industry are subject to strict regulations and regular audits.",
      "speaker": "speaker_2",
      "target_language": "Ja, besonders die Finanzbranche, das Gesundheitswesen und die Energiebranche unterliegen strengen Vorschriften und regelmäßigen Überprüfungen.",
      "turn_nr": "8"
    }
  ],
  "speakers": {
    "speaker_1": {
      "gender": "f",
      "name": "Anna"
    },
    "speaker_2": {
      "gender": "m",
      "name": "Thomas"
    }
  },
  "title": "Konversation über Compliance in Deutschland",
  "user_ID": "3"
}

prmtrzr = LLMParametrizer()
prmtrzr.initialize_OpenAI()

prompt_1  = prompt_big_JSON(dialogue["all_turns"], "English (US)", "German", "C2", "4", dialogue["speakers"])
prmtrzr.add_prompts(prompt_1)
# prmtrzr.add_models(GPT_MODEL.GPT_4o.value, GPT_MODEL.GPT_3_5_T.value)
prmtrzr.add_temperatures(0.5, 1.0, 2.0)
results = prmtrzr.run(output_csv=True)
print(results)
