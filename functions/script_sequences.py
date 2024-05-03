
intro_sequences = []

def intro_sequence_1(narrator_title, target_language):
    script_part = [
            "narrator_opening_phrases_5_0",
            "narrator_opening_phrases_5_1",
            narrator_title,
            "narrator_navigation_phrases_7"  #listen
        ]
    return script_part
intro_sequences.append(intro_sequence_1)

def intro_sequence_2(narrator_title, target_language):
    script_part = [
            "narrator_opening_phrases_3_0",
            target_language,
            "narrator_opening_phrases_3_1",
            "narrator_opening_phrases_5_1",
            narrator_title,
            "narrator_navigation_phrases_7"  #listen
        ]
    return script_part
intro_sequences.append(intro_sequence_2)

def intro_sequence_3(narrator_title, target_language):
    script_part = [
            "narrator_opening_phrases_0",
            narrator_title,
            "narrator_opening_phrases_6_1",  #listen
        ]
    return script_part
intro_sequences.append(intro_sequence_3)

def intro_sequence_4(narrator_title, target_language):
    script_part = [
            "narrator_opening_phrases_2",
            "narrator_opening_phrases_5_1",
            narrator_title,
            "narrator_opening_phrases_6_1",  #listen
        ]
    return script_part
intro_sequences.append(intro_sequence_4)

def intro_sequence_welcomeback(narrator_title, target_language):
    script_part = [
            "narrator_opening_phrases_4_0",
            narrator_title,
            "narrator_navigation_phrases_4_1"  #let's get started
            "narrator_navigation_phrases_6_1"  #listen and repeat
        ]
    return script_part
# intro_sequences.append(intro_sequence_welcomeback)

sentence_sequences = []
def sentence_sequence_1(native, target, narrator_explanation, narrator_fun_fact):
    script_part = [
            narrator_explanation,
            "one_second_break",
            "narrator_navigation_phrases_7",  # listen
            "one_second_break",
            target,
            # "narrator_repetition_phrases_0_0"
        ]
    return script_part
sentence_sequences.append(sentence_sequence_1)

def sentence_sequence_2(native, target, narrator_explanation, narrator_fun_fact):
    script_part = [
            narrator_explanation,
            "one_second_break",
            "narrator_repetition_phrases_0_0",  # listen how they say
            "one_second_break",
            native,
            "one_second_break",
            target,
            "narrator_repetition_phrases_21" # Let's break it down. Listen to the phrase, and repeat it.
        ]
    return script_part
sentence_sequences.append(sentence_sequence_2)

def sentence_sequence_3(native, target, narrator_explanation, narrator_fun_fact):
    script_part = [
            narrator_explanation,
            "one_second_break",
            "narrator_repetition_phrases_2_0",  # Focus on how they say..
            "one_second_break",
            native,
            "one_second_break",
            target,
            "narrator_repetition_phrases_21" # Let's break it down. Listen to the phrase, and repeat it.
        ]
    return script_part
sentence_sequences.append(sentence_sequence_3)

chunk_sequences = []
def chunk_sequence_1(narrator_fun_fact, native_language, target_language, words):
    script_part = [
            native_language,
            "one_second_break",
            "narrator_repetition_phrases_0_1", #"...and try saying it just like that."
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
chunk_sequences.append(chunk_sequence_1)

def chunk_sequence_2(narrator_fun_fact, native_language, target_language, words):
    script_part = []
    words = words_2_reps(words)
    script_part.extend(words)
    script_part.extend([
            "one_second_break",
            "narrator_repetition_phrases_23_0", # how to say
            native_language,
            "one_second_break",
            target_language,
            "narrator_repetition_phrases_11_0", # now say
            native_language,
            "five_second_break",
            target_language,
            "five_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            "one_second_break",
            narrator_fun_fact,
            "narrator_repetition_phrases_5", #Try to echo what they say. Say it out loud.
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ])
    return script_part
chunk_sequences.append(chunk_sequence_2)

def chunk_sequence_3(narrator_fun_fact, native_language, target_language, words):
    script_part = [] 
    script_part.extend(["narrator_navigation_phrases_12", target_language, "one_second_break","narrator_navigation_phrases_14"])
    words = words_2_reps(words)
    script_part.extend(words)
    script_part.extend([
            "one_second_break",
            target_language,
            "one_second_break",
            "narrator_repetition_phrases_3_0", # Can you mimic the way they said...?
            native_language,
            "narrator_repetition_phrases_3_1", # Give it a try
            "five_second_break",
            target_language,
            "five_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            "one_second_break",
            narrator_fun_fact,
            "narrator_repetition_phrases_4", #Listen and repeat
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ])
    return script_part
chunk_sequences.append(chunk_sequence_3)

def chunk_sequence_3rep(narrator_fun_fact, native_language, target_language, words):
    script_part = []
    words = words_2_reps(words)
    script_part.extend(words)
    script_part.extend([
            "one_second_break",
            target_language,
            "one_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            "one_second_break",
            "narrator_repetition_phrases_1_1",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break",
            narrator_fun_fact,
            "narrator_repetition_phrases_4",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ])
    return script_part
chunk_sequences.append(chunk_sequence_3rep)

def chunk_sequence_3rep_new(narrator_fun_fact, native_language, target_language, words):
    script_part = []
    words = words_2_reps(words)
    script_part.extend(words)
    script_part.extend([
            "one_second_break",
            target_language,
            "one_second_break",
            native_language,
            "one_second_break",
            "narrator_repetition_phrases_9_0", # try to say
            target_language,
            "five_second_break",
            target_language,
            "five_second_break",
            target_language,
            "five_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            "one_second_break",
            narrator_fun_fact,
            "narrator_repetition_phrases_12_0", #Repeat the phrase
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ])
    return script_part
chunk_sequences.append(chunk_sequence_3rep_new)

def words_2_reps(chunk):
    script_part = []
    for word in chunk:
        script_part.append(word)
        script_part.append("five_second_break")
        script_part.append(word)
        script_part.append("five_second_break")
    return script_part

def words_3_reps(chunk):
    script_part = []
    for word in chunk:
        script_part.append(word)
        script_part.append("five_second_break")
        script_part.append(word)
        script_part.append("five_second_break")
        script_part.append(word)
        script_part.append("five_second_break")
    return script_part