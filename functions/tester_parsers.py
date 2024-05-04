import os
import datetime
from lesson_generator import generate_lesson
from json_parsers import parse_and_convert_to_speech, parse_and_create_script, TTS_PROVIDERS


now = datetime.datetime.now().strftime("%m.%d.%H.%M.%S")

example_JSON = {
  "dialogue": [
    {
      "speaker": "speaker_1",
      "turn_nr": "1",
      "target_language": "Albert, tengo curiosidad por entender mejor c\u00f3mo concebiste la teor\u00eda de la relatividad.",
      "native_language": "Albert, I am curious to better understand how you conceived the theory of relativity.",
      "narrator_explanation": "Shiva is expressing curiosity in understanding the development of the theory of relativity.",
      "narrator_fun_fact": "The theory of relativity was introduced by Albert Einstein in the early 20th century, altering the basics of physics.",
      "split_sentence": [
        {
          "target_language": "Albert, tengo curiosidad",
          "native_language": "Albert, I am curious",
          "narrator_translation": "||Albert, tengo curiosidad|| translates as 'Albert, I am curious'.",
          "words": [
            { "target_language": "Albert,", "narrator_translation": "||Albert|| is a direct address." },
            { "target_language": "tengo", "narrator_translation": "||Tengo|| means 'I have'." },
            { "target_language": "curiosidad", "narrator_translation": "||Curiosidad|| means 'curiosity'." }
          ]
        },
        {
          "target_language": "por entender mejor c\u00f3mo",
          "native_language": "to better understand how",
          "narrator_translation": "'To better understand how' is expressed as ||por entender mejor c\u00f3mo||.",
          "words": [
            { "target_language": "por", "narrator_translation": "||Por|| translates to 'for/to'." },
            { "target_language": "entender", "narrator_translation": "||Entender|| means 'understand'." },
            { "target_language": "mejor", "narrator_translation": "||Mejor|| means 'better'." },
            { "target_language": "c\u00f3mo", "narrator_translation": "||C\u00f3mo|| translates to 'how'." }
          ]
        },
        {
          "target_language": "concebiste la teor\u00eda",
          "native_language": "you conceived the theory",
          "narrator_translation": "'You conceived the theory' is translated as ||concebiste la teor\u00eda||.",
          "words": [
            { "target_language": "concebiste", "narrator_translation": "||Concebiste|| means 'you conceived'." },
            { "target_language": "la", "narrator_translation": "||La|| translates to 'the'." },
            { "target_language": "teor\u00eda", "narrator_translation": "||Teor\u00eda|| means 'theory'." }
          ]
        },
        {
          "target_language": "de la relatividad.",
          "native_language": "of relativity.",
          "narrator_translation": "'Of relativity' is shown as ||de la relatividad.||",
          "words": [
            { "target_language": "de", "narrator_translation": "||De|| translates to 'of'." },
            { "target_language": "la", "narrator_translation": "||La|| translates to 'the'." },
            { "target_language": "relatividad", "narrator_translation": "||Relatividad|| means 'relativity'." }
          ]
        }
      ]
    },
    {
      "speaker": "speaker_2",
      "turn_nr": "2",
      "target_language": "La idea b\u00e1sica es que el espacio y el tiempo no son absolutos, sino que dependen del movimiento del observador.",
      "native_language": "The basic idea is that space and time are not absolute, but depend on the motion of the observer.",
      "narrator_explanation": "Albert explains the fundamental aspect of the theory of relativity regarding space and time.",
      "narrator_fun_fact": "Einstein's theory proposed a radical departure from traditional Newtonian physics.",
      "split_sentence": [
        {
          "target_language": "La idea b\u00e1sica es que",
          "native_language": "The basic idea is that",
          "narrator_translation": "'The basic idea is that' translates to ||La idea b\u00e1sica es que||.",
          "words": [
            { "target_language": "La", "narrator_translation": "||La|| translates to 'the'." },
            { "target_language": "idea", "narrator_translation": "||Idea|| means 'idea'." },
            { "target_language": "b\u00e1sica", "narrator_translation": "||B\u00e1sica|| translates to 'basic'." },
            { "target_language": "es", "narrator_translation": "||Es|| means 'is'." },
            { "target_language": "que", "narrator_translation": "||Que|| translates to 'that'." }
          ]
        },
        {
          "target_language": "el espacio y el tiempo",
          "native_language": "space and time",
          "narrator_translation": "'Space and time' is expressed as ||el espacio y el tiempo|| in Spanish.",
          "words": [
            { "target_language": "el", "narrator_translation": "||El|| translates to 'the'." },
            { "target_language": "espacio", "narrator_translation": "||Espacio|| means 'space'." },
            { "target_language": "y", "narrator_translation": "||Y|| means 'and'." },
            { "target_language": "el", "narrator_translation": "||El|| translates to 'the'." },
            { "target_language": "tiempo", "narrator_translation": "||Tiempo|| means 'time'." }
          ]
        },
        {
          "target_language": "no son absolutos,",
          "native_language": "are not absolute,",
          "narrator_translation": "'Are not absolute,' is translated to ||no son absolutos,||.",
          "words": [
            { "target_language": "no", "narrator_translation": "||No|| translates to 'not'." },
            { "target_language": "son", "narrator_translation": "||Son|| means 'are'." },
            { "target_language": "absolutos,", "narrator_translation": "||Absolutos,|| means 'absolute,'." }
          ]
        },
        {
          "target_language": "sino que dependen del movimiento",
          "native_language": "but depend on the motion",
          "narrator_translation": "'But depend on the motion' is phrased as ||sino que dependen del movimiento|| in Spanish.",
          "words": [
            { "target_language": "sino", "narrator_translation": "||Sino|| translates to 'but'." },
            { "target_language": "que", "narrator_translation": "||Que|| translates to 'that'." },
            { "target_language": "dependen", "narrator_translation": "||Dependen|| means 'depend'." },
            { "target_language": "del", "narrator_translation": "||Del|| translates to 'of the'." },
            { "target_language": "movimiento", "narrator_translation": "||Movimiento|| means 'motion'." }
          ]
        },
        {
          "target_language": "del observador.",
          "native_language": "of the observer.",
          "narrator_translation": "'Of the observer' translates to ||del observador.||",
          "words": [
            { "target_language": "del", "narrator_translation": "||Del|| translates to 'of the'." },
            { "target_language": "observador", "narrator_translation": "||Observador|| means 'observer'." }
          ]
        }
      ]
    }
  ]
}

# create a directory
os.mkdir(f"other/test_{now}")
full_lesson_directory = f"other/test_{now}"

directory_for_new_audio = f"audio"
# parse_and_convert_to_speech(example_JSON, directory_for_new_audio, TTS_PROVIDERS.ELEVENLABS)
script = parse_and_create_script(example_JSON)

print(script)
# generate_lesson(script, full_lesson_directory, directory_for_new_audio)
