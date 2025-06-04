from pydantic import BaseModel
from typing import List, Dict, Optional, Any

#  *******   **     **     **         *******     ********  **     ** ********
# /**////** /**    ****   /**        **/////**   **//////**/**    /**/**///// 
# /**    /**/**   **//**  /**       **     //** **      // /**    /**/**      
# /**    /**/**  **  //** /**      /**      /**/**         /**    /**/******* 
# /**    /**/** **********/**      /**      /**/**    *****/**    /**/**////  
# /**    ** /**/**//////**/**      //**     ** //**  ////**/**    /**/**      
# /*******  /**/**     /**/******** //*******   //******** //******* /********
# ///////   // //      // ////////   ///////     ////////   ///////  //////// 

class DialogueTurn(BaseModel):
    target_language: str
    native_language: str
    turn_nr: str
    speaker: str
    gender: str

class DialogueStructure(BaseModel):
    title: str
    speakers: Dict[str, Dict[str, str]]
    dialogue: List[DialogueTurn]
    keywords_used: List[str]

#  ******   **   ********             **  ********   *******   ****     **
# /*////** /**  **//////**           /** **//////   **/////** /**/**   /**
# /*   /** /** **      //            /**/**        **     //**/**//**  /**
# /******  /**/**                    /**/*********/**      /**/** //** /**
# /*//// **/**/**    *****           /**////////**/**      /**/**  //**/**
# /*    /**/**//**  ////**       **  /**       /**//**     ** /**   //****
# /******* /** //********       //*****  ********  //*******  /**    //***
# ///////  //   ////////         /////  ////////    ///////   //      /// 

class WordTranslation(BaseModel):
    target_language: str
    narrator_translation: str

class SplitSentence(BaseModel):
    target_language: str
    native_language: str
    narrator_translation: str
    words: List[WordTranslation]

class BigJsonTurn(BaseModel):
    speaker: str
    turn_nr: str
    native_language: str
    narrator_explanation: str
    narrator_fun_fact: str
    target_language: str
    split_sentence: List[SplitSentence]

class BigJsonStructure(BaseModel):
    dialogue: List[BigJsonTurn]

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-Topic_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_


class LessonTopic(BaseModel):
    title: str
    topic: str

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_- Custom Lesson _-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

class CustomLesson(BaseModel):
    title: str
    topic: str
    words_to_learn: List[str]

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_- Translate Keywords -_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

class TranslatedKeywords(BaseModel):
    keywords: List[str]