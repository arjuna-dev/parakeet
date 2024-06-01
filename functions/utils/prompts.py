


def prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length):
   return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 speakers. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the dialogue if they are provided. If there are spelling mistakes in the content request, fix them. The title should be in {native_language}. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The main original dialogue happens in {target_language}, the translations to {native_language} should be as literal as possible. Skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female.

With the following data as an example enclosed in double vertical lines (||):

||
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": ["discrimination", "patience"],
"native_language": "English",
"target_language": "Spanish",
"language_level": "C2",
||

You would generate the following JSON enclosed in triple equals symbols (===):

JSON:
===
{{
    "title": "Understanding Viveka Chudamani",
    "speakers": {{
        "speaker_1":{{ "name": "Mateo", "gender": "m" }},
        "speaker_2": {{ "name": "Shankaracharya", "gender": "m" }}
        }},
    "all_turns": [
        {{
            "target_language": "Shankaracharya, \u00bfqu\u00e9 significa exactamente viveka en el contexto de Viveka Chudamani?",
            "native_language": "Shankaracharya, what exactly does viveka mean in the context of Viveka Chudamani?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "Viveka es la capacidad de discriminar entre lo real y lo no real.",
            "native_language": "Viveka is the ability to discriminate between the real and the unreal.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "m"
        }},
        {{
            "target_language": "\u00bfY c\u00f3mo se desarrolla esta discriminaci\u00f3n?",
            "native_language": "And how does one develop this discrimination?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "Se desarrolla a trav\u00e9s de la pr\u00e1ctica constante y la paciencia.",
            "native_language": "It develops through constant practice and patience.",
            "turn_nr": "4",
            "speaker": "speaker_2",
            "gender": "m"
        }}
    ]
}}
===
'''



def prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers):
   return f'''Please generate a JSON using this conversation:\n{speakers}\n{dialogue}\n Language level is {language_level}. You will write turns from 1 to {length}. You will write the narrator_explanation and narrator_fun_fact keys of the JSON file in {native_language}, when quoting in {target_language} the text should be enclosed in double vertical bars (||). The {target_language} sentence of each turn should be split in smaller parts of maximum 4 words that have grammatical cohesion and make sense and then translated as literally as possible to {native_language}. For the narrator_translation key avoid grammatical explanations, avoid explaining gender and number of articles for example. Here is an example of the JSON file you should generate enclosed in triple equals symbols (===):

JSON: ===
{{
"dialogue": [
    {{
      "speaker": "speaker_1",
      "turn_nr": "1",
      "target_language": "Hola, me gustaría una bolsa de palomitas, por favor.",
      "native_language": "Hello, I would like a bag of popcorn, please.",
      "narrator_explanation": "Carlos is ordering popcorn at the cinema.",
      "narrator_fun_fact": "Popcorn is often associated with movie theaters in many cultures.",
      "split_sentence": [
        {{
          "target_language": "Hola",
          "native_language": "Hello",
          "narrator_translation": "||Hola|| means 'Hello'. It's a universal greeting in Spanish-speaking countries.",
          "words": [
            {{
              "target_language": "Hola",
              "narrator_translation": "||Hola|| means 'Hello'."
            }}
          ]
        }},
        {{
          "target_language": "me gustaría",
          "native_language": "I would like",
          "narrator_translation": "'I would like' is expressed as ||Me gustaría|| in Spanish, used when making polite requests.",
          "words": [
            {{
              "target_language": "me",
              "narrator_translation": "||Me|| translates to 'myself'."
            }},
            {{
              "target_language": "gustaría",
              "narrator_translation": "||Gustaría|| translates to 'would like'."
            }}
          ]
        }},
        {{
          "target_language": "una bolsa",
          "native_language": "a bag",
          "narrator_translation": "||Una bolsa|| translates as 'a bag', commonly used when shopping or ordering items.",
          "words": [
            {{
              "target_language": "una",
              "narrator_translation": "||Una|| translates to 'a'."
            }},
            {{
              "target_language": "bolsa",
              "narrator_translation": "||Bolsa|| translates to 'bag'."
            }}
          ]
        }},
        {{
          "target_language": "de palomitas",
          "native_language": "of popcorn",
          "narrator_translation": "||De palomitas|| translates to 'of popcorn', a popular snack at cinemas.",
          "words": [
            {{
              "target_language": "de",
              "narrator_translation": "||De|| translates to 'of'."
            }},
            {{
              "target_language": "palomitas",
              "narrator_translation": "||Palomitas|| translates to 'popcorn'."
            }}
          ]
        }},
        {{
          "target_language": "por favor",
          "native_language": "please",
          "narrator_translation": "||Por favor|| simply means 'please', a key phrase for polite expressions in Spanish.",
          "words": [
            {{
              "target_language": "por",
              "narrator_translation": "||Por|| translates to 'for'."
            }},
            {{
              "target_language": "favor",
              "narrator_translation": "||Favor|| translates to 'favor'."
            }}
          ]
        }}
      ]
    }},
    {{
      "speaker": "speaker_2",
      "turn_nr": 2,
      "target_language": "¿De qué tamaño? ¿Pequeño, mediano o grande?",
      "native_language": "What size? Small, medium, or large?",
      "narrator_explanation": "Elena is asking Carlos about the size of the popcorn bag he wants.",
      "narrator_fun_fact": "In Spain, popcorn sizes at cinemas can vary widely from one theater to another.",
      "split_sentence": [
        {{
          "target_language": "¿De qué tamaño?",
          "native_language": "What size?",
          "narrator_translation": "'What size?' is asked as ||¿De qué tamaño?|| in Spanish, common in shopping scenarios.",
          "words": [
            {{
              "target_language": "¿De",
              "narrator_translation": "||¿De|| translates to 'of'."
            }},
            {{
              "target_language": "qué",
              "narrator_translation": "||Qué|| translates to 'what'."
            }},
            {{
              "target_language": "tamaño?",
              "narrator_translation": "||Tamaño|| translates to 'size'."
            }}
          ]
        }},
        {{
          "target_language": "¿Pequeño, mediano o grande?",
          "native_language": "Small, medium, or large?",
          "narrator_translation": "Choosing sizes in Spanish involves ||Pequeño, mediano o grande|| for 'Small, medium, or large.'",
          "words": [
            {{
              "target_language": "¿Pequeño",
              "narrator_translation": "||Pequeño|| translates to 'Small'."
            }},
            {{
              "target_language": "mediano",
              "narrator_translation": "||Mediano|| translates to 'Medium'."
            }},
            {{
              "target_language": "o",
              "narrator_translation": "||O|| translates to 'or'."
            }},
            {{
              "target_language": "grande",
              "narrator_translation": "||Grande|| translates to 'Large'."
            }}
          ]
        }}
      ]
    }}
  ]
}}
===
Continue adding turns until you reach {length} turns.
'''
