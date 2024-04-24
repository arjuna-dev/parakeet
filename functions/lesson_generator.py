from pydub import AudioSegment # type: ignore
from script_generator import generate_script, get_counts
import datetime
import json

# Constants
now = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
filename = f'full_lesson_{now}.mp3'
audio_files_directory = "audio"
one_second_break = AudioSegment.silent(duration=1000)  # 1000 milliseconds = 1 second
five_second_break = AudioSegment.silent(duration=5000)  # 5000 milliseconds = 5 seconds

# Function to get the audio segment, considering special cases like pauses
def get_audio_segment(key, lesson_script_audio_segments):
    if key == "one_second_break":
        return one_second_break
    elif key == "five_second_break":
        return five_second_break
    else:
        return lesson_script_audio_segments.get(key)

# Function to generate the full lesson audio
def generate_lesson(filename_text_for_tts):
    
    # generating script here
    with open(filename_text_for_tts, 'r') as file:
        text_for_tts = json.load(file)
    lesson_script = generate_script(*get_counts(text_for_tts))
    
    #Create audio segments from the lesson_script
    lesson_script_audio_segments = {}
    for step in lesson_script:
        if step != "one_second_break" and step != "five_second_break":
            try:
                lesson_script_audio_segments[step] = AudioSegment.from_mp3(f"{audio_files_directory}/{step}.mp3")
            except:
                print(f"Warning: Could not create audio segment. Missing audio file for {step}")

    # Combine audio segments in the specified sequence
    combined = AudioSegment.silent(duration=0)  # Start with a silent segment
    for step in lesson_script:
        segment = get_audio_segment(step, lesson_script_audio_segments)
        if segment:
            combined += segment
        else:
            print(f"Warning: Could not add audio segment to full lesson audio. Missing audio segment for {step}")

    # Export the combined audio
    combined.export(filename, format="mp3")
    print(f"Combined audio exported as {filename}")
