import random

def prompt_dialogue(requested_scenario, category, native_language, target_language, language_level, keywords, length):
   keywords_instruction = ""
   if category == 'Custom Lesson':
      keywords_instruction = f"All the words in {keywords} list should be used in the dialogue if possible."
   else:
      keywords_instruction = "IMPORTANT: ALL the words in {keywords} list MUST be used in the dialogue in their exact form without declination."

   return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 speakers. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords}
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

{keywords_instruction}
If there are spelling mistakes in the content request, fix them. The title should be in {native_language} (native_language). The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture associated with that language to create the names. The translations should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female.
For "keywords_used", include the exact form of the keywords as they appear in the dialogue, even if they differ from their base or dictionary form. Do not alter, stem, or normalize the words — capture them exactly as used.

This is an example of a request you could get and its expected output.


Request:
###
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": ["discriminación", "contexto", "exactamente", "axila"]
"native_language": "English",
"target_language": "Spanish",
"language_level": "C2",
"length": 2
###



Expected output in JSON format:
###
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
        }}
    ],
    "keywords_used": ["discriminar", "contexto", "exactamente"]
}}
###

Puedes habalar y traducir en cualquier idioma, este es un ejemplo de alemán e inglés.

Request:

###
"requested_scenario": "Reasons to become vegetarian",
"keywords": ["Gesundheit", "Mitgefühl", "Erdnussbutter"]
"native_language": "German",
"target_language": "English",
"language_level": "A1"
###

Expected output in JSON format:
###
{{
    "title": "Reasons to Become Vegetarian",
    "speakers": {{
        "speaker_1":{{ "name": "Jonas", "gender": "m" }},
        "speaker_2": {{ "name": "Sophie", "gender": "f" }}
        }},
    "dialogue": [
        {{
            "target_language": "Why should someone become a vegetarian?",
            "native_language": "Warum sollte jemand Vegetarier werden?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "It is good for health and shows compassion for animals.",
            "native_language": "Es ist gut für die Gesundheit und zeigt Mitgefühl für Tiere.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "f"
        }},
        {{
            "target_language": "But can I still eat peanut butter?",
            "native_language": "Aber kann ich trotzdem Erdnussbutter essen?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "Yes, peanut butter is vegetarian!",
            "native_language": "Ja, Erdnussbutter ist vegetarisch, und sogar Astronauten essen sie!",
            "turn_nr": "4",
            "speaker": "speaker_2",
            "gender": "f"
        }}
    ],
    "keywords_used": ["Gesundheit", "Mitgefühl", "Erdnussbutter"]
}}
###
'''

def prompt_translate_keywords(keywords, target_language, native_language):
   return f'''Please translate the following keywords {keywords} to {target_language}. Return an array of objects where each object contains the word in both {native_language} (native_language) and {target_language} (target_language). If a keyword is already in {target_language}, keep it as is for the target_language value, but provide the {native_language} translation for the native_language value.

Example request:
###
keywords: ["health", "compassion", "peanut butter"]
target_language: "German"
native_language: "English"
###

Expected output in JSON format:
###
{{
    "keywords": [
        {{"{native_language}": "health", "{target_language}": "Gesundheit"}},
        {{"{native_language}": "compassion", "{target_language}": "Mitgefühl"}},
        {{"{native_language}": "peanut butter", "{target_language}": "Erdnussbutter"}}
    ]
}}
###

Example request:
###
keywords: ["Gesundheit", "compassion", "Erdnussbutter"]
target_language: "German"
native_language: "English"
###

Expected output in JSON format:
###
{{
    "keywords": [
        {{"{native_language}": "health", "{target_language}": "Gesundheit"}},
        {{"{native_language}": "compassion", "{target_language}": "Mitgefühl"}},
        {{"{native_language}": "peanut butter", "{target_language}": "Erdnussbutter"}}
    ]
}}
###


