def _dialogue_level_instructions(language_level: str) -> str:
   """Extra constraints so dialogue complexity matches the learner profile."""
   s = (language_level or "").strip().lower()
   if "absolute" in s or "a1" in s:
      return (
         "LANGUAGE LEVEL (dialogue) — ABSOLUTE BEGINNER / A1: Use only very common vocabulary and simple grammar in the target language. "
         "Keep each turn toward the shorter end of 6–12 words; one clear idea per turn. Avoid idioms and slang unless required by keywords. "
         "Prefer clear, predictable sentence patterns."
      )
   if ("beginner" in s and "absolute" not in s) or "a2" in s:
      return (
         "LANGUAGE LEVEL (dialogue) — BEGINNER / A2: Mostly simple structures; allow slightly richer vocabulary where natural. "
         "Keep turns concise; avoid rare or literary words unless they appear in keywords."
      )
   if "intermediate" in s or "b1" in s or "b2" in s:
      return (
         "LANGUAGE LEVEL (dialogue) — INTERMEDIATE / B1–B2: Natural everyday language; some longer or layered sentences are fine. "
         "Common colloquialisms are OK when they fit the scenario."
      )
   if "advanced" in s or "c1" in s or "c2" in s:
      return (
         "LANGUAGE LEVEL (dialogue) — ADVANCED / C1–C2: Authentic, nuanced language; varied sentence length and register. "
         "Idioms and subtle humor are allowed when they fit the scenario."
      )
   return (
      "LANGUAGE LEVEL (dialogue): Match complexity to the stated level; default to clear, natural speech."
   )


def _narrator_level_instructions(language_level: str) -> str:
   """How much scaffolding narrator_explanation / fun facts / splits should provide."""
   s = (language_level or "").strip().lower()
   if "absolute" in s or "a1" in s:
      return (
         "NARRATION FOR THIS LEVEL — A1: Keep narrator_explanation short and concrete; focus on meaning, not grammar terminology. "
         "narrator_fun_fact should be one simple memorable fact or literal gloss—avoid long etymological digressions. "
         "Prefer shorter split_sentence chunks and straightforward narrator_translation lines."
      )
   if ("beginner" in s and "absolute" not in s) or "a2" in s:
      return (
         "NARRATION FOR THIS LEVEL — A2: Brief explanations; introduce light tips only when they aid comprehension. "
         "Fun facts can be slightly richer but stay accessible."
      )
   if "intermediate" in s or "b1" in s or "b2" in s:
      return (
         "NARRATION FOR THIS LEVEL — B1–B2: Balance explanation with fluency-building; you may note useful patterns briefly. "
         "Fun facts can include etymology or idioms when helpful."
      )
   if "advanced" in s or "c1" in s or "c2" in s:
      return (
         "NARRATION FOR THIS LEVEL — C1–C2: Prefer concise narration; skip oversimplified word-by-word breakdowns unless pedagogically useful. "
         "Fun facts can focus on nuance, register, collocations, or cultural subtext."
      )
   return "NARRATION: Match explanation depth to the learner level; default to clear, efficient commentary."


