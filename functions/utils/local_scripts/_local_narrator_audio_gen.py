import json
import sys
import os
import asyncio
from google.cloud import firestore
from mutagen.mp3 import MP3
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from elevenlabs.elevenlabs_api import elevenlabs_tts
from google_tts.gcloud_text_to_speech_api import google_synthesize_text, create_google_voice

# When generating audio for narrator:
# TODO: 1. Add the langugage code and the voice name to narrator_tts_voices.json.
# TODO: 2. Add the language name to the LANGUAGE_NAMES dictionary here.
# TODO: 3. Translate the narrator_transcriptions folder to the language and add it to the narrator_transcriptions with the name: _local_transcriptions_<language_code>.json.
# TODO: 4. Run this script.

# Language code to language name mapping
LANGUAGE_NAMES = {
    'en_UK': 'English (UK)',
    'en_AU': 'English (Australia)',
}

def get_audio_duration(file_path):
    """Calculate duration of a local audio file"""
    audio = MP3(file_path)
    return audio.info.length  # Returns length in seconds

async def generate_audio(key, value, narrator_voice, lang_code):
    language_name = LANGUAGE_NAMES.get(lang_code)
    file_name = f"{key}.mp3"
    file_path = f"google_tts/narrator_{language_name}/{file_name}"

    # Generate the audio file
    await google_synthesize_text(
        value,
        narrator_voice,
        file_path,
        bucket_name="narrator_audio_files"
    )

    # Calculate duration after generation
    try:
        duration = get_audio_duration(file_path)
        return {key: duration}
    except Exception as e:
        print(f"Error calculating duration for {file_path}: {e}")
        return {}

async def process_language(lang_code, voice_name):
    narrator_voice = create_google_voice(voice_name.split("-")[0] + "-" + voice_name.split("-")[1], voice_name)
    narrator_file_durations = {}
    language_name = LANGUAGE_NAMES.get(lang_code)

    # Create output directory if it doesn't exist
    os.makedirs(f"google_tts/narrator_{language_name}", exist_ok=True)

    # Try to load the transcription file for this language
    transcription_file = f'narrator_transcriptions/_local_transcriptions_{lang_code}.json'
    try:
        with open(transcription_file, 'r', encoding='utf-8') as file:
            narrator_pool = json.load(file)
    except FileNotFoundError:
        print(f"Warning: No transcription file found for language code {lang_code}")
        return {}

    # Create tasks for all audio generations
    tasks = [generate_audio(key, value, narrator_voice, lang_code)
             for key, value in narrator_pool.items()]

    # Run all tasks concurrently
    results = await asyncio.gather(*tasks)

    # Combine all results
    for result in results:
        narrator_file_durations.update(result)

    # Add standard breaks
    narrator_file_durations.update({
        "one_second_break": 1.0,
        "five_second_break": 5.0
    })

    # Upload to Firestore
    db = firestore.Client()
    doc_ref = db.collection(f'narrator_audio_files_durations/google_tts/narrator_{language_name}').document('durations')
    doc_ref.set(narrator_file_durations)

    print(f"Processed {len(narrator_file_durations)} files for {language_name}")
    return narrator_file_durations

async def main():
    # Load voice configurations
    try:
        with open('narrator_tts_voices.json', 'r', encoding='utf-8') as file:
            voice_configs = json.load(file)
    except FileNotFoundError:
        print("Error: narrator_tts_voices.json not found")
        return

    # Create tasks for all languages
    tasks = [process_language(lang_code, voice_name)
             for lang_code, voice_name in voice_configs.items()]

    # Process all languages concurrently
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())


# narrator_voice = "GoZIEyk9z3H2szw545o8"
# elevenlabs_tts("Text to generate",narrator_voice, f"audio/{"file_name"}.mp3")