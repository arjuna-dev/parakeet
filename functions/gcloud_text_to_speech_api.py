from google.cloud import texttospeech, storage

def choose_voice(language_code, gender, specific_voice=None): # specific_voice = "en-US-Standard-C" for narrator
    if gender == "m": 
        ssml_gender = texttospeech.SsmlVoiceGender.MALE
    elif gender == "f":
        ssml_gender = texttospeech.SsmlVoiceGender.FEMALE
        
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


def synthesize_text(text, voice, output_path, bucket_name="conversations_audio_files"):
    """Synthesizes speech from the input string of text."""

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

        # Print the URL of the uploaded audio file
        # print(f"Audio file uploaded to: gs://{bucket_name}/{blob_name}")
        print(f'Audio content written to file {output_path}')

        blob_name = f"{output_path}"

        # Create a storage client
        storage_client = storage.Client()
        

        # Upload the audio file to the bucket
        bucket = storage_client.get_bucket(bucket_name)
        bucket.reload(timeout=300)
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(output_path)
        
        # Make the blob publicly accessible
        blob.make_public()

# narrator_voice = choose_voice('en-US', "f", "en-US-Standard-C")
# synthesize_text("Hello, World!", narrator_voice, "folder/file")