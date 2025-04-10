import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'script_sequences.dart' as sequences;
import 'constants.dart';
import 'script_generator_to_urls.dart' show constructUrl;
import 'package:fsrs/fsrs.dart' as fsrs;
import 'spaced_repetition_fsrs.dart' show WordCard;
import '../screens/audio_player_s_utils.dart' show accessBigJson;

Future<Map<String, DocumentReference>> ensureFirestoreWords(String userId, String targetLanguage, String category, List<dynamic> words) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category);
  Map<String, DocumentReference> wordDocRefs = {};

  for (var word in words) {
    word = word.toLowerCase().trim();
    final docSnap = await docRef.collection(category).doc(word).get();
    wordDocRefs[word] = docRef.collection(category).doc(word);
    if (!docSnap.exists) {
      WordCard newCard = WordCard(
        word: word,
        due: DateTime.now(),
        lastReview: DateTime.now(),
        stability: 0,
        difficulty: 0,
        elapsedDays: 0,
        scheduledDays: 0,
        reps: 0,
        lapses: 0,
        state: fsrs.State.newState,
      );
      await docRef.collection(category).doc(word).set(newCard.toFirestore());
    }
  }
  return wordDocRefs;
}

Future<List<String>> getOverdueWords(String userId, String targetLanguage, String category) async {
  final collectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category);

  final nowString = DateTime.now().toIso8601String();
  final querySnapshot = await collectionRef.where('due', isLessThanOrEqualTo: nowString).get();

  // Return just the list of word IDs (the document IDs).
  return querySnapshot.docs.map((doc) => doc.id).toList();
}

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

String formConversationAudioUrl(String documentId, String fileName) {
  return "https://storage.googleapis.com/conversations_audio_files/"
      "$documentId/$fileName.mp3";
}

Future<List<DocumentReference>> getOverdueWordsRefs(String userId, String targetLanguage, String category) async {
  final collectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category);

  final nowString = DateTime.now().toIso8601String();
  final querySnapshot = await collectionRef.where('due', isLessThanOrEqualTo: nowString).limit(5).get();

  return querySnapshot.docs.map((doc) => doc.reference).toList();
}

Future<Map<String, dynamic>?> getAudioUrlsForWord(DocumentReference docRef) async {
  final docSnapshot = await docRef.get();

  if (!docSnapshot.exists) {
    return null;
  }

  final data = docSnapshot.data() as Map<String, dynamic>;

  return data;
}

Future<Map<String, dynamic>> parseAndCreateScript(
  Map<String, dynamic> bigJson,
  List<dynamic> wordsToRepeat,
  List<dynamic> dialogue,
  ValueNotifier<RepetitionMode> repetitionMode,
  String userId,
  String documentId,
  String targetLanguage,
  String nativeLanguage,
  String category,
) async {
  Map<String, dynamic> bigJsonMap = bigJson;
  List<dynamic> bigJsonList = bigJson["dialogue"] as List<dynamic>;
  Map<String, DocumentReference> overdueWordsUsed = {};

  overdueWordsUsed = await ensureFirestoreWords(userId, targetLanguage, category, wordsToRepeat);

  final overdueList = await getOverdueWords(userId, targetLanguage, category);
  final Set<String> wordsToRepeatSet = wordsToRepeat.cast<String>().toSet();
  overdueList.removeWhere((word) => wordsToRepeatSet.contains(word));

  List<String> script = createFirstScript(dialogue);

  for (int i = 0; i < bigJsonList.length; i++) {
    if ((bigJsonList[i] as Map).isNotEmpty) {
      String nativeSentence = "dialogue_${i}_native_language";
      String targetSentence = "dialogue_${i}_target_language";

      String narratorExplanation = "dialogue_${i}_narrator_explanation";
      String narratorFunFactText = bigJsonList[i]["narrator_fun_fact"] ?? "";

      // Extract enclosed text
      List<Map<String, dynamic>> classifiedText = extractAndClassifyEnclosedWords(narratorFunFactText);
      List<String> narratorFunFact = [];
      for (int index = 0; index < classifiedText.length; index++) {
        String narratorFunFactChunks = "dialogue_${i}_narrator_fun_fact_$index";
        narratorFunFact.add(narratorFunFactChunks);
      }

      // Construct sentence-level sequence
      List<String> sentenceSequence = sequences.sentenceSequence1(
        nativeSentence,
        targetSentence,
        narratorExplanation,
        narratorFunFact,
        isFirstSentence: i == 0,
      );
      script.addAll(sentenceSequence);

      // Check if any words to repeat appear in this entire sentence
      bool sentenceHasTargetWords = wordsToRepeat.any((element) => bigJsonList[i]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));

      if (sentenceHasTargetWords) {
        // Process each 'split_sentence' item
        for (int j = 0; j < bigJsonList[i]["split_sentence"].length; j++) {
          bool splitHasTargetWords =
              wordsToRepeat.any((element) => bigJsonList[i]["split_sentence"][j]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));

          if (splitHasTargetWords) {
            // 8f. Check if any word in this chunk is overdue
            bool chunkIsOverdue = overdueList.any((overdueWord) => bigJsonList[i]["split_sentence"][j]["target_language"].toString().toLowerCase().contains(overdueWord.toLowerCase()));
            // Insert narrator phrase if overdue
            if (chunkIsOverdue) {
              bool usePhraseEightZero = Random().nextBool();
              script.add(usePhraseEightZero ? "narrator_navigation_phrases_8_0" : "narrator_navigation_phrases_5");
            }

            // Build chunk-level narration
            String text = bigJsonList[i]["split_sentence"][j]["narrator_translation"];
            List<Map<String, dynamic>> classifiedText1 = extractAndClassifyEnclosedWords(text);
            List<String> narratorTranslationsChunk = [];
            for (int index = 0; index < classifiedText1.length; index++) {
              String narratorTranslation = "dialogue_${i}_split_sentence_${j}_narrator_translation_$index";
              narratorTranslationsChunk.add(narratorTranslation);
              narratorTranslationsChunk.add("one_second_break");
            }

            String splitNative = "dialogue_${i}_split_sentence_${j}_native_language";
            String splitTarget = "dialogue_${i}_split_sentence_${j}_target_language";

            // Word objects for chunkSequence
            List<Map<String, dynamic>> wordObjects = [];
            for (int index = 0; index < bigJsonList[i]["split_sentence"][j]['words'].length; index++) {
              bool wordIsTarget = wordsToRepeat
                  .any((element) => bigJsonList[i]["split_sentence"][j]["words"][index]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));
              if (wordIsTarget) {
                String wordFile = "dialogue_${i}_split_sentence_${j}_words_${index}_target_language";

                String text = bigJsonList[i]["split_sentence"][j]['words'][index]["narrator_translation"];
                List<Map<String, dynamic>> classifiedText2 = extractAndClassifyEnclosedWords(text);
                List<String> narratorTranslations = [];
                for (int index2 = 0; index2 < classifiedText2.length; index2++) {
                  String narratorTranslation = "dialogue_${i}_split_sentence_${j}_words_${index}_narrator_translation_$index2";
                  narratorTranslations.add(narratorTranslation);
                }

                wordObjects.add({
                  "word": wordFile,
                  "translation": narratorTranslations,
                });
              }
            }
            // Insert the chunk sequence with normal or reduced repetition
            if (repetitionMode.value == RepetitionMode.normal) {
              List<String> chunkSequence = sequences.chunkSequence1(
                narratorTranslationsChunk,
                splitNative,
                splitTarget,
                wordObjects,
                j,
              );
              script.addAll(chunkSequence);
            } else {
              // repetitionMode.value == RepetitionMode.less
              List<String> chunkSequence = sequences.chunkSequence1Less(
                narratorTranslationsChunk,
                splitNative,
                splitTarget,
                wordObjects,
                j,
              );
              script.addAll(chunkSequence);
            }

            // Save audio URLs for word to Firestore
            for (var wordObj in wordObjects) {
              print("wordObj: $wordObj");
              final targetScript = 'dialogue_${i}_split_sentence_${j}_target_language';
              final nativeScript = 'dialogue_${i}_split_sentence_${j}_native_language';
              // final targetChunk = bigJsonList[i]["split_sentence"][j]["target_language"];
              // final nativeChunk = bigJsonList[i]["split_sentence"][j]["native_language"];
              final nativeChunkUrl = await constructUrl(nativeScript, documentId, nativeLanguage, userId);
              final targetChunkUrl = await constructUrl(targetScript, documentId, targetLanguage, userId);

              String word = accessBigJson(bigJsonMap, wordObj["word"]);
              word = word.toLowerCase().trim().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
              // match the word in the words_to_repeat list even if it matches partly and if it is in the list, assign word to the word in the list
              if (wordsToRepeat.any((element) => word.contains(element))) {
                word = wordsToRepeat.firstWhere((element) => word.contains(element));
                _appendRepetitionUrlsToWordDoc(userId, targetLanguage, word, category, {
                  "native_chunk": nativeChunkUrl,
                  "target_chunk": targetChunkUrl,
                });
              }
            }
          }
        }
      }

      if (i == dialogue.length - 1) {
        Random random = Random();
        int randomNumber = random.nextInt(5);
        script.add("narrator_closing_phrases_$randomNumber");
      }
    }
  }
  final overdueWordDocRefs = await getOverdueWordsRefs(userId, targetLanguage, category);

  int overdueWordsToUseLength = overdueWordDocRefs.length;
  int insertOverdueEvery = 0;
  if (overdueWordsToUseLength > 0) {
    insertOverdueEvery = (script.length / overdueWordsToUseLength).round();
  }

  final overdueSequences = <List<String>>[];
  for (var docRef in overdueWordDocRefs) {
    print('constructing overdue sequence');
    final wordUrls = await getAudioUrlsForWord(docRef);
    if (wordUrls != null && wordUrls['audio_urls'] != null && wordUrls['audio_urls']['native_chunk'] != null && wordUrls['audio_urls']['target_chunk'] != null) {
      print("WordUrls: $wordUrls");
      overdueWordsUsed.addAll({wordUrls['word']: docRef});
      List<String> overdueChunkSequence = sequences.activeRecallSequence1Less(
        wordUrls['audio_urls']['native_chunk'],
        wordUrls['audio_urls']['target_chunk'],
      );
      overdueSequences.add(overdueChunkSequence.toList());
    }
  }
  for (int i = insertOverdueEvery; i < script.length && overdueSequences.isNotEmpty; i++) {
    if (i % insertOverdueEvery == 0) {
      if (i >= script.length) {
        script.addAll(overdueSequences.removeAt(0));
      } else {
        script.insertAll(i, overdueSequences.removeAt(0));
      }
    }
  }
  while (overdueSequences.isNotEmpty) {
    script.addAll(overdueSequences.removeAt(0));
  }

  final Set<String> overdueSet = overdueList.toSet();
  final List<String> combinedWordsList = overdueSet.union(wordsToRepeatSet).toList();
  Future<List<fsrs.Card>> getAllCards(List<String> words) async {
    List<fsrs.Card> cards = [];
    for (String word in words) {
      final collectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category).doc(word);

      // Get the document snapshot
      final docSnapshot = await collectionRef.get();

      // Check if document exists and has data
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          fsrs.Card card = WordCard.fromFirestore(data);
          cards.add(card);
        }
      }
    }
    return cards;
  }

  List<fsrs.Card> cardsCollection = await getAllCards(combinedWordsList);
  var f = fsrs.FSRS();
  fsrs.Card firstCard = cardsCollection[0];
  var now = DateTime.now();
  print("Now: $now");
  var cardPossibleSchedulings = f.repeat(firstCard, now);
  print("Due 1: ${firstCard.due}, State 1: ${firstCard.state}");
  firstCard = cardPossibleSchedulings[fsrs.Rating.easy]!.card;
  print("Due 2: ${firstCard.due}, State 2: ${firstCard.state}");

  return {"script": script, "overdueWordsUsed": overdueWordsUsed};
}

Future<void> _appendRepetitionUrlsToWordDoc(
  String userId,
  String targetLanguage,
  String word,
  String category,
  Map<String, dynamic> urlsMap,
) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category).doc(word);

  await docRef.set(
    {
      'audio_urls': urlsMap,
    },
    SetOptions(merge: true),
  );
}
