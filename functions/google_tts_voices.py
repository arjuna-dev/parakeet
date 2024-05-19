google_tts_voices =  [
    # Commented as these voices have a very restricted quota
    # {
    #   "language": "English",
    #   "gender": "m",
    #   "voice_id": "en-US-Journey-D",
    #   "voice_category": "Premium",
    #   "voice_type": "Journey",
    #   "language_code": "en-US"
    # },
    # {
    #   "language": "English",
    #   "gender": "f",
    #   "voice_id": "en-US-Journey-F",
    #   "voice_category": "Premium",
    #   "voice_type": "Journey",
    #   "language_code": "en-US"
    # },
    {
      "language": "English",
      "gender": "m",
      "voice_id": "en-US-Journey-D",
      "voice_type": "Premium",
      "language_code": "en-US"
    },
    {
      "language": "English",
      "gender": "f",
      "voice_id": "en-US-Journey-F",
      "voice_type": "Premium",
      "language_code": "en-US"
    },
    {
      "language": "German",
      "gender": "m",
      "voice_id": "de-DE-Studio-B",
      "voice_type": "Premium",
      "language_code": "de-DE"
    },
    {
      "language": "German",
      "gender": "f",
      "voice_id": "de-DE-Studio-C",
      "voice_type": "Premium",
      "language_code": "de-DE"
    },
    {
      "language": "German",
      "gender": "m",
      "voice_id": "de-DE-Neural2-B",
      "voice_type": "Premium",
      "language_code": "de-DE"
    },
    {
      "language": "German",
      "gender": "f",
      "voice_id": "de-DE-Neural2-C	",
      "voice_type": "Premium",
      "language_code": "de-DE"
    },
    {
      "language": "Hungarian",
      "gender": "f",
      "voice_id": "hu-HU-Wavenet-A",
      "voice_type": "Premium",
      "language_code": "en-US"
    }
  ]

quota_limits = {
  "Neural2":{
    "requests_per_minute": 1000
  },
  "Studio":{
    "requests_per_minute": 500
  },
  "Journey":{
    "requests_per_minute": 30
  },
  "Wavenet":{
    "requests_per_minute": 1000
  },
  "Polyglot":{
    "requests_per_minute": 1000
  }
}

voice_types = list(quota_limits.keys())

def sleep_time_according_to_rate_limit(voice, number_of_audio_files):
    # TODO: Would need to keep track of the number of requests made in the last minute by all users
    voice_type = [voice_type for voice_type in voice_types if voice_type in voice.name][0]
    voice_request_limit = quota_limits.get(voice_type).get("requests_per_minute")

    if number_of_audio_files < voice_request_limit:
        return 0

    requests_per_second = voice_request_limit / 60
    sleep_time = 1 / requests_per_second
    sleep_time_w_buffer = sleep_time * 1.1

    return sleep_time_w_buffer
