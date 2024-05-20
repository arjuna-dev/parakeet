def chatGPT_API_call(dialogue, native_language, target_language, language_level, length, speakers):

    client = openai.OpenAI(api_key=OPEN_AI_API_KEY)

    # Create the chat completion
    completion = client.chat.completions.create(
        model=gpt_model,
        #   stream=True,
        messages=[
            {"role": "system", "content": "You are a language learning teacher and content creator. You specialize in creating engaging conversations in any language to be used as content for learning. You are also able to create conversations in different tones and for different audiences."},
            {"role": "user", "content": prompt(dialogue, native_language, target_language, language_level, length, speakers)}
        ],
        response_format={'type': 'json_object'}
    )

    chatGPT_JSON_response = completion.choices[0].message.content
    try:
        data = json.loads(chatGPT_JSON_response)
    except Exception as e:
        print(chatGPT_JSON_response)
        print(f"Error parsing JSON response from chatGPT: {e}")
        #TODO: log error and failed JSON in DB and ask the user to try again
        return

    return data