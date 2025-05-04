import 'dart:math';

enum RecallType {
  overdueWord,
  thisConversation,
}

List<Function> introSequences = [introSequence1, introSequence2, introSequence3, introSequence4, introSequence5];

List<String> introSequence1() {
  List<String> scriptPart = [
    "nickname",
    "narrator_opening_phrases_15",
    "narrator_opening_phrases_5_1",
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
    "one_second_break",
  ];
  return scriptPart;
}

List<String> introSequence2() {
  List<String> scriptPart = [
    "nickname",
    "narrator_opening_phrases_5_1", // today's lesson is
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
    "one_second_break",
  ];
  return scriptPart;
}

List<String> introSequence3() {
  List<String> scriptPart = [
    "nickname",
    "narrator_opening_phrases_0",
    "title",
    "narrator_opening_phrases_7", //Let's first listen to the whole conversation
    "one_second_break",
  ];
  return scriptPart;
}

List<String> introSequence4() {
  List<String> scriptPart = [
    "nickname",
    "narrator_opening_phrases_14",
    "narrator_opening_phrases_5_1", // today's lesson is
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
    "one_second_break",
  ];
  return scriptPart;
}

List<String> introSequence5() {
  List<String> scriptPart = [
    "nickname",
    "narrator_opening_phrases_4_0", // welcome back today we're going to practice phrases that will help you with the topic...
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
    "one_second_break",
  ];
  return scriptPart;
}

List<Function> outroSequences = [introOutroSequence1];
List<String> introOutroSequence1() {
  List<String> scriptPart = [
    "one_second_break",
    "narrator_navigation_phrases_18", //You just listened to the full conversation.",
    "narrator_navigation_phrases_19", //Now, let's go through the dialog
    "one_second_break"
  ];
  return scriptPart;
}

List<Function> sentenceSequences = [sentenceSequence1];
List<String> sentenceSequence1(String native, String target, String narratorExplanation, List<String> narratorFunFact, {bool isFirstSentence = false}) {
  String firstPhrase = isFirstSentence ? "narrator_navigation_phrases_20" : "narrator_navigation_phrases_21";
  List<String> scriptPart = [
    firstPhrase, //For now just listen
    "one_second_break",
    target,
    narratorExplanation,
    "narrator_navigation_phrases_22", // Just listen
    "one_second_break",
    target,
    ...narratorFunFact,
    "one_second_break",
  ];
  return scriptPart;
}

List<Function> activeRecallSequences = [activeRecallSequence1];
List<String> activeRecallSequence1(String native, String target) {
  List<String> scriptPart = [
    "narrator_navigation_phrases_8_0", // do you remember how to say...
    "one_second_break",
    native,
    '\$$target',
    "five_second_break",
    target,
    '\$$target',
    "five_second_break",
    target,
    '\$$target',
    "five_second_break",
  ];
  return scriptPart;
}

List<String> activeRecallSequence1Less(String native, String target, RecallType recallType) {
  String narratorPhrase;
  if (recallType == RecallType.overdueWord) {
    final random = Random();
    final int randomIndex = random.nextInt(3);
    final List<String> phrases = [
      "narrator_navigation_phrases_1_0",
      "narrator_navigation_phrases_5",
      "narrator_navigation_phrases_3_0"
    ]; //"reflect on the vocabulary previously learned how do you say" - "to refresh our memory what was the word for" - "before we dive into new material please repeat the phrase for"
    narratorPhrase = phrases[randomIndex];
  } else if (recallType == RecallType.thisConversation) {
    final random = Random();
    final int randomIndex = random.nextInt(3);
    final List<String> phrases = ["narrator_navigation_phrases_8_0", "narrator_navigation_phrases_4_0", "narrator_navigation_phrases_15"]; //"do you remember how to say..." - "how do you say" - "now try to say"
    narratorPhrase = phrases[randomIndex];
  } else {
    print("Error: Invalid recall type");
    narratorPhrase = "narrator_navigation_phrases_8_0"; // Default to overdueWord
  }
  List<String> scriptPart = [
    narratorPhrase,
    "one_second_break",
    native,
    '\$$target',
    "five_second_break",
    target,
    '\$$target',
    "five_second_break",
  ];
  return scriptPart;
}

List<Function> chunkSequences = [chunkSequence1];
List<String> chunkSequence1(List<String> narratorTranslationsChunk, String nativeLanguage, String targetLanguage, List<Map<String, dynamic>> wordKeys, int chunkNumber) {
  List<String> allWordsRepetitions = words2Reps(wordKeys);
  //List<String> chunkSpaced = spacedWordsFixElevenlabsLonelyWords(wordKeys);
  String firstPhrase = chunkNumber == 0 ? "narrator_navigation_phrases_17" : "narrator_navigation_phrases_23";
  List<String> scriptPart = [
    firstPhrase,
    "narrator_navigation_phrases_22", // Just listen
    "one_second_break",
    targetLanguage,
    "one_second_break",
    ...allWordsRepetitions,
    "narrator_navigation_phrases_15", // Now try to say..
    "one_second_break",
    nativeLanguage,
    '\$$targetLanguage',
    "five_second_break",
    //...chunkSpaced,
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
    "narrator_repetition_phrases_25", // Pay attention to the pronunciation and try saying it just like that.
    "one_second_break",
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
    ...narratorTranslationsChunk,
    "narrator_repetition_phrases_4", //Listen and repeat
    "one_second_break",
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break"
  ];
  return scriptPart;
}

List<String> chunkSequence1Less(List<String> narratorTranslationsChunk, String nativeLanguage, String targetLanguage, List<Map<String, dynamic>> wordKeys, int chunkNumber) {
  List<String> allWordsRepetitions = words2RepsLess(wordKeys);
  //List<String> chunkSpaced = spacedWordsFixElevenlabsLonelyWords(wordKeys);
  String firstPhrase = chunkNumber == 0 ? "narrator_navigation_phrases_17" : "narrator_navigation_phrases_23";
  List<String> scriptPart = [
    firstPhrase,
    "narrator_navigation_phrases_22", // Just listen
    "one_second_break",
    targetLanguage,
    "one_second_break",
    ...allWordsRepetitions,
    "narrator_navigation_phrases_15", // Now try to say..
    "one_second_break",
    nativeLanguage,
    '\$$targetLanguage',
    "five_second_break",
    //...chunkSpaced,
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
    "narrator_repetition_phrases_25", // Pay attention to the pronunciation and try saying it just like that.
    "one_second_break",
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
    ...narratorTranslationsChunk,
    "narrator_repetition_phrases_4", //Listen and repeat
    "one_second_break",
    targetLanguage,
    '\$$targetLanguage',
    "five_second_break",
  ];
  return scriptPart;
}

List<String> words2Reps(List<Map<String, dynamic>> wordKeys) {
  List<String> scriptPart = [];
  for (int i = 0; i < wordKeys.length; i++) {
    scriptPart.addAll(wordKeys[i]["narrator_translation_keys"]);
    if (i == 0) {
      scriptPart.add("one_second_break");
      scriptPart.add("narrator_repetition_phrases_4"); // Listen and repeat
      scriptPart.add("one_second_break");
    }
    String word = wordKeys[i]["word_key"];
    scriptPart.add(word);
    scriptPart.add('\$$word');
    scriptPart.add("five_second_break");
    scriptPart.add(word);
    scriptPart.add('\$$word');
    scriptPart.add("five_second_break");
  }
  return scriptPart;
}

List<String> words2RepsLess(List<Map<String, dynamic>> wordKeys) {
  List<String> scriptPart = [];
  for (int i = 0; i < wordKeys.length; i++) {
    scriptPart.addAll(wordKeys[i]["narrator_translation_keys"]);
    if (i == 0) {
      scriptPart.add("one_second_break");
      scriptPart.add("narrator_repetition_phrases_4"); // Listen and repeat
      scriptPart.add("one_second_break");
    }
    String word = wordKeys[i]["word_key"];
    scriptPart.add(word);
    scriptPart.add('\$$word');
    scriptPart.add("five_second_break");
  }
  return scriptPart;
}

List<String> spacedWords(List<Map<String, dynamic>> wordKeys) {
  List<String> scriptPart = [];
  for (int i = 0; i < wordKeys.length; i++) {
    String word = wordKeys[i]["word_key"];
    scriptPart.add(word);
    scriptPart.add('\$$word');
    scriptPart.add("one_second_break");
  }
  return scriptPart;
}