'''

def prompt_big_JSON(dialogue, native_language, target_language, language_level, length, speakers):
   return f'''Please generate a JSON using this conversation:\n{speakers}\n{dialogue}\n The language level is {language_level}.

   - You will write turns from 1 to {length}.
   - You will write the narrator_explanation and narrator_fun_fact keys of the JSON file in the native_language: {native_language}, when quoting from the target_language, {target_language}, the text should be enclosed in double vertical bars (||).
   - If the target_language ({target_language}) sentence of a turn is contains sub-sentences it should be split in these smaller sub-sentences that have grammatical cohesion and make sense.
    - Then these sub-sentences should be translated as literally as possible to the native_language ({native_language}) taking as context the sub-sentence and NOT the full sentence or conversation.
  - For the narrator_translation json key avoid grammatical explanations, avoid explaining gender and number of articles for example.
  - For the narrator_fun_fact json key focus on things like etymology, explaining compound words, explaining idiomatic phrases, etc.

  Example request:
  ###
  target_language: "Spanish"
  native_language: "English"
  length: 2
  speakers: "speaker_1: Carlos, speaker_2: Elena"
  language_level: "B2"
  dialogue: [similar to the one given above]
  ###

JSON: ###
{{
"dialogue": [
    {{
      "speaker": "speaker_1",
      "turn_nr": "1",
      "native_language": "Hello, I would like a bag of popcorn, please.",
      "narrator_explanation": "Carlos is ordering popcorn at the cinema.",
      "narrator_fun_fact": "The word ||palomitas|| in Spanish means 'popcorn,' but it literally translates to 'little doves,' referring to the way popcorn kernels puff up like small birds.",
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
      "narrator_fun_fact": "The phrase ||¿De qué tamaño?|| means 'What size?' in English. ||Tamaño|| specifically refers to physical size or dimensions. The words ||pequeño||, ||mediano||, and ||grande|| mean 'small,' 'medium,' and 'large' respectively, making this sentence a common way to ask about size options in Spanish."
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
###
Continue adding turns until you reach {length} turns.

Aquí tienes otro ejemplo de un diálogo en alemán para aprender inglés.

Request:
###
target_language: "English"
native_language: "German"
length: 2
[continues...]
###

JSON response by you:
###
{{
 "dialogue": [
    {{
      "speaker": "speaker_1",
      "turn_nr": "1",
      "target_language": "Who do you think is the best player in the upcoming EURO?",
      "native_language": "Wer denkst du ist der beste Spieler bei der kommenden EURO?",
      "narrator_explanation": "Jürgen fragt Maria, wen sie für den besten Spieler bei der kommenden EURO-Fußballmeisterschaft hält.",
      "narrator_fun_fact": "Das englische Wort ||player|| bedeutet 'Spieler' auf Deutsch. Es kommt vom Verb ||play||, das 'spielen' bedeutet. ||Player|| kann für Menschen verwendet werden, die Spiele spielen, Musik machen oder schauspielern. Es wird auch oft für Ausdrücke wie ||team player|| genutzt, was jemanden beschreibt, der gut im Team arbeitet."
      "split_sentence": [
        {{
          "target_language": "Who do you think",
          "native_language": "Wer denkst du",
          "narrator_translation": "||Who do you think|| bedeutet 'Wer denkst du'.",
          "words": [
            {{
              "target_language": "Who",
              "narrator_translation": "||Who|| bedeutet 'Wer'."
            }},
            {{
              "target_language": "do you think",
              "narrator_translation": "||do you think|| bedeutet 'denkst du'."
            }}
          ]
        }},
        {{
          "target_language": "is the best player",
          "native_language": "ist der beste Spieler",
          "narrator_translation": "||Is|| bedeutet 'ist'. ||The best player|| heißt 'der beste Spieler'.",
          "words": [
            {{
              "target_language": "is",
              "narrator_translation": "||Is|| bedeutet 'ist'."
            }},
            {{
              "target_language": "the best player",
              "narrator_translation": "||the best player|| heißt 'Der beste Spieler'."
            }}
          ]
        }},
        {{
          "target_language": "in the upcoming EURO?",
          "native_language": "bei der kommenden EURO?",
          "narrator_translation": "||In the upcoming|| bedeutet 'bei der kommenden'. ||EURO|| ist die Fußball-Europameisterschaft.",
          "words": [
            {{
              "target_language": "in",
              "narrator_translation": "||In|| bedeutet 'bei' oder 'in'."
            }},
            {{
              "target_language": "the",
              "narrator_translation": "||The|| bedeutet 'der', 'die' oder 'das', abhängig vom Kontext."
            }},
            {{
              "target_language": "upcoming",
              "narrator_translation": "||upcoming|| bedeutet 'Kommenden'."
            }},
            {{
              "target_language": "EURO",
              "narrator_translation": "||EURO|| ist die Fußball-Europameisterschaft."
            }}
          ]
        }}
      ]
    }},
    {{
      "speaker": "speaker_2",
      "turn_nr": "2",
      "target_language": "I believe that Mbappé is one of the best players alive at the moment.",
      "native_language": "Ich glaube, dass Mbappé einer der besten Spieler ist, die momentan leben.",
      "narrator_explanation": "Maria sagt, dass sie Mbappé für einen der besten Spieler hält. Hier verwendet sie den Satzanfang ||I believe||, um ihre Meinung auszudrücken.",
      "narrator_fun_fact": "Das englische Wort ||believe|| bedeutet 'glauben' auf Deutsch. Es wird oft mit ||I|| (Ich) verwendet, um Meinungen oder Gedanken auszudrücken.",
      "split_sentence": [
        {{
          "target_language": "I believe",
          "native_language": "Ich glaube",
          "narrator_translation": "||I|| bedeutet 'Ich'. ||Believe|| heißt 'glaube'.",
          "words": [
            {{
              "target_language": "I",
              "narrator_translation": "||I|| bedeutet 'Ich'."
            }},
            {{
              "target_language": "believe",
              "narrator_translation": "||Believe|| heißt 'glaube'."
            }}
          ]
        }},
        {{
          "target_language": "that Mbappé is one of the best players",
          "native_language": "dass Mbappé einer der besten Spieler ist",
          "narrator_translation": "||That|| bedeutet 'dass'. ||One of the best players|| heißt 'einer der besten Spieler'.",
          "words": [
            {{
              "target_language": "that",
              "narrator_translation": "||That|| bedeutet 'dass'."
            }},
            {{
              "target_language": "Mbappé",
              "narrator_translation": "||Mbappé|| ist der Name eines berühmten Fußballspielers."
            }},
            {{
              "target_language": "one of the best",
              "narrator_translation": "||One of the best|| bedeutet 'einer der besten' auf Deutsch. Es beschreibt etwas oder jemanden, der zu den Besten einer Gruppe gehört."
            }},
            {{
              "target_language": "players",
              "narrator_translation": "||Players|| bedeutet 'Spieler' auf Deutsch und bezieht sich auf Personen, die ein Spiel spielen, wie z. B. Fußballspieler."
            }}
          ]
        }},
        {{
          "target_language": "alive at the moment.",
          "native_language": "die momentan leben.",
          "narrator_translation": "||Alive|| bedeutet 'leben'. ||At the moment|| heißt 'momentan'.",
          "words": [
            {{
              "target_language": "alive",
              "narrator_translation": "||Leben|| bedeutet 'alive'."
            }},
            {{
              "target_language": "at the moment",
              "narrator_translation": "||Momentan|| heißt 'at the moment'."
            }}
          ]
        }}
      ]
    }}
  ]
}}
###

Continue adding turns until you reach {length} turns.
'''


def prompt_dialogue_w_transliteration(requested_scenario, category, native_language, target_language, language_level, keywords, length):
  chinese_korean_addition = ""
  if target_language == "Mandarin Chinese" or target_language == "Japanese":
    chinese_korean_addition = 'Please add a space between words even though it is not the traditional way of writing'

  keywords_instruction = ""
  if category == 'Custom Lesson':
    keywords_instruction = f"All the words in {keywords} list should be used in the dialogue."
  else:
    keywords_instruction = "IMPORTANT: EVERY word in {keywords} list MUST be used in the dialogue."

  return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 speakers. You will be using the following content:

requested_scenario: {requested_scenario}
keywords: {keywords}
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

{keywords_instruction}
If there are spelling mistakes in the content request, fix them. The title should be in the native_language: {native_language}. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The main original dialogue happens in the target_language, {target_language}, the translations to native_language, {native_language} should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female. {chinese_korean_addition}. The target_language field should include the text in the {target_language} characters followed by the transliteration enclosed in double vertical lines (||).

The "keywords_used" should be the keywords that are exactly used in the dialogue.
Here is an example of data you could get and its expected output.

Data:
"""
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": ["能力", "耐心"],
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
            "target_language": "维韦卡 在 维韦卡·楚达马尼 的 背景 下 到底 是 什么 意思？ || wéiwéikǎ zài wéiwéikǎ·chǔdámǎní de bèijǐng xià dàodǐ shì shénme yìsi?",
            "native_language": "What exactly does viveka mean in the context of Viveka Chudamani?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "维韦卡 是 分辨 真实 与 非真实 的 能力。 || wéiwéikǎ shì fēnbiàn zhēnshí yǔ fēi zhēnshí de nénglì.",
            "native_language": "Viveka is the ability to discriminate between the real and the unreal.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "m"
        }},
        {{
            "target_language": "这种 辨别 能力 是 如何 发展 的？ || zhè zhǒng biànbié nénglì shì rúhé fāzhǎn de?",
            "native_language": "And how does one develop this discrimination?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "通过 不断 的 练习 和 耐心 来 发展。 || tōngguò bùduàn de liànxí hé nàixīn lái fāzhǎn.",
            "native_language": "It develops through constant practice and patience.",
            "turn_nr": "4",
            "speaker": "speaker_2",
            "gender": "m"
        }}
    ],
    "keywords_used": ["能力", "耐心"]
}}
"""
'''

def prompt_generate_lesson_topic(category, selected_words, target_language, native_language, level_number):
  # Generate a boolean variable that is 50% chances false
  funky_topic = random.choice([True, False])
  extra_instructions = ""

  if funky_topic:
    extra_instructions = "Because we will be generating many such lessons try to think outside the box and come up with a topic that is not too common, but still relevant to the category."

  # Define level-specific instructions
  level_mapping = {
    1: "beginner",
    2: "intermediate",
    3: "advanced"
  }

  level_name = level_mapping.get(level_number, "beginner")

  level_instructions = {
    1: "The topic should be simple, practical, and focus on everyday situations that beginners would encounter.",
    2: "The topic should be moderately complex, covering more nuanced situations and concepts.",
    3: "The topic should be sophisticated, covering abstract concepts, professional situations, or specialized topics."
  }

  level_instruction = level_instructions.get(level_number, level_instructions[1])

  return f'''Generate a language lesson topic that fits the category '{category}' that can be taught with the words in {selected_words}.
        {extra_instructions}

        IMPORTANT: This lesson is for {level_name} level learners. {level_instruction}

        The topic should be fun, engaging and practical for language learning at the {level_name} level.
        Return the response in this exact JSON format:
        {{
            "title": "The lesson title in {native_language}",
            "topic": "The lesson topic in {native_language}"
        }}
        '''

def prompt_suggest_custom_lesson(target_language, native_language):
  return f'''Generate topic and words for a custom language lesson.
        The topic should be engaging, fun and practical for language learning and includes exactly 5 relevant words related to the topic.
        Return the response in this exact JSON format:
        {{
            "title": "The lesson title in {native_language}",
            "topic": "The lesson topic in {native_language}",
            "words_to_learn": ["word1", "word2", "word3", "word4", "word5"]
        }}
        The words should be in {target_language} and in lower case.
        '''