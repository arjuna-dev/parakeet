List<Function> introSequences = [];

List<String> introSequence1() {
  List<String> scriptPart = [
    "narrator_opening_phrases_5_0",
    "narrator_opening_phrases_5_1",
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
  ];
  return scriptPart;
}

List<String> introSequence3() {
  List<String> scriptPart = [
    "narrator_opening_phrases_0",
    "title",
    "narrator_opening_phrases_7", //Let's first listen to the whole conversation
  ];
  return scriptPart;
}

List<String> introSequence4() {
  List<String> scriptPart = [
    "narrator_opening_phrases_2",
    "narrator_opening_phrases_5_1",
    "title",
    "narrator_opening_phrases_8", //Now just listen to the whole conversation
  ];
  return scriptPart;
}

void populateIntroSequences() {
  introSequences.add(introSequence1);
  introSequences.add(introSequence3);
  introSequences.add(introSequence4);
}

List<Function> outroSequences = [];
List<String> introOutroSequence1() {
  List<String> scriptPart = [
    "one_second_break",
    "narrator_navigation_phrases_18", //You just listened to the full conversation.",
    "narrator_navigation_phrases_19", //Now, let's go through the dialog
    "one_second_break"
  ];
  return scriptPart;
}

void populateOutroSequences() {
  outroSequences.add(introOutroSequence1);
}

List<Function> sentenceSequences = [];
List<String> sentenceSequence1(String native, String target,
    String narratorExplanation, String narratorFunFact,
    {bool isFirstSentence = false}) {
  String firstPhrase = isFirstSentence
      ? "narrator_navigation_phrases_20"
      : "narrator_navigation_phrases_21";
  List<String> scriptPart = [
    firstPhrase, //For now just listen
    "one_second_break",
    target,
    "one_second_break",
    narratorExplanation,
    "narrator_navigation_phrases_22", // Just listen
    target,
    "one_second_break",
    narratorFunFact,
    "one_second_break",
  ];
  return scriptPart;
}

void populateSentenceSequences() {
  sentenceSequences.add(sentenceSequence1);
}

List<Function> activeRecallSequences = [];
List<String> activeRecallSequence1(String native, String target) {
  List<String> scriptPart = [
    "narrator_navigation_phrases_8_0", // do you remember how to say...
    native,
    "five_second_break",
    target,
    "five_second_break",
    target,
    "five_second_break",
  ];
  return scriptPart;
}

void populateactiveRecallSequences() {
  activeRecallSequences.add(activeRecallSequence1);
}

List<Function> chunkSequences = [];
List<String> chunkSequence1(
    List<String> narratorFunFact,
    String nativeLanguage,
    String targetLanguage,
    List<Map<String, dynamic>> wordObjects,
    int chunkNumber) {
  List<String> wordsReps = words2RepsFixElevenlabsLonelyWords(wordObjects);
  List<String> wordsSpaced = spacedWordsFixElevenlabsLonelyWords(wordObjects);
  String firstPhrase = chunkNumber == 0
      ? "narrator_navigation_phrases_17"
      : "narrator_navigation_phrases_23";
  List<String> scriptPart = [
    firstPhrase,
    "narrator_navigation_phrases_22", // Just listen
    targetLanguage,
    "one_second_break",
    ...wordsReps,
    "narrator_navigation_phrases_15", // Now try to say..
    nativeLanguage,
    "five_second_break",
    targetLanguage,
    "five_second_break",
    "narrator_repetition_phrases_25", // Pay attention to the pronunciation and try saying it just like that.
    ...wordsSpaced,
    "five_second_break",
    ...narratorFunFact,
    "narrator_repetition_phrases_4", //Listen and repeat
    targetLanguage,
    "five_second_break",
    targetLanguage,
    "five_second_break"
  ];
  return scriptPart;
}

void populateChunkSequences() {
  chunkSequences.add(chunkSequence1);
}

List<String> words2RepsFixElevenlabsLonelyWords(
    List<Map<String, dynamic>> wordObjects) {
  List<String> scriptPart = [];
  for (int i = 0; i < wordObjects.length; i++) {
    scriptPart.addAll(wordObjects[i]["translation"]);
    if (i == 0) {
      scriptPart.add("narrator_repetition_phrases_4"); // Listen and repeat
    }
    scriptPart.add(wordObjects[i]["translation"][0]);
    scriptPart.add("five_second_break");
    scriptPart.add(wordObjects[i]["translation"][0]);
    scriptPart.add("five_second_break");
  }
  return scriptPart;
}

List<String> spacedWordsFixElevenlabsLonelyWords(
    List<Map<String, dynamic>> wordObjects) {
  List<String> scriptPart = [];
  for (int i = 0; i < wordObjects.length; i++) {
    scriptPart.add(wordObjects[i]["translation"][0]);
    scriptPart.add("one_second_break");
  }
  return scriptPart;
}