def prompt_dialogue(requested_scenario, category, native_language, target_language, language_level, keywords, length):
   keywords_instruction = ""
   if category == 'Custom Lesson':
      keywords_instruction = f"All the words in {keywords} list should be used in the dialogue if possible."
   else:
      keywords_instruction = "IMPORTANT: ALL the words in {keywords} list MUST be used in the dialogue in their exact form without declination."

   return f'''Please generate a JSON file with a dialogue containing EXACTLY {length} turns—no more, no fewer—so that turn_nr should go from 1 to {length}. The "dialogue" array must have exactly {length} objects. Include always 2 speakers. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords}
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

{_dialogue_level_instructions(language_level)}

{keywords_instruction}
If there are spelling mistakes in the content request, fix them. The title should be in {native_language} (native_language). The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture associated with that language to create the names. The translations should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female.
For "keywords_used", include the exact form of the keywords as they appear in the dialogue, even if they differ from their base or dictionary form. Do not alter, stem, or normalize the words — capture them exactly as used.

IMPORTANT: Each dialogue SHOULD be between 6 and 12 words and SHOULD be to the point, AVOID long sentences and unnecessary words.

IMPORTANT: Include natural speech markers and vocal markups throughout the dialogue to make it sound more natural and realistic. USE exactly these markers as defined below:
- Non-speech sounds: [sigh], [laughing], [uhm]
- Style modifiers: [sarcasm], [whispering], [extremely fast]
- Pacing and pauses: [short pause], [medium pause], [long pause]
There should NEVER be two markers one after the other. Place these markers strategically and at natural speech pauses for emotional expression and natural flow.
it should always be enclosed in big brackets [] and not in parentheses ().
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
            "target_language": "[whispering] \u00bfqu\u00e9 significa exactamente viveka [short pause] en el contexto de Viveka Chudamani?",
            "native_language": "[whispering] What exactly does viveka [short pause] mean in the context of Viveka Chudamani?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "Viveka [medium pause] es la capacidad de discriminar [short pause] entre lo real y lo no real.",
            "native_language": "Viveka [medium pause] is the ability to discriminate [short pause] between the real and the unreal.",
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
            "target_language": "It is good for health [short pause] and shows compassion for animals.",
            "native_language": "Es ist gut für die Gesundheit [short pause] und zeigt Mitgefühl für Tiere.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "f"
        }},
        {{
            "target_language": "[sarcasm] But can I still [uhm] eat peanut butter?",
            "native_language": "[sarcasm] Aber kann ich [uhm] trotzdem Erdnussbutter essen?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }}
    ],
    "keywords_used": ["Gesundheit", "Mitgefühl", "Erdnussbutter"]
}}
###
'''

def prompt_translate_keywords(keywords, target_language, native_language):
   return f'''Please translate the following keywords {keywords} to {target_language}. Return an array of objects where each object contains the word in both {native_language} (native_language) and {target_language} (target_language). If a keyword is already in {target_language}, keep it as is for the target_language value, but provide the {native_language} translation for the native_language value.

CRITICAL (used to match vocabulary in the lesson and generate audio):
- The "{target_language}" value for each item must be the exact surface form that will appear in the spoken lesson (same spelling, word boundaries, and spacing as in the dialogue). Multi-word phrases must be a single JSON string (e.g. "guten tag").
- Do not put pipe characters (|) or double pipes (||) inside these values.

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

   {_narrator_level_instructions(language_level)}

   - You will write turns from 1 to {length}.

   STRICT LANGUAGE RULES for "narrator_explanation" and "narrator_fun_fact" (MUST follow):
   - Write the main narration in {native_language} only. The learner hears the native-language narrator voice for all non-quoted text.
   - Only words or short phrases that are actually in {target_language} may appear in {target_language}, and they MUST be wrapped in ||double vertical bars||. Do not write full sentences in {target_language} outside of ||...||.
   - Do NOT write entire explanations in {target_language}. Wrong: a Spanish paragraph when native_language is English. Right: English sentences with ||hola|| or ||¿cómo estás?|| where the target form is cited.
   - If you need to refer to a target phrase, paraphrase in {native_language} and put only the literal target phrase inside ||...||.
   - Speech markers like [sigh] belong in {native_language} narration, not inside ||...|| unless they are part of the quoted target phrase.

   - You will write the narrator_explanation and narrator_fun_fact keys of the JSON file in the native_language: {native_language}, when quoting from the target_language, {target_language}, the text should be enclosed in double vertical bars (||).
   - If the target_language ({target_language}) sentence of a turn is contains sub-sentences it should be split in these smaller sub-sentences that have grammatical cohesion and make sense.
    - Then these sub-sentences should be translated as literally as possible to the native_language ({native_language}) taking as context the sub-sentence and NOT the full sentence or conversation.
  - For the narrator_translation json key avoid grammatical explanations, avoid explaining gender and number of articles for example.
  - For the narrator_fun_fact json key focus on things like etymology, explaining compound words, explaining idiomatic phrases, etc.
IMPORTANT: Include natural speech markers and vocal markups throughout the dialogue to make it sound more natural and realistic. USE exactly these markers as defined below:
- Non-speech sounds: [sigh], [laughing], [uhm]
- Style modifiers: [sarcasm], [whispering], [extremely fast]
- Pacing and pauses: [short pause], [medium pause], [long pause]
There should NEVER be two markers one after the other. Place these markers strategically and at natural speech pauses for emotional expression and natural flow.
it should always be enclosed in big brackets [] and not in parentheses ().
This is an example of a request you could get and its expected output.

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
      "target_language": "[uhm] Who do you think [short pause] is the best player in the upcoming EURO?",
      "native_language": "[uhm] Wer denkst du [short pause] ist der beste Spieler bei der kommenden EURO?",
      "narrator_explanation": "Jürgen fragt Maria [uhm], wen sie für den besten Spieler bei der kommenden EURO-Fußballmeisterschaft hält.",
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
      "target_language": "[sigh] I believe [medium pause] that Mbappé is one of the best players alive at the moment.",
      "native_language": "[sigh] Ich glaube [medium pause], dass Mbappé einer der besten Spieler ist, die momentan leben.",
      "narrator_explanation": "Maria sagt [sigh], dass sie Mbappé für einen der besten Spieler hält. Hier verwendet sie den Satzanfang ||I believe||, um ihre Meinung auszudrücken.",
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

  return f'''Please generate a JSON file with a dialogue containing EXACTLY {length} turns—no more, no fewer—so that turn_nr should go from 1 to {length}. The "dialogue" array must have exactly {length} objects. Include always 2 speakers. Each dialogue should be between 8 and 12 words and should not be too long and to the point. You will be using the following content:

