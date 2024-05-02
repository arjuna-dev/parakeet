

def prompt(requested_scenario, native_language, target_language, language_level, keywords, length):
   return f'''Please generate a JSON file with a dialogue containing {length} turns, so that turn_nr should go from 1 to {length}. Include always 2 characters. You will be using the the following content:

requested_scenario: {requested_scenario}
keywords: {keywords} 
target_language: {target_language}
native_language: {native_language}
language_level: {language_level}

The keywords should be used in the dialogue if they are provided. If there are spelling mistakes in the content request, fix them. The names of the speakers should be matching the speakers mentioned in the requested scenario, if no names are provided use the target_language language and culture to create the names. The more advanced language levels could have more than one sentence per turn. The sentence of each turn should be split in small parts of 2 to 4 words that have grammatical cohesion and make sense. The main original dialogue happens in the target_language, the translations of it should be as literal as possible. Skip introductions between speakers unless specified and go straight to the topic of conversation. With the following data as an example:
```
"requested_scenario": "Shankaracharya explains to a disciple the meaning of Viveka Chudamani",
"keywords": ["discrimination", "patience"],
"native_language": "English",
"target_language": "Spanish",
"language_level": "C2",
```

You would generate the following JSON enclosed in triple equals symbols:

JSON:
===
{{
    "title": "Understanding Viveka Chudamani",
    "speakers": {{
        "speaker_1":{{ "name": "Mateo", "gender": "m" }},
        "speaker_2": {{ "name": "Shankaracharya", "gender": "m" }}
        }}
    "all_turns": [
        {{
            "target_language": "Shankaracharya, \u00bfqu\u00e9 significa exactamente viveka en el contexto de Viveka Chudamani?",
            "native_language": "Shankaracharya, what exactly does viveka mean in the context of Viveka Chudamani?"
            "turn_nr": "1",
        }},
        {{
            "target_language": "Viveka es la capacidad de discriminar entre lo real y lo no real.",
            "native_language": "Viveka is the ability to discriminate between the real and the unreal."
            "turn_nr": "2",
        }},
        {{
            "target_language": "\u00bfY c\u00f3mo se desarrolla esta discriminaci\u00f3n?",
            "native_language": "And how does one develop this discrimination?"
            "turn_nr": "3",
        }},
        {{
            "target_language": "Se desarrolla a trav\u00e9s de la pr\u00e1ctica constante y la paciencia.",
            "native_language": "It develops through constant practice and patience."
            "turn_nr": "4",
        }}
    ]
}}
===
'''
