from pydub import AudioSegment
from script import script

# Define paths to audio files and silence segments
audio_files_directory = "audio"
one_second_break = AudioSegment.silent(duration=1000)  # 1000 milliseconds = 1 second
five_second_break = AudioSegment.silent(duration=5000)  # 5000 milliseconds = 5 seconds

# Dictionary of audio segments, preloaded
audio_segments = {
    "opening_phrase_7": AudioSegment.from_mp3(f"{audio_files_directory}/native_0_sentence.mp3"),
    # "opening_phrase_7": AudioSegment.from_mp3(f"{audio_files_directory}/opening_phrase_7.mp3"),
    # "requested_scenario": AudioSegment.from_mp3(f"{audio_files_directory}/requested_scenario.mp3"),
    # Load other required segments similarly...
}

# Define the order of segments based on your script
sequence = [
    "opening_phrase_7", 
    "five_second_break",
    "opening_phrase_7", 
    # "requested_scenario",
    # "target_language_sentence_1",
    # "target_language_sentence_2",
    # Add other segments as needed
    # "five_second_break",  # Example of including a break
]

# Function to get the audio segment, considering special cases like pauses
def get_audio_segment(key):
    if key == "one_second_break":
        return one_second_break
    elif key == "five_second_break":
        return five_second_break
    else:
        return audio_segments.get(key)

# Combine audio segments in the specified sequence
combined = AudioSegment.silent(duration=0)  # Start with a silent segment
for key in script:
    segment = get_audio_segment(key)
    if segment:
        combined += segment
    else:
        print(f"Warning: Missing audio segment for {key}")

# Export the combined audio
combined.export("full_lesson_audio.mp3", format="mp3")
print("Combined audio exported as 'full_lesson_audio.mp3'")
