from google.cloud import texttospeech

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


def synthesize_text(text, voice, output_path):
    """Synthesizes speech from the input string of text."""

    client = texttospeech.TextToSpeechClient()
    # print(client.list_voices())

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
        print(f'Audio content written to file {output_path}.mp3')

# synthesize_text("Hello, World!")