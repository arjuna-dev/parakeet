import openai
import os
import json
from .utilities import is_running_locally, GPT_MODEL

if is_running_locally:
    from dotenv import load_dotenv
    load_dotenv()
    OPEN_AI_API_KEY = os.getenv('OPEN_AI_API_KEY')
else:
    OPEN_AI_API_KEY = os.environ.get("OPEN_AI_API_KEY")

assert OPEN_AI_API_KEY, "OPEN_AI_API_KEY is not set in the environment variables"

def chatGPT_API_call(prompt, use_stream, model=GPT_MODEL.GPT_5_mini.value):

    client = openai.OpenAI(api_key=OPEN_AI_API_KEY)

    # Create the chat completion
    completion = client.chat.completions.create(
        model=model,
        stream=use_stream,
        max_tokens=4096,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in writing engaging dialogues in any language and their translations to any language to be used as content for learning a language. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt}
        ],
        response_format={'type': 'json_object'}
    )

    return completion
