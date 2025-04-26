import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'script_sequences.dart' as sequences;
import 'constants.dart';
import 'script_generator_to_urls.dart' show constructUrl;
import 'package:fsrs/fsrs.dart' as fsrs;
import 'spaced_repetition_fsrs.dart' show WordCard;
import '../screens/audio_player_s_utils.dart' show accessBigJson;

Future<Map<String, DocumentReference>> getSelectedWordCardDocRefs(String userId, String targetLanguage, String category, List<dynamic> words) async {
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

Future<List<DocumentReference>> get5MostOverdueWordsRefs(String userId, String targetLanguage, List<dynamic> selectedWords) async {
  final categoriesRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words');
  final categoriesSnapshot = await categoriesRef.get();

  List<Map<String, dynamic>> overdueWordsWithDates = [];
  final now = DateTime.now();

  // Loop through all categories
  for (var categoryDoc in categoriesSnapshot.docs) {
    final category = categoryDoc.id;
    final wordsCollectionRef = categoriesRef.doc(category).collection(category);

    // Query overdue words in a category
    final querySnapshot = await wordsCollectionRef.where('due', isLessThanOrEqualTo: now.toIso8601String()).get();

    // Add each overdue word with its due date and reference
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      // Add only if the word is not in the selected words list
      if (data.containsKey('due') && data.containsKey('word') && !selectedWords.contains(data['word'])) {
        try {
          final dueDate = DateTime.parse(data['due']);
          final daysOverdue = now.difference(dueDate).inDays;

          overdueWordsWithDates.add({
            'reference': doc.reference,
            'daysOverdue': daysOverdue,
          });
        } catch (e) {
          // Skip if date parsing fails
          print('Error parsing date for word ${doc.id}: $e');
        }
      }
    }
  }

  // Sort by days overdue (descending) and take the top 5
  overdueWordsWithDates.sort((a, b) => b['daysOverdue'].compareTo(a['daysOverdue']));

  // Return only the references of the 5 most overdue words
  return overdueWordsWithDates.take(5).map((item) => item['reference'] as DocumentReference).toList();
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

List<String> buildKeysForNarratorTranslation(String narratorText, int i, int j) {
  List<Map<String, dynamic>> classifiedText1 = extractAndClassifyEnclosedWords(narratorText);
  List<String> narratorTranslationsChunk = [];
  for (int index = 0; index < classifiedText1.length; index++) {
    String narratorTranslation = "dialogue_${i}_split_sentence_${j}_narrator_translation_$index";
    narratorTranslationsChunk.add(narratorTranslation);
    narratorTranslationsChunk.add("one_second_break");
  }
  return narratorTranslationsChunk;
}

List<Map<String, dynamic>> getWordKeys(List splitSentenceWords, int i, int j, List<dynamic> selectedWords) {
  List<Map<String, dynamic>> wordKeys = [];
  for (int index = 0; index < splitSentenceWords.length; index++) {
    bool isSelectedWord = selectedWords.any((element) => splitSentenceWords[index]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));
    if (isSelectedWord) {
      String wordKey = "dialogue_${i}_split_sentence_${j}_words_${index}_target_language";

      String text = splitSentenceWords[index]["narrator_translation"];
      List<Map<String, dynamic>> classifiedText2 = extractAndClassifyEnclosedWords(text);
      List<String> narratorTranslations = [];
      for (int index2 = 0; index2 < classifiedText2.length; index2++) {
        String narratorTranslation = "dialogue_${i}_split_sentence_${j}_words_${index}_narrator_translation_$index2";
        narratorTranslations.add(narratorTranslation);
      }

      wordKeys.add({
        "word_key": wordKey,
        "narrator_translation_keys": narratorTranslations,
      });
    }
  }
  return wordKeys;
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

Future<Map<String, dynamic>?> getDocumentDataFromRef(DocumentReference docRef) async {
  final docSnapshot = await docRef.get();

  if (!docSnapshot.exists) {
    return null;
  }

  final data = docSnapshot.data() as Map<String, dynamic>;

  return data;
}

Future<Map<String, dynamic>> parseAndCreateScript(
  Map<String, dynamic> bigJson,
  List<dynamic> selectedWords,
  List<dynamic> dialogue,
  ValueNotifier<RepetitionMode> repetitionMode,
  String userId,
  String documentId,
  String targetLanguage,
  String nativeLanguage,
  String category,
) async {
  print("Parsing and creating script 🫡");
  Map<String, dynamic> bigJsonMap = bigJson;
  List<dynamic> bigJsonList = bigJson["dialogue"] as List<dynamic>;

  List<String> script = createFirstScript(dialogue);

  final List<DocumentReference> overdueListRefs = await get5MostOverdueWordsRefs(userId, targetLanguage, selectedWords);
  final List<DocumentSnapshot<Object?>> overdueListDocs = await Future.wait(overdueListRefs.map((ref) => ref.get()));
  // final List<String> overdueWordsList = overdueListDocs.map((doc) => (doc.data() as Map<String, dynamic>)['word'] as String).toList();

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
      bool sentenceHasSelectedWords = selectedWords.any((element) => bigJsonList[i]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));

      if (sentenceHasSelectedWords) {
        // Process each 'split_sentence' item
        for (int j = 0; j < bigJsonList[i]["split_sentence"].length; j++) {
          bool splitHasSelectedWords =
              selectedWords.any((element) => bigJsonList[i]["split_sentence"][j]["target_language"].replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').toLowerCase().split(' ').contains(element));

          print("splity:  ${bigJsonList[i]["split_sentence"][j]["target_language"]}");

          if (splitHasSelectedWords) {
            // Build chunk-level narration
            List<String> narratorTranslationsChunk = buildKeysForNarratorTranslation(bigJsonList[i]["split_sentence"][j]["narrator_translation"], i, j);

            String splitNative = "dialogue_${i}_split_sentence_${j}_native_language";
            String splitTarget = "dialogue_${i}_split_sentence_${j}_target_language";

            // Get the word keys for the current split sentence
            List<Map<String, dynamic>> wordKeys = getWordKeys(bigJsonList[i]["split_sentence"][j]['words'], i, j, selectedWords);

            // Insert the chunk sequence with normal or reduced repetition
            if (repetitionMode.value == RepetitionMode.normal) {
              List<String> chunkSequence = sequences.chunkSequence1(
                narratorTranslationsChunk,
                splitNative,
                splitTarget,
                wordKeys,
                j,
              );
              script.addAll(chunkSequence);
            } else {
              // repetitionMode.value == RepetitionMode.less
              List<String> chunkSequence = sequences.chunkSequence1Less(
                narratorTranslationsChunk,
                splitNative,
                splitTarget,
                wordKeys,
                j,
              );
              script.addAll(chunkSequence);
            }

            print("wordKeys: $wordKeys");

            // Save audio URLs for word to Firestore
            for (var wordKey in wordKeys) {
              final targetChunkKey = 'dialogue_${i}_split_sentence_${j}_target_language';
              final nativeChunkKey = 'dialogue_${i}_split_sentence_${j}_native_language';

              final nativeChunkUrl = await constructUrl(nativeChunkKey, documentId, nativeLanguage, userId);
              final targetChunkUrl = await constructUrl(targetChunkKey, documentId, targetLanguage, userId);

              String word = accessBigJson(bigJsonMap, wordKey["word_key"]);
              word = word.toLowerCase().trim().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
              // match the word in the words_to_repeat list even if it matches partly and if it is in the list, assign word to the word in the list
              if (selectedWords.any((element) => word.contains(element))) {
                print("selectedWords: $selectedWords");
                print("word_1: $word");
                word = selectedWords.firstWhere((element) => word.contains(element));
                print("word_2: $word");
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

  Map<String, DocumentReference> allUsedWordsCards = {};
  allUsedWordsCards = await getSelectedWordCardDocRefs(userId, targetLanguage, category, selectedWords);
  final overdueSequences = <List<String>>[];
  for (var docRef in overdueListRefs) {
    final wordDoc = await getDocumentDataFromRef(docRef);

    if (wordDoc != null && wordDoc['audio_urls'] != null && wordDoc['audio_urls']['native_chunk'] != null && wordDoc['audio_urls']['target_chunk'] != null) {
      allUsedWordsCards.addAll({wordDoc['word']: docRef});
      List<String> overdueChunkSequence = sequences.activeRecallSequence1Less(
        wordDoc['audio_urls']['native_chunk'],
        wordDoc['audio_urls']['target_chunk'],
      );
      overdueSequences.add(overdueChunkSequence.toList());
    }
  }

//   Getting all cards and checking it for debugging

  // Future<List<fsrs.Card>> getAllUsedCardsInCategory(List<String> words) async {
  //   List<fsrs.Card> cards = [];
  //   for (String word in words) {
  //     print("word: $word");
  //     final collectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category).doc(word);
  //     print("collectionRef: $collectionRef");

  //     // Get the document snapshot
  //     final docSnapshot = await collectionRef.get(const GetOptions(source: Source.server));

  //     // Check if document exists and has data
  //     if (docSnapshot.exists) {
  //       final data = docSnapshot.data();
  //       print("doc: $data");
  //       if (data != null) {
  //         fsrs.Card card = WordCard.fromFirestore(data).card;
  //         cards.add(card);
  //       }
  //     }
  //   }
  //   return cards;
  // }

  // final Set<String> overdueSet = overdueWordsList.toSet();
  // final Set<String> selectedWordsSet = selectedWords.cast<String>().toSet();
  // final List<String> combinedWordsList = overdueSet.union(selectedWordsSet).toList();

  // List<fsrs.Card> cardsCollection = await getAllUsedCardsInCategory(combinedWordsList);
  // var f = fsrs.FSRS();
  // fsrs.Card firstCard = cardsCollection[0];
  // var now = DateTime.now();
  // print("Now: $now");
  // var cardPossibleSchedulings = f.repeat(firstCard, now);
  // print("Due 1: ${firstCard.due}, State 1: ${firstCard.state}");
  // firstCard = cardPossibleSchedulings[fsrs.Rating.easy]!.card;
  // print("Due 2: ${firstCard.due}, State 2: ${firstCard.state}");

//   -----------------------------------------

  return {"script": script, "allUsedWordsCards": allUsedWordsCards};
}

Future<void> _appendRepetitionUrlsToWordDoc(
  String userId,
  String targetLanguage,
  String word,
  String category,
  Map<String, dynamic> urlsMap,
) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category).doc(word);

  print("urlsMap: $urlsMap");

  await docRef.set(
    {
      'audio_urls': urlsMap,
    },
    SetOptions(merge: true),
  );
}
