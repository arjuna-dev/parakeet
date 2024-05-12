
intro_sequences = []

def intro_sequence_1():
    script_part = [
            "narrator_opening_phrases_5_0",
            "narrator_opening_phrases_5_1",
            "title",
            "narrator_opening_phrases_8", #Now just listen to the whole conversation
        ]
    return script_part
intro_sequences.append(intro_sequence_1)

# def intro_sequence_2():
#     script_part = [
#             "narrator_opening_phrases_3_0",
#             "target_language",
#             "narrator_opening_phrases_3_1",
#             "narrator_opening_phrases_5_1",
#             "title",
#             "narrator_opening_phrases_7", #Let's first listen to the whole conversation
#         ]
#     return script_part
# intro_sequences.append(intro_sequence_2)

def intro_sequence_3():
    script_part = [
            "narrator_opening_phrases_0",
            "title",
            "narrator_opening_phrases_7", #Let's first listen to the whole conversation
        ]
    return script_part
intro_sequences.append(intro_sequence_3)

def intro_sequence_4():
    script_part = [
            "narrator_opening_phrases_2",
            "narrator_opening_phrases_5_1",
            "title",
            "narrator_opening_phrases_8", #Now just listen to the whole conversation
        ]
    return script_part
intro_sequences.append(intro_sequence_4)

outro_sequences =[]
def intro_outro_sequence_1():
    script_part = [
            "one_second_break",
            "narrator_navigation_phrases_18",  #You just listened to the full conversation.",
            "narrator_navigation_phrases_19", #Now, let's go through the dialog 
            "one_second_break"
        ]
    return script_part
outro_sequences.append(intro_outro_sequence_1)

sentence_sequences = []

def sentence_sequence_1(native, target, narrator_explanation, narrator_fun_fact, is_first_sentence=False):
    first_phrase = "narrator_navigation_phrases_20" if is_first_sentence else "narrator_navigation_phrases_21"
    script_part = [
            first_phrase, #For now just listen 
            "one_second_break",
            target,
            "one_second_break",
            narrator_explanation,
            "narrator_navigation_phrases_22", # Just listen
            target,
            "one_second_break",
            narrator_fun_fact,
            "one_second_break",
        ]
    return script_part
sentence_sequences.append(sentence_sequence_1)

active_recall_sequences = []
def active_recall_sequence_1(native, target):
    script_part = [
            "narrator_navigation_phrases_8_0", # do you remember how to say...
            native,
            "narrator_navigation_phrases_8_1" , #in
            "target_language",
            "five_second_break",
            target,
            "five_second_break",
            target,
            "five_second_break",
        ]
    return script_part
active_recall_sequences.append(sentence_sequence_1)

chunk_sequences = []
def chunk_sequence_1(narrator_fun_fact, native_language, target_language, word_objects, chunk_number):
    words = words_2_reps(word_objects)
    if chunk_number == 0:
        first_phrase = "narrator_navigation_phrases_17" #"Now, let's break down the sentence"
    else:
        first_phrase = "narrator_navigation_phrases_23" #"Now, let's go to the next part of the sentence"
    script_part = [
            first_phrase,
            "narrator_navigation_phrases_22", # Just listen
            target_language,
            "one_second_break",
            *words,
            "narrator_navigation_phrases_8_0", # Do you remember how to say..
            native_language,
            "five_second_break",
            target_language,
            "five_second_break",
            "narrator_repetition_phrases_25", #"pay attention to the pronouncitation and try saying it just like that."
            target_language,
            "five_second_break",
            "narrator_navigation_phrases_11", #It means
            native_language,
            *narrator_fun_fact,
            "narrator_repetition_phrases_4", #Listen and repeat
            target_language,
            "five_second_break",
            target_language,
            "five_second_break"
        ]
    return script_part
chunk_sequences.append(chunk_sequence_1)

def words_2_reps(word_objects):
    script_part = []
    for i, word_object in enumerate(word_objects):
        script_part.extend(word_object["translation"])
        if i == 0:
            script_part.append("narrator_repetition_phrases_4") # Listen and repeat
        script_part.append(word_object["word"])
        script_part.append("five_second_break")
        script_part.append(word_object["word"])
        script_part.append("five_second_break")
    return script_part

def words_3_reps(word_objects):
    script_part = []
    for word_object in word_objects:
        script_part.extend(word_object["translation"])
        "narrator_repetition_phrases_4"
        script_part.append(word_object["word"])
        script_part.append("five_second_break")
        script_part.append(word_object["word"])
        script_part.append("five_second_break")
        script_part.append(word_object["word"])
        script_part.append("five_second_break")
    return script_part