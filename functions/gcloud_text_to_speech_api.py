from google.cloud import texttospeech, storage
from pydub import AudioSegment # type: ignore


def choose_voice(language_code, gender, specific_voice=None): # specific_voice = "en-US-Standard-C" for narrator
    if gender == "m": 
        ssml_gender = texttospeech.SsmlVoiceGender.MALE
    elif gender == "f":
        ssml_gender = texttospeech.SsmlVoiceGender.FEMALE
    else:
        ssml_gender = texttospeech.SsmlVoiceGender.SSML_VOICE_GENDER_UNSPECIFIED
        
    if specific_voice == None:
        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            ssml_gender=ssml_gender
        )
    else:
        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            ssml_gender=ssml_gender,
            name=specific_voice
        )
    return voice


def synthesize_text(text, voice, output_path, local_run=False, bucket_name="conversations_audio_files"):

    client = texttospeech.TextToSpeechClient()

    input_text = texttospeech.SynthesisInput(text=text)

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = client.synthesize_speech(
        request={"input": input_text, "voice": voice, "audio_config": audio_config}
    )

    # The response's audio_content is binary.
    with open(f"{output_path}", "wb") as out:
        out.write(response.audio_content)

    if local_run:
        return f"Audio content written to file {output_path}"

    else:
        # Load audio file
        audio = AudioSegment.from_file(output_path)
        
        # Get duration of audio file
        duration = len(audio) / 1000
        
        # Upload the audio file to the bucket
        blob_name = f"{output_path}"
        storage_client = storage.Client()
        bucket = storage_client.get_bucket(bucket_name)
        blob = bucket.blob(blob_name)
        try:
            blob.upload_from_filename(output_path, timeout = 600)
        except Exception as e:
            print(f'Error uploading file: {e}')    
            
        blob.metadata = {'duration' : str(duration)}
        blob.patch()
        
        # Make the blob publicly accessible
        blob.make_public()
        
        return {output_path.split("/")[1].replace('.mp3', ''): duration}

# narrator_voice = choose_voice('en-US', "f", "en-US-Standard-C")
# synthesize_text("Hello, World!", narrator_voice, "folder/file")