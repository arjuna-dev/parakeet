from google.cloud import texttospeech, storage
from google_tts_voices import google_tts_voices

def find_matching_voice_google(language, gender, exclude_voice_id=None):
    voice_id = None
    for voice in google_tts_voices:
        if voice.get('language') == language and voice.get('gender') == gender and voice.get('voice_id') != exclude_voice_id:
            voice_id = voice.get('voice_id')
            return voice_id
    raise Exception("No matching voice found")

def create_google_voice(language_code, voice_id):
    voice = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_id)
    print('voice: ', voice)
    return voice

def google_synthesize_text(text, voice, output_path, local_run=False, bucket_name="conversations_audio_files"):

    client = texttospeech.TextToSpeechClient()

    input_text = texttospeech.SynthesisInput(text=text)

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = client.synthesize_speech(
        request={"input": input_text, "voice": voice, "audio_config": audio_config}
    )
#     response = client.synthesize_speech(
#     input=input_text, voice=voice, audio_config=audio_config
#     )

    # The response's audio_content is binary.
    with open(f"{output_path}", "wb") as out:
        out.write(response.audio_content)

    if local_run:
        return f"Audio content written to file {output_path}"

    else:
        # Upload the audio file to the bucket
        blob_name = f"{output_path}"
        storage_client = storage.Client()
        bucket = storage_client.get_bucket(bucket_name)
        bucket.reload(timeout=300)
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(output_path)
        
        # Make the blob publicly accessible
        blob.make_public()

def list_voices(language_code=None):
    client = tts.TextToSpeechClient()
    response = client.list_voices(language_code=language_code)
    voices = sorted(response.voices, key=lambda voice: voice.name)

    print(f" Voices: {len(voices)} ".center(60, "-"))
    for voice in voices:
        languages = ", ".join(voice.language_codes)
        name = voice.name
        gender = tts.SsmlVoiceGender(voice.ssml_gender).name
        rate = voice.natural_sample_rate_hertz
        print(f"{languages:<8} | {name:<24} | {gender:<8} | {rate:,} Hz")

# narrator_voice = choose_voice('en-US', "f", "en-US-Standard-C")
# synthesize_text("Hello, World!", narrator_voice, "folder/file")