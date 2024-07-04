import 'dart:math';
import 'script_sequences.dart' as sequences;

List<Map<String, dynamic>> extractAndClassifyEnclosedWords(String inputString) {
  List<String> parts = inputString.split('||');

  List<Map<String, dynamic>> result = [];

  bool isEnclosed = false;

  for (var part in parts) {
    if (part.isNotEmpty) {
      result.add({'text': part, 'enclosed': isEnclosed});
    }
    isEnclosed = !isEnclosed;
  }

  return result;
}

List<String> createFirstScript(List<dynamic> data) {
  List<String> script = [];
  int randomI = Random().nextInt(sequences.introSequences.length);
  List<String> introSequence = sequences.introSequences[randomI]();
  script.addAll(introSequence);
  for (int i = 0; i < data.length; i++) {
    script.add("dialogue_${i}_target_language");
  }

  script.addAll(sequences.introOutroSequence1());

  return script;
}

List<String> parseAndCreateScript(
    List<dynamic> data, List<dynamic> wordsToRepeat, List<dynamic> dialogue) {
  List<String> script = [];

  script = createFirstScript(dialogue);
  List<dynamic> wordsToRepeatWithoutPunctation = wordsToRepeat.map((word) {
    return word.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
  }).toList();

  //List<int> sentenceNumberExcludeList = [];
  // Process each turn in the dialogue
  for (int i = 0; i < data.length; i++) {
    if ((data[i] as Map).isNotEmpty) {
      String nativeSentence = "dialogue_${i}_native_language";
      String targetSentence = "dialogue_${i}_target_language";

      String narratorExplanation = "dialogue_${i}_narrator_explanation";
      String narratorFunFactText = data[i]["narrator_fun_fact"];

      // Classify and process the text into parts enclosed by || (target_language text)
      List<Map<String, dynamic>> classifiedText =
          extractAndClassifyEnclosedWords(narratorFunFactText);
      List<String> narratorFunFact = [];
      for (int index = 0; index < classifiedText.length; index++) {
        String narratorFunFactChunks = "dialogue_${i}_narrator_fun_fact_$index";
        narratorFunFact.add(narratorFunFactChunks);
        narratorFunFact.add("one_second_break");
      }

      List<String> sentenceSequence = sequences.sentenceSequence1(
          nativeSentence, targetSentence, narratorExplanation, narratorFunFact,
          isFirstSentence: i == 0);
      script.addAll(sentenceSequence);

      List<int> chunkNumberExcludeList = [];

      // Process words in the sentence
      if (wordsToRepeatWithoutPunctation.any((element) => data[i]
              ["target_language"]
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
          .split(' ')
          .contains(element))) {
        // Process split_sentence items
        for (int j = 0; j < data[i]["split_sentence"].length; j++) {
          // Check if user wants to repeat the split sentence (only if at least one word they want is there)
          if (wordsToRepeatWithoutPunctation.any((element) => data[i]
                  ["split_sentence"][j]["target_language"]
              .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
              .split(' ')
              .contains(element))) {
            String text = data[i]["split_sentence"][j]["narrator_translation"];

            // Classify and process the text into parts enclosed by || (target_language text)
            List<Map<String, dynamic>> classifiedText1 =
                extractAndClassifyEnclosedWords(text);
            List<String> narratorTranslationsChunk = [];
            for (int index = 0; index < classifiedText1.length; index++) {
              String narratorTranslation =
                  "dialogue_${i}_split_sentence_${j}_narrator_translation_$index";
              narratorTranslationsChunk.add(narratorTranslation);
              narratorTranslationsChunk.add("one_second_break");
            }

            String splitNative =
                "dialogue_${i}_split_sentence_${j}_native_language";
            String splitTarget =
                "dialogue_${i}_split_sentence_${j}_target_language";

            List<Map<String, dynamic>> wordObjects = [];
            for (int index = 0;
                index < data[i]["split_sentence"][j]['words'].length;
                index++) {
              if (wordsToRepeatWithoutPunctation.contains(data[i]
                  ["split_sentence"][j]['words'][index]["target_language"])) {
                String wordFile =
                    "dialogue_${i}_split_sentence_${j}_words_${index}_target_language";
                String text = data[i]["split_sentence"][j]['words'][index]
                    ["narrator_translation"];

                // Classify and process the text into parts enclosed by || (target_language text)
                List<Map<String, dynamic>> classifiedText2 =
                    extractAndClassifyEnclosedWords(text);
                List<String> narratorTranslations = [];
                for (int index2 = 0;
                    index2 < classifiedText2.length;
                    index2++) {
                  String narratorTranslation =
                      "dialogue_${i}_split_sentence_${j}_words_${index}_narrator_translation_$index2";
                  narratorTranslations.add(narratorTranslation);
                }

                wordObjects.add(
                    {"word": wordFile, "translation": narratorTranslations});
              }
            }

            List<String> chunkSequence = sequences.chunkSequence1(
                narratorTranslationsChunk,
                splitNative,
                splitTarget,
                wordObjects,
                j);
            script.addAll(chunkSequence);
          } else {
            chunkNumberExcludeList.add(j);
          }
        }
        // Active recall sequence
        // if (i != 0) {
        //   if (chunkNumberExcludeList.length != data[i]["split_sentence"].length) {
        //     List<int> validSentences = List<int>.generate(i + 1, (index) => index)
        //       ..removeWhere(
        //           (element) => sentenceNumberExcludeList.contains(element));
        //     if (validSentences.isEmpty) {
        //       break;
        //     }
        //     int randomSentenceI =
        //         validSentences[Random().nextInt(validSentences.length)];
        //     int numberOfChunks =
        //         data[randomSentenceI]["split_sentence"].length - 1;
        //     List<int> validChunks = List<int>.generate(numberOfChunks, (i) => i)
        //       ..removeWhere(
        //           (element) => chunkNumberExcludeList.contains(element));
        //     if (validChunks.isEmpty) {
        //       break;
        //     }
        //     int randomChunkI = validChunks[Random().nextInt(validChunks.length)];
        //     String target =
        //         "dialogue_${randomSentenceI}_split_sentence_${randomChunkI}_target_language";
        //     String native =
        //         "dialogue_${randomSentenceI}_split_sentence_${randomChunkI}_native_language";
        //     List<String> activeRecallSequence =
        //         sequences.activeRecallSequence1(native, target);
        //     script.addAll(activeRecallSequence);
        //   } else {
        //     sentenceNumberExcludeList.add(i);
        //   }
        // } else if (chunkNumberExcludeList.length ==
        //     data[i]["split_sentence"].length) {
        //   sentenceNumberExcludeList.add(i);
        // }
      }
      if (i == dialogue.length - 1) {
        Random random = Random();
        int randomNumber = random.nextInt(5);
        script.add("narrator_closing_phrases_$randomNumber");
      }
    }
  }
  // Uncomment to print full script:
  // for (int i = 0; i < script.length; i++) {
  //   print(script[i]);
  // }
  return script;
}