requested_scenario: {requested_scenario}
keywords: {keywords}
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

{keywords_instruction}
If there are spelling mistakes in the content request, fix them. The title should be in the native_language: {native_language}. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The main original dialogue happens in the target_language, {target_language}, the translations to native_language, {native_language} should be as literal as possible. Make sure never to include names in the actual dialogues and skip introductions between speakers unless specified and go straight to the topic of conversation. Specify gender with "m" for male and "f" for female. {chinese_korean_addition}. The target_language field should include the text in the {target_language} characters followed by the transliteration enclosed in double vertical lines (||).

The "keywords_used" should be the keywords that are exactly used in the dialogue.

IMPORTANT: Include natural speech markers and vocal markups throughout the dialogue to make it sound more natural and realistic. USE exactly these markers as defined below:
- Non-speech sounds: [sigh], [laughing], [uhm]
- Style modifiers: [sarcasm], [whispering], [extremely fast]
- Pacing and pauses: [short pause], [medium pause], [long pause]
There should NEVER be two markers one after the other. Place these markers strategically and at natural speech pauses for emotional expression and natural flow.
it should always be enclosed in big brackets [] and not in parentheses ().

This is an example of a request you could get and its expected output.

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
            "target_language": "[curious] 维韦卡 在 维韦卡·楚达马尼 的 背景 下 [short pause] 到底 是 什么 意思？ || [curious] wéiwéikǎ zài wéiwéikǎ·chǔdámǎní de bèijǐng xià [short pause] dàodǐ shì shénme yìsi?",
            "native_language": "[curious] What exactly does viveka [short pause] mean in the context of Viveka Chudamani?",
            "turn_nr": "1",
            "speaker": "speaker_1",
            "gender": "m"
        }},
        {{
            "target_language": "[thoughtfully] 维韦卡 [medium pause] 是 分辨 真实 与 非真实 的 能力。 || [thoughtfully] wéiwéikǎ [medium pause] shì fēnbiàn zhēnshí yǔ fēi zhēnshí de nénglì.",
            "native_language": "[thoughtfully] Viveka [medium pause] is the ability to discriminate between the real and the unreal.",
            "turn_nr": "2",
            "speaker": "speaker_2",
            "gender": "m"
        }},
        {{
            "target_language": "[excited] 这种 辨别 能力 [short pause] 是 如何 借 耐心 来 发展 的？ || [excited] zhè zhǒng biànbié nénglì [short pause] shì rúhé jiè nàixīn lái fāzhǎn de?",
            "native_language": "[excited] And how [short pause] does one develop this discrimination [short pause] through patience?",
            "turn_nr": "3",
            "speaker": "speaker_1",
            "gender": "m"
        }}
    ],
    "keywords_used": ["能力", "耐心"]
}}
"""
'''

def prompt_generate_lesson_topic(category, selected_words, target_language, native_language, level_number, recent_topics=None):
  # Define level-specific instructions
  level_mapping = {
    1: "beginner",
    2: "intermediate",
    3: "advanced"
  }

  level_name = level_mapping.get(level_number, "beginner")

  level_instructions = {
    1: "Use simple, familiar situations: greetings, food, directions, shopping, weather, family, or a typical day.",
    2: "Use situations adults actually run into: making plans, travel, work basics, health, hobbies, services (bank, doctor, phone), or social chat.",
    3: "Use richer but still realistic contexts: work or studies, news and opinions, travel problems, relationships, or modern life (apps, subscriptions, routines)—natural contemporary language, not academic or archaic themes."
  }

  level_instruction = level_instructions.get(level_number, level_instructions[1])

  avoid_block = ""
  if recent_topics:
    avoid_block = f"""
        AVOID REPEATING THESE (the learner already had lessons with these topics):
        {recent_topics}
        Your new "title" and "topic" must be clearly different — do not repeat, translate, or closely paraphrase any of the above.
        """

  return f'''Generate a language lesson topic that fits the category '{category}' and can be taught with the words in {selected_words}.
        {avoid_block}
        TOPIC STYLE (very important):
        - Prefer relatable, modern, everyday life: routines, travel, food, friends, work/school, health, shopping, tech/apps, making plans, small talk.
        - Avoid obscure, quirky, or "random for the sake of it" scenarios (no odd historical figures, niche philosophy, surreal plots, or contrived gimmicks).
        - The learner should think "I could need this sentence this week."

        IMPORTANT: This lesson is for {level_name} level learners. {level_instruction}

        The title and topic should sound natural and useful for language learning at the {level_name} level.
        Return the response in this exact JSON format:
        {{
            "title": "The lesson title in {native_language}",
            "topic": "The lesson topic in {native_language}"
        }}
        '''


def _grammar_level_instructions(language_level: str) -> str:
  normalized = (language_level or "").lower()
  if "a1" in normalized or "absolute beginner" in normalized:
    return (
      "LANGUAGE LEVEL (grammar) — ABSOLUTE BEGINNER / A1: explain the grammar simply, "
      "use very short examples, avoid jargon, and prefer everyday survival language."
    )
  if "a2" in normalized or "beginner" in normalized:
    return (
      "LANGUAGE LEVEL (grammar) — BEGINNER / A2: keep explanations clear and practical, "
      "use short everyday examples, and introduce only light terminology."
    )
  if "b1" in normalized or "b2" in normalized or "intermediate" in normalized:
    return (
      "LANGUAGE LEVEL (grammar) — INTERMEDIATE / B1-B2: use natural examples from daily life, "
      "allow moderate sentence length, and explain form + usage clearly."
    )
  if "c1" in normalized or "c2" in normalized or "advanced" in normalized:
    return (
      "LANGUAGE LEVEL (grammar) — ADVANCED / C1-C2: use nuanced natural examples, "
      "compare registers or edge cases when useful, and keep the lesson practical rather than academic."
    )
  return "LANGUAGE LEVEL (grammar): match explanation depth and example complexity to the learner level."


def prompt_grammar_lesson(requested_topic, native_language, target_language, language_level, length_minutes="7"):
  return f'''Create a narrator-led grammar audio lesson as JSON.
The learner wants help with this grammar topic: "{requested_topic}".

This lesson must:
- be fully narrator based, NOT a dialogue between speakers
- teach one grammar topic only
- feel practical and useful in real life
- use clear examples in {target_language}
- be suitable for a roughly 5 to 10 minute audio lesson, target around {length_minutes} minutes
- adapt to the learner level
- include target-language words, phrases, or sentences in the target_language field
- include narration/explanations in {native_language}
- when the native_language narration mentions an exact target-language word, phrase, or sentence that should be spoken in the target-language voice, wrap only that target-language text in ||double vertical bars||

{_grammar_level_instructions(language_level)}

Return JSON in this exact shape:
{{
  "title": "Lesson title in {native_language}",
  "lesson_type": "grammar",
  "segments": [
    {{
      "section_type": "intro",
      "title": "short section title in {native_language}",
      "native_language": "narrator explanation in {native_language}",
      "target_language": "optional example in {target_language}"
    }},
    {{
      "section_type": "concept",
      "title": "short section title in {native_language}",
      "native_language": "main concept explanation in {native_language}",
      "target_language": "short target-language example"
    }},
    {{
      "section_type": "example",
      "title": "short section title in {native_language}",
      "native_language": "example explanation in {native_language}",
      "target_language": "natural example sentence in {target_language}"
    }},
    {{
      "section_type": "practice",
      "title": "short section title in {native_language}",
      "native_language": "guided practice prompt or reminder in {native_language}",
      "target_language": "practice sentence or phrase in {target_language}"
    }},
    {{
      "section_type": "recap",
      "title": "short section title in {native_language}",
      "native_language": "recap in {native_language}",
      "target_language": "final target-language example"
    }}
  ]
}}

IMPORTANT:
- Create 6 to 10 segments total.
- Use section_type values from this set only: intro, concept, example, practice, recap.
- Every segment must have native_language.
- Most segments should also have target_language.
- Keep target_language examples natural and level-appropriate.
- Keep narration warm and teacher-like.
- In native_language, write the explanation in {native_language}, but if you quote exact {target_language} forms, wrap only those exact target-language parts in ||...||.
- Do not wrap whole native-language sentences in ||...||.
'''


def prompt_grammar_podcast_part_1(requested_topic, native_language, target_language, language_level, total_length_minutes="7"):
  return f'''Create PART 1 of a grammar podcast lesson as JSON.
The learner wants help with this grammar topic: "{requested_topic}".

The podcast format must use exactly two speakers:
- speaker_1: the narrator/teacher, who speaks mostly in {native_language}
- speaker_2: the target-language voice, who speaks only in {target_language} examples, prompts, and drills

The lesson should feel like an audio podcast, not like a chatbot or a dramatic scene.
This is only the short introduction and setup section.
Target duration for PART 1 is about 30 to 60 seconds.

{_grammar_level_instructions(language_level)}

Return JSON in this exact shape:
{{
  "title": "lesson title in {native_language}",
  "lesson_type": "grammar",
  "speakers": {{
    "speaker_1": {{
      "name": "Narrator",
      "role": "narrator",
      "language": "{native_language}"
    }},
    "speaker_2": {{
      "name": "Target Voice",
      "role": "target_language_speaker",
      "language": "{target_language}"
    }}
  }},
  "segments": [
    {{
      "speaker": "speaker_1",
      "text": "teaching narration in {native_language}"
    }},
    {{
      "speaker": "speaker_2",
      "text": "short example or drill in {target_language}"
    }}
  ]
}}

IMPORTANT:
- Create 6 to 10 turns total for PART 1.
- speaker_1 must do most of the speaking.
- speaker_2 should appear regularly with examples, drills, or repetitions in {target_language}.
- speaker_2 must speak target-language examples at a pace appropriate for learner level {language_level}; for beginners this means slower and very clear.
- If speaker_1 mentions an exact {target_language} word or phrase inside a teaching sentence, wrap only that exact target-language snippet in ||...|| so it can be spoken by speaker_2.
- Do not leave target-language snippets inside speaker_1 as plain text; use ||...|| for those quoted forms.
- Do not put target-language examples, conjugation lists, or vocabulary items in speaker_1 unless they are wrapped in ||...||.
- Any exact {target_language} word, phrase, sentence, conjugation, or example must be spoken by speaker_2, never by speaker_1.
- Keep each turn short enough for natural podcast pacing.
- Prefer shorter, cleaner target-language turns so the target speaker can say them slowly and clearly.
- Focus only on introduction, quick context, and one or two simple examples.
- Do not use markdown.
- Return ONLY valid JSON with no commentary before or after it.
- Escape any double quotes that appear inside text values.
- Do not include stage directions, brackets, or speaker names inside the text itself.
- Do not repeat the exact same example too often.
- End PART 1 at a natural handoff point that invites more explanation next.
'''


def prompt_grammar_podcast_part_2(requested_topic, existing_segments, native_language, target_language, language_level, total_length_minutes="7"):
  return f'''Create PART 2 of a grammar podcast lesson as JSON.
The learner wants help with this grammar topic: "{requested_topic}".

PART 1 has already been created with these turns:
{existing_segments}

The podcast format must use exactly two speakers:
- speaker_1: the narrator/teacher, who speaks mostly in {native_language}
- speaker_2: the target-language voice, who speaks only in {target_language} examples, prompts, and drills

This is PART 2 only, which should contain the main lesson content after the short intro.

{_grammar_level_instructions(language_level)}

Return JSON in this exact shape:
{{
  "lesson_type": "grammar",
  "segments": [
    {{
      "speaker": "speaker_1",
      "text": "continuation teaching narration in {native_language}"
    }},
    {{
      "speaker": "speaker_2",
      "text": "continuation example or drill in {target_language}"
    }}
  ]
}}

IMPORTANT:
- Create 16 to 26 turns total for PART 2.
- Continue naturally from PART 1 instead of restarting the lesson.
- speaker_1 must do most of the speaking.
- speaker_2 should appear regularly with examples, drills, or repetitions in {target_language}.
- speaker_2 must speak target-language examples at a pace appropriate for learner level {language_level}; for beginners this means slower and very clear.
- If speaker_1 mentions an exact {target_language} word or phrase inside a teaching sentence, wrap only that exact target-language snippet in ||...|| so it can be spoken by speaker_2.
- Do not leave target-language snippets inside speaker_1 as plain text; use ||...|| for those quoted forms.
- Do not put target-language examples, conjugation lists, or vocabulary items in speaker_1 unless they are wrapped in ||...||.
- Any exact {target_language} word, phrase, sentence, conjugation, or example must be spoken by speaker_2, never by speaker_1.
- Include more guided practice and a final recap.
- Keep each turn short enough for natural podcast pacing.
- Prefer shorter, cleaner target-language turns so the target speaker can say them slowly and clearly.
- Do not use markdown.
- Return ONLY valid JSON with no commentary before or after it.
- Escape any double quotes that appear inside text values.
- Do not include stage directions, brackets, or speaker names inside the text itself.
- End with a clear conclusion.
'''


def prompt_suggest_grammar_lesson(target_language, native_language, language_level, recent_topics=None):
  avoid_block = ""
  if recent_topics:
    avoid_block = f"""
        Do not repeat or closely paraphrase these recently used grammar topics:
        {recent_topics}
        """

  return f'''Suggest one practical grammar lesson topic for a learner of {target_language}.
        {avoid_block}
        The learner level is {language_level}.
        The topic should feel useful in real life, such as tense usage, polite requests, articles, word order, question forms, negation, comparisons, or connectors.
        Avoid academic linguistics jargon unless the level clearly supports it.
        Return the response in this exact JSON format:
        {{
            "title": "The lesson title in {native_language}",
            "topic": "The grammar topic in {native_language}"
        }}
        '''

def prompt_suggest_custom_lesson(target_language, native_language, recent_topics=None):
  avoid_block = ""
  if recent_topics:
    avoid_block = f"""
        Do not repeat or closely paraphrase these recently used topics (titles or scenarios):
        {recent_topics}
        """
  return f'''Generate topic and words for a custom language lesson.
        {avoid_block}
        The topic must feel relatable and modern—situations people actually encounter (daily life, travel, work or study, social plans, food, health, shopping, using apps or services, small talk).
        Avoid weird, overly niche, or gimmicky scenarios; keep it practical and something a learner might use soon.
        Include exactly 3 relevant words related to the topic.
        Return the response in this exact JSON format:
        {{
            "title": "The lesson title in {native_language}",
            "topic": "The lesson topic in {native_language}",
            "words_to_learn": ["word1", "word2", "word3"]
        }}
        The words should be in {target_language} and in lower case.
        '''
