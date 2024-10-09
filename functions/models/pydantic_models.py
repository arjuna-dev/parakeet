from pydantic import BaseModel
from typing import List, Optional

class FirstAPIRequest(BaseModel):
    requested_scenario: str
    native_language: str
    target_language: str
    length: str
    user_ID: str
    document_id: str
    tts_provider: str
    language_level: Optional[str] = "A1"
    keywords: Optional[str] = ""
    voice_mode: bool

class SecondAPIRequest(BaseModel):
    dialogue: List[dict[str, str]]
    document_id: str
    user_ID: str
    title: str
    speakers: dict[str, dict[str, str]]
    native_language: str
    target_language: str
    language_level: str
    length: str
    voice_1_id: str
    voice_2_id: str
    words_to_repeat: List[str]
    tts_provider: str

