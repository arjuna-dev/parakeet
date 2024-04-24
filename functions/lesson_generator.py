from pydub import AudioSegment # type: ignore
from script_generator import generate_script, get_counts
import datetime
import json
import os

# Constants
#now = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

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
def generate_lesson(title_name):
    
    #name of the combined audio file
    filename = f'all_files_{title_name}/lesson_final_{title_name}.mp3'
    
    # generating script here
    with open(f'all_files_{title_name}/text_for_tts_{title_name}.json', 'r') as file:
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

    # Delete all the audio files in audio folder which don't start with narrator_
    for file in os.listdir("audio"):
        if not file.startswith("narrator_") and file.endswith(".mp3"):
            os.remove(os.path.join("audio", file))
    
    
    # Export the combined audio
    combined.export(filename, format="mp3")
    print(f"Combined audio exported as {filename}")
