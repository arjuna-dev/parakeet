from pydantic import BaseModel
from typing import List, Optional

class Speaker(BaseModel):
    id: str
    name: str
    gender: str

class FirstAPIRequest(BaseModel):
    requested_scenario: str
    category: Optional[str] = "Custom Lesson"
    native_language: str
    target_language: str
    length: str
    user_ID: str
    document_id: str
    tts_provider: str
    language_level: str
    keywords: List[str] | Optional[str] = ""

class SecondAPIRequest(BaseModel):
    dialogue: List[dict[str, str]]
    document_id: str
    user_ID: str
    title: str
    speakers: List[Speaker]
    native_language: str
    target_language: str
    language_level: str
    length: str
    voice_1_id: str
    voice_2_id: str
    words_to_repeat: List[str]
    tts_provider: str
