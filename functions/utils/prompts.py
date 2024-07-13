def prompt_dialogue(requested_scenario, native_language, target_language, language_level, keywords, length):
   return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 speakers. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the dialogue if they make sense for the conversation. If the keywords are not used in the conversation then add them to the json key unused_keywords. If there are spelling mistakes in the content request, fix them. The title should be in {native_language}. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The main original dialogue happens in {target_language}, the translations to {native_language} should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female.

With the following data as an example enclosed in double vertical lines (||):

||
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": "discrimination, patience, salmon, armpit"
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
    "dialogue": [
        {{
            "target_language": "\u00bfqu\u00e9 significa exactamente viveka en el contexto de Viveka Chudamani?",
            "native_language": "What exactly does viveka mean in the context of Viveka Chudamani?",
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
    "unused_keywords": ["salmon", "armpit"]
}}
===
'''

def prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers):
   return f'''Please generate a JSON using this conversation:\n{speakers}\n{dialogue}\n The language level is {language_level}. 
   
   - You will write turns from 1 to {length}. 
   - You will write the narrator_explanation and narrator_fun_fact keys of the JSON file in {native_language}, when quoting in {target_language} the text should be enclosed in double vertical bars (||).
   - If the {target_language} sentence of a turn is contains sub-sentences it should be split in these smaller sub-sentences that have grammatical cohesion and make sense.
    - Then these sub-sentences should be translated as literally as possible to {native_language} taking as context the sub-sentence and NOT the full sentence or conversation. 
  - For the narrator_translation json key avoid grammatical explanations, avoid explaining gender and number of articles for example.
  - For the narrator_fun_fact json key focus on things like etymology, explaining compound words, explaining idiomatic phrases, etc.
  
  Here is an example of the JSON file you should generate enclosed in triple equals symbols (===):

JSON: ===
{{
"dialogue": [
    {{
      "speaker": "speaker_1",
      "turn_nr": "1",
      "native_language": "Hello, I would like a bag of popcorn, please.",
      "narrator_explanation": "Carlos is ordering popcorn at the cinema.",
      "narrator_fun_fact": ""Popcorn" is a compound word formed from "pop" and "corn." "Pop" refers to the noise made by the corn as it explodes when heated, and "corn" in this context is derived from the old English grain that encompasses all types of grains, including wheat and barley. However, in modern American English, "corn" typically refers specifically to maize.",
      "target_language": "Hola, me gustaría una bolsa de palomitas, por favor.",
      "split_sentence": [
        {{
          "target_language": "Hola",
          "native_language": "Hello",
          "narrator_translation": "||Hola|| is a universal greeting in Spanish-speaking countries.",
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
      "native_language": "What size? Small, medium, or large?",
      "narrator_explanation": "Elena is asking Carlos about the size of the popcorn bag he wants.",
      "narrator_fun_fact": "The term "popcorn" first appeared in John Russell Bartlett’s 1848 "Dictionary of Americanisms," which reflects its usage in early America. The word has remained relatively unchanged in meaning since that time.",
      "target_language": "¿De qué tamaño? ¿Pequeño, mediano o grande?",
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

Here is another example:
===
{{
 "dialogue": [
    {{
      "speaker": "speaker_1",
      "turn_nr": "1",
      "native_language": "Who do you think is the best player in the upcoming EURO?",
      "narrator_explanation": "Jürgen is asking Maria who she thinks will be the best player in the upcoming EURO soccer tournament.",
      "narrator_fun_fact": "The word ||Spieler|| means 'player' in German. It comes from the verb ||spielen||, which means 'to play'. ||Beste|| is the superlative form of 'good' (||gut||), meaning 'the best'.",
      "target_language": "Wer denkst du ist der beste Spieler bei der kommenden EURO?",
      "split_sentence": [
        {{
          "target_language": "Wer denkst du",
          "native_language": "Who do you think",
          "narrator_translation": "||Wer|| means 'Who'. ||Denkst|| translates to 'think'. ||Du|| means 'you'.",
          "words": [
            {{
              "target_language": "Wer",
              "narrator_translation": "||Wer|| means 'Who'."
            }},
            {{
              "target_language": "denkst",
              "narrator_translation": "||Denkst|| translates to 'think'."
            }},
            {{
              "target_language": "du",
              "narrator_translation": "||Du|| means 'you'."
            }}
          ]
        }},
        {{
          "target_language": "ist der beste Spieler",
          "native_language": "is the best player",
          "narrator_translation": "||Ist|| means 'is'. ||Der beste|| translates to 'the best'. ||Spieler|| means 'player'.",
          "words": [
            {{
              "target_language": "ist",
              "narrator_translation": "||Ist|| means 'is'."
            }},
            {{
              "target_language": "der beste",
              "narrator_translation": "||Der beste|| translates to 'the best'."
            }},
            {{
              "target_language": "Spieler",
              "narrator_translation": "||Spieler|| means 'player'."
            }}
          ]
        }},
        {{
          "target_language": "bei der kommenden EURO?",
          "native_language": "in the upcoming EURO?",
          "narrator_translation": "||Bei|| means 'in' or 'at'. ||Der kommenden|| translates to 'the upcoming'. ||EURO|| is short for the European Football Championship.",
          "words": [
            {{
              "target_language": "bei",
              "narrator_translation": "||Bei|| means 'in' or 'at'."
            }},
            {{
              "target_language": "der kommenden",
              "narrator_translation": "||Der kommenden|| translates to 'the upcoming'."
            }},
            {{
              "target_language": "EURO",
              "narrator_translation": "||EURO|| is short for the European Football Championship."
            }}
          ]
        }}
      ]
    }},
    {{
      "speaker": "speaker_2",
      "turn_nr": "2",
      "native_language": "I believe that Mbappé is one of the best players alive at the moment.",
      "narrator_explanation": "Maria expresses her opinion that Mbappé is currently one of the best players in the world.",
      "narrator_fun_fact": "The German word ||glaube|| means 'believe'. It comes from the Old High German ||gilouben||, which means 'to trust'. ||Momentan|| is derived from the Latin ||momentum||, meaning 'moment'.",
      "target_language": "Ich glaube, dass Mbappé einer der besten Spieler ist, die momentan leben.",
      "split_sentence": [
        {{
          "target_language": "Ich glaube",
          "native_language": "I believe",
          "narrator_translation": "||Ich|| means 'I'. ||Glaube|| means 'believe'.",
          "words": [
            {{
              "target_language": "Ich",
              "narrator_translation": "||Ich|| means 'I'."
            }},
            {{
              "target_language": "glaube",
              "narrator_translation": "||Glaube|| means 'believe'."
            }}
          ]
        }},
        {{
          "target_language": "dass Mbappé einer der besten Spieler ist",
          "native_language": "that Mbappé is one of the best players",
          "narrator_translation": "||Dass|| means 'that'. ||Einer der besten|| means 'one of the best'. ||Spieler|| means 'players'. ||Ist|| means 'is'.",
          "words": [
            {{
              "target_language": "dass",
              "narrator_translation": "||Dass|| means 'that'."
            }},
            {{
              "target_language": "Mbappé",
              "narrator_translation": "||Mbappé|| is a proper noun and refers to the famous football player, Kylian Mbappé."
            }},
            {{
              "target_language": "einer der besten",
              "narrator_translation": "||Einer der besten|| means 'one of the best'."
            }},
            {{
              "target_language": "Spieler",
              "narrator_translation": "||Spieler|| means 'players'."
            }},
            {{
              "target_language": "ist",
              "narrator_translation": "||Ist|| means 'is'."
            }}
          ]
        }},
        {{
          "target_language": "die momentan leben.",
          "native_language": "alive at the moment.",
          "narrator_translation": "||Die|| means 'who'. ||Momentan|| means 'at the moment'. ||Leben|| means 'live' or 'are alive'.",
          "words": [
            {{
              "target_language": "die",
              "narrator_translation": "||Die|| means 'who'."
            }},
            {{
              "target_language": "momentan",
              "narrator_translation": "||Momentan|| means 'at the moment'."
            }},
            {{
              "target_language": "leben.",
              "narrator_translation": "||Leben|| means 'live' or 'are alive'."
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


def prompt_dialogue_w_transliteration(requested_scenario, native_language, target_language, language_level, keywords, length):
  return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 speakers. You will be using the following content:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the dialogue if they are provided. If there are spelling mistakes in the content request, fix them. The title should be in {native_language}. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The main original dialogue happens in {target_language}, the translations to {native_language} should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female. The target_language field should include the text in the {target_language} characters followed by the transliteration enclosed in double vertical lines (||).

Here is an example of data you could get and its expected output.

Data:
"""
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": ["discrimination", "patience"],
"native_language": "English",
"target_language": "Mandarin Chinese",
"language_level": "C2",
"""

Expected JSON output:
"""
{{
    "title": "Understanding Viveka Chudamani",
    "speakers": {{
        "speaker_1":{{ "name": "Li Wei", "gender": "m" }},
        "speaker_2": {{ "name": "Shankaracharya", "gender": "m" }}
        }},
    "dialogue": [
        {{
            "target_language": "维韦卡在维韦卡·楚达马尼的背景下到底是什么意思？ ||wéiwéikǎ zài wéiwéikǎ·chǔdámǎní de bèijǐng xià dàodǐ shì shénme yìsi?||",
            "native_language": "What exactly does viveka mean in the context of Viveka Chudamani?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "维韦卡是分辨真实与非真实的能力。 ||wéiwéikǎ shì fēnbiàn zhēnshí yǔ fēi zhēnshí de nénglì.||",
            "native_language": "Viveka is the ability to discriminate between the real and the unreal.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "m"
        }},
        {{
            "target_language": "这种辨别能力是如何发展的？ ||zhè zhǒng biànbié nénglì shì rúhé fāzhǎn de?||",
            "native_language": "And how does one develop this discrimination?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "通过不断的练习和耐心来发展。 ||tōngguò bùduàn de liànxí hé nàixīn lái fāzhǎn.||",
            "native_language": "It develops through constant practice and patience.",
            "turn_nr": "4",
            "speaker": "speaker_2",
            "gender": "m"
        }}
    ]
}}
"""
'''