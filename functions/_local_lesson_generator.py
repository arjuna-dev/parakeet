from pydub import AudioSegment # type: ignore
import datetime
import json
import os

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
def generate_lesson(script, save_directory, output_name, audio_files_directory, narrator_audio_files_directory):

    #name of the combined audio file
    filename = f'{save_directory}/{output_name}.mp3'
    
    #Create audio segments from the lesson_script
    lesson_script_audio_segments = {}
    for step in script:
        if step != "one_second_break" and step != "five_second_break":
            try:
                lesson_script_audio_segments[step] = AudioSegment.from_mp3(f"{audio_files_directory}/{step}.mp3")
            except:
                try:
                    lesson_script_audio_segments[step] = AudioSegment.from_mp3(f"{narrator_audio_files_directory}/{step}.mp3")
                except:
                    print(f"Warning: Could not create audio segment. Missing audio file for {step}")

    # Combine audio segments in the specified sequence
    combined = AudioSegment.silent(duration=0)  # Start with a silent segment
    for audio_file_name in script:
        segment = get_audio_segment(audio_file_name, lesson_script_audio_segments)
        if segment:
            combined += segment
        else:
            print(f"Warning: Could not add audio segment to full lesson audio. Missing audio segment for {audio_file_name}")
    
    # Export the combined audio
    combined.export(filename, format="mp3")
    print(f"Combined audio exported as {filename}")
