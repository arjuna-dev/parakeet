

def prompt(dialogue, native_language, target_language, language_level, length):
   return f'''Please generate a JSON using this information:\n {dialogue} \n Language level is {language_level}. You will write turns from 1 to {length}. You will write the narrator_explanation and narrator_fun_fact keys of the JSON file in {native_language}, when quoting in {target_language} the text should be enclosed in double vertical bars (||). The {target_language} sentence of each turn should be split in smaller parts of maximum 4 words that have grammatical cohesion and make sense and then translated as literally as possible to {native_language}. For the narrator_translation key avoid grammatical explanations, avoid explaining gender and number of articles for example. Here is an example of the JSON file you should generate enclosed in triple equals symbols (===):

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
'''
