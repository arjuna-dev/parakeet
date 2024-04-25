import json


def get_counts(text_for_tts):
    sentence_count = 0
    chunk_count = {}
    target_count = {}
    for key in text_for_tts.keys():
        if "sentence_" in key:
            sentence_number = int(key.split("_")[1])
            if sentence_number > sentence_count:
                sentence_count = sentence_number + 1
            if "split_sentence_" in key:
                chunk_number = int(key.split("_")[4])
                if f"sentence {sentence_number}" not in chunk_count:
                    chunk_count[f"sentence {sentence_number}"] = 0
                    target_count[f"sentence {sentence_number}"] = {}
                if chunk_number > chunk_count[f"sentence {sentence_number}"]:
                    chunk_count[f"sentence {sentence_number}"] = chunk_number + 1
                if "target_" in key:
                    target_number = int(key.split("_")[6])
                    if f"chunk {chunk_number}" not in target_count[f"sentence {sentence_number}"]:
                        target_count[f"sentence {sentence_number}"][f"chunk {chunk_number}"] = 0
                    if target_number > target_count[f"sentence {sentence_number}"][f"chunk {chunk_number}"]:
                        target_count[f"sentence {sentence_number}"][f"chunk {chunk_number}"] = target_number + 1
    return sentence_count, chunk_count, target_count


def generate_script(sentence_count, chunk_count, target_count):
    script = [
        "narrator_opening_phrases_5_0",
        "narrator_opening_phrases_5_1",
        "lesson_title_narrator",
        "narrator_navigation_phrases_7" #listen
    ]
    for i in range(sentence_count):  # Narrator introducing the whole conversation
        script.extend([
            f"sentence_{i}_target"
        ])
    script.extend([
        "one_second_break", 
        "one_second_break"
    ])
    for i in range(sentence_count):  # Repeat for i
        # Sentence i
        script.extend([
            f"sentence_{i}_narrator_explanation",
            "one_second_break",
            "narrator_navigation_phrases_7",  # listen
            "one_second_break",
            f"sentence_{i}_target",
        ])

        for j in range(chunk_count[f"sentence {i}"]):  # Chunk j
            script.extend([
                "narrator_repetition_phrases_0_0",  # Listen to how they say:
                "one_second_break",
                f"sentence_{i}_split_sentence_{j}_native",
                "one_second_break",
                "narrator_repetition_phrases_0_1",
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
                "narrator_navigation_phrases_11",  # It means
                f"sentence_{i}_split_sentence_{j}_native",
                "one_second_break",
                f"sentence_{i}_split_sentence_{j}_narrator_fun_fact",
                "narrator_repetition_phrases_4",
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
            ])
            for k in range(target_count[f"sentence {i}"][f"chunk {j}"]):  # for each k
                script.extend([
                    f"sentence_{i}_split_sentence_{j}_target_{k}",
                    "five_second_break"
                ])
            script.append(f"sentence_{i}_split_sentence_{j}_target")
            script.append("five_second_break")

        # Remember part
        script.extend([
            "narrator_navigation_phrases_8_0",  # Do you remember how to say...
            f"sentence_{i}_split_sentence_{j}_native",
            "one_second_break",
            "narrator_repetition_phrases_3_1",  # Give it a try
            "five_second_break",
        ])
        for j in range(chunk_count[f"sentence {i}"]):  # Chunk j
            script.extend([
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
                f"sentence_{i}_split_sentence_{j}_target",
                "five_second_break",
            ])

        # Wrap up
        script.extend([
            "narrator_navigation_phrases_10",  # listen
            "one_second_break",
            f"sentence_{i}_target",
            "five_second_break",
            f"sentence_{i}_target",
            "five_second_break",
        ])
    script.extend([
        "narrator_closing_phrases_3"
    ])
    return (script)

# with open('text_for_tts.json', 'r') as file:
#     text_for_tts = json.load(file)


# generate_script(*get_counts(text_for_tts))
