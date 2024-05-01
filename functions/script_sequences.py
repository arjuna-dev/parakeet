

def intro_sequence_1(narrator_title):
    script_part = [
            "narrator_opening_phrases_5_0",
            "narrator_opening_phrases_5_1",
            narrator_title,
            "narrator_navigation_phrases_7"  #listen
        ]
    return script_part


def sentence_sequence_1(native, target, narrator_explanation, narrator_fun_fact):
    script_part = [
            narrator_explanation,
            "one_second_break",
            "narrator_navigation_phrases_7",  # listen
            "one_second_break",
            target,
            "narrator_repetition_phrases_0_0"
        ]
    return script_part

def chunk_sequence_1(narrator_fun_fact, native_language, target_language, words):
    script_part = [
            native_language,
            "one_second_break",
            "narrator_repetition_phrases_0_1",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            "one_second_break",
            narrator_fun_fact,
            "narrator_repetition_phrases_4",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ]
    words = words_2_reps(words)
    script_part.extend(words)
    return script_part

def words_2_reps(chunk):
    script_part = []
    for word in chunk:
        script_part.append(word)
        script_part.append("five_second_break")
        script_part.append(word)
        script_part.append("five_second_break")
    return script_part