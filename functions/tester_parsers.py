import os
import datetime
from lesson_generator import generate_lesson
from main import parse_and_convert_to_speech, parse_and_create_script, TTS_PROVIDERS


now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

example_JSON = {
  "title": "Understanding Viveka Chudamani",
  "all_turns": [
    {
      "target_language": "Shankaracharya, \u00bfqu\u00e9 significa realmente la viveka?",
      "native_language": "Shankaracharya, what does viveka really mean?"
    },
    {
      "target_language": "Viveka es la capacidad para discriminar entre lo real y lo irreal.",
      "native_language": "Viveka is the ability to discriminate between what is real and what is unreal."
    },
    {
      "target_language": "\u00bfY cu\u00e1l es el papel de la paciencia en este aprendizaje?",
      "native_language": "And what is the role of patience in this learning?"
    },
    {
      "target_language": "La paciencia es clave. Te permite profundizar en la comprensi\u00f3n sin prisa.",
      "native_language": "Patience is key. It allows you to deepen understanding without haste."
    }
  ],
  "requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
  "keywords": ["discrimination", "patience"],
  "native_language": "English",
  "target_language": "Spanish (Mexico)",
  "language_level": "C2",
  "speakers": { "speaker_1": { "name": "Rafael", "gender": "m" }, "speaker_2": { "name": "Sof\u00eda", "gender": "f" } },
  "dialogue": [
    {
      "speaker": "speaker_1",
      "turn_nr": 1,
      "target_language": "Shankaracharya, \u00bfqu\u00e9 significa realmente la viveka?",
      "native_language": "Shankaracharya, what does viveka really mean?",
      "narrator_explanation": "Rafael is asking Sof\u00eda, who represents Shankaracharya, about the deep meaning of viveka.",
      "narrator_fun_fact": "Viveka Chudamani is a Sanskrit text attributed to Adi Shankaracharya, focusing on discrimination between the eternal and the ephemeral.",
      "split_sentence": [
        {
          "target_language": "Shankaracharya, \u00bfqu\u00e9 significa",
          "native_language": "Shankaracharya, what does mean",
          "narrator_fun_fact": "||Shankaracharya|| is the name of a revered philosopher in Indian tradition."
        },
        {
          "target_language": "realmente la viveka?",
          "native_language": "really the viveka?",
          "narrator_fun_fact": "The phrase ||realmente la viveka|| queries the true essence of ||viveka||, meaning discernment."
        }
      ]
    }
    ]
}

# create a directory
os.mkdir(f"other/test_{now}")
full_lesson_directory = f"other/test_{now}"

directory_for_new_audio = f"audio"
parse_and_convert_to_speech(example_JSON, directory_for_new_audio, TTS_PROVIDERS.ELEVENLABS)
script = parse_and_create_script(example_JSON)

print(script)
generate_lesson(script, full_lesson_directory, directory_for_new_audio)
