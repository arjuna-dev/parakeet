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

def chatGPT_API_call(prompt, use_stream, pydantic_model):
    """
    Make API calls to OpenAI's ChatGPT with structured output support.
    
    Args:
        prompt: The prompt to send to the API
        use_stream: Boolean indicating whether to use streaming responses
        pydantic_model: Required Pydantic model class that defines the response structure
    
    Returns:
        If streaming is False: The API response parsed according to the provided Pydantic model
        If streaming is True: A stream object that can be iterated for partial results and/or used to get the final completion
    """
    client = openai.OpenAI(api_key=OPEN_AI_API_KEY)
    
    # System message that defines the assistant's behavior
    system_message = "You are a language learning teacher and content creator. You specialize in writing engaging dialogues in any language and their translations to any language to be used as content for learning a language. You are also able to create conversations in different tones and for different audiences."
    
    # Prepare messages array
    messages = [
        {"role": "system", "content": system_message},
        {"role": "user", "content": prompt}
    ]
    
    if use_stream:
        # Use the stream helper with the pydantic model for structured streaming
        completion = client.beta.chat.completions.stream(
            model=GPT_MODEL.GPT_41_nano.value,
            messages=messages,
            max_tokens=4096,
            response_format=pydantic_model
        )
    else:
        # For non-streaming, use the parse method with direct pydantic model
        completion = client.beta.chat.completions.parse(
            model=GPT_MODEL.GPT_41_nano.value,
            messages=messages,
            response_format=pydantic_model
        )
    return completion
