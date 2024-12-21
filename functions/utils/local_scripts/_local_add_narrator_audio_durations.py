import json
import os
import concurrent.futures
from google.cloud import firestore
from mutagen.mp3 import MP3

# Language code to language name mapping based on native_language_list.dart
LANGUAGE_NAMES = {
    'en-UK': 'English (UK)',
    'en-AU': 'English (Australia)',
}

def get_audio_duration(file_path):
    """Calculate duration of a local audio file"""
    audio = MP3(file_path)
    return audio.info.length  # Returns length in seconds

def process_language_folder(language_code):
    """Process all audio files for a specific language from local directory"""
    language_name = LANGUAGE_NAMES.get(language_code)

    if not language_name:
        print(f"Warning: No language name mapping found for {language_code}")
        return

    folder_path = f"google_tts/narrator_{language_name}"
    if not os.path.exists(folder_path):
        print(f"Warning: Folder not found for {language_name}")
        return

    durations = {}
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for file_name in os.listdir(folder_path):
            if file_name.endswith('.mp3'):
                file_path = os.path.join(folder_path, file_name)
                base_name = file_name.replace('.mp3', '')
                future = executor.submit(get_audio_duration, file_path)
                futures.append((base_name, future))

        for base_name, future in futures:
            try:
                duration = future.result()
                durations[base_name] = duration
            except Exception as e:
                print(f"Error processing {base_name}: {e}")

    # Add standard breaks
    durations.update({
        "one_second_break": 1.0,
        "five_second_break": 5.0
    })

    # Upload to Firestore
    db = firestore.Client()
    doc_ref = db.collection(f'narrator_audio_files_durations/google_tts/narrator_{language_name}').document('durations')
    doc_ref.set(durations)

    print(f"Processed {len(durations)} files for {language_name}")
    return durations

def main():
    """Process all language folders concurrently"""
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for language_code in LANGUAGE_NAMES.keys():
            future = executor.submit(process_language_folder, language_code)
            futures.append((language_code, future))

        for language_code, future in futures:
            try:
                result = future.result()
                print(f"Completed processing {language_code}")
            except Exception as e:
                print(f"Error processing language {language_code}: {e}")

if __name__ == "__main__":
    main()