def synthesize_text(conversation, output_path):
    """Synthesizes speech from the input string of text."""
    from google.cloud import texttospeech

    client = texttospeech.TextToSpeechClient()
    print(client.list_voices())

    input_text = texttospeech.SynthesisInput(text=conversation.text)

    # Note: the voice can also be specified by name.
    # Names of voices can be retrieved with client.list_voices().
    
    # check if the speaker is the narrator
    if "narrator" in output_path:
        voice = texttospeech.VoiceSelectionParams(
            language_code="en-US",
            name="en-US-Standard-C",
            ssml_gender=texttospeech.SsmlVoiceGender.FEMALE
        )
    else:
        if conversation.gender == "male": 
            ssml_gender = texttospeech.SsmlVoiceGender.MALE
        else:
            ssml_gender = texttospeech.SsmlVoiceGender.FEMALE
            
        voice = texttospeech.VoiceSelectionParams(
            language_code=conversation.language_code, # this ensures 
            ssml_gender=ssml_gender
        )

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = client.synthesize_speech(
        request={"input": input_text, "voice": voice, "audio_config": audio_config}
    )

    # The response's audio_content is binary.
    with open(f"{output_path}.mp3", "wb") as out:
        out.write(response.audio_content)
        print('Audio content written to file "output.mp3"')

synthesize_text("Hello, World!")