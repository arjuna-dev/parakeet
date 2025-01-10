import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/ad_service.dart';
import 'package:parakeet/services/file_duration_update_service.dart';
import 'package:parakeet/services/update_firestore_service.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:parakeet/utils/script_generator.dart' as script_generator;
import 'package:parakeet/utils/speech_recognition.dart';
import 'package:parakeet/widgets/position_data.dart';
import 'package:parakeet/widgets/dialogue_list.dart';
import 'package:parakeet/widgets/position_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../utils/constants.dart';
import 'package:parakeet/main.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../utils/vosk_recognizer.dart';
import 'package:parakeet/utils/supported_language_codes.dart';
import 'dart:convert';
import 'package:parakeet/services/streak_service.dart';
import 'package:parakeet/widgets/streak_display.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String documentID;
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;

  const AudioPlayerScreen({
    Key? key,
    required this.documentID,
    required this.dialogue,
    required this.userID,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
    required this.generating,
  }) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  UpdateFirestoreService? firestoreService;
  FileDurationUpdate? fileDurationUpdate;
  late AudioPlayer player;
  late ConcatenatingAudioSource playlist;
  late AnalyticsManager analyticsManager;
  // late List<AudioSource> couldNotListenFeedbackAudio;
  late AudioSource audioCue;

  String currentTrack = '';
  String? previousTargetTrack;
  String? targetPhraseToCompareWith;
  String? voiceLanguageCode;
  bool isLanguageSupported = false;
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  int updateNumber = 0;
  bool speechRecognitionActive = false;
  bool? speechRecognitionSupported;
  Map<String, dynamic>? latestSnapshot;
  Map<int, String> filesToCompare = {};
  Map<String, dynamic>? existingBigJson;
  bool hasNicknameAudio = false;
  bool addressByNickname = true;
  bool isLoading = false;
  double _playbackSpeed = 1.0;

  Duration totalDuration = Duration.zero;
  Duration finalTotalDuration = Duration.zero;
  List<Duration> trackDurations = [];
  List<dynamic> script = [];

  SpeechToText speechInstance = SpeechToText();
  String liveTextSpeechToText = '';

  Map<String, dynamic>? audioDurations = {};
  Future<Map<String, dynamic>>? cachedAudioDurations;

  int previousIndex = -1;
  bool _hasPremium = false;
  bool _hasShownInitialAd = false;

  late SpeechToTextUltra speechToTextUltra;

  bool isSliderMoving = false;

  bool _isSkipping = false;

  SpeechService? voskSpeechService;

  final StreakService _streakService = StreakService();
  bool _showStreak = false;

  final ValueNotifier<RepetitionMode> _repetitionsMode = ValueNotifier(RepetitionMode.normal);

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    player.setSpeed(_playbackSpeed);
    playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: []);
    script = script_generator.createFirstScript(widget.dialogue);
    currentTrack = script[0];
    analyticsManager = AnalyticsManager(widget.userID, widget.documentID);
    analyticsManager.loadAnalyticsFromFirebase();
    _listenToPlayerStreams();
    cachedAudioDurations = getAudioDurationsFromNarratorStorage();
    firestoreService = UpdateFirestoreService.getInstance(widget.documentID, widget.generating, updatePlaylist, updateTrackLength, saveSnapshot);
    fileDurationUpdate = FileDurationUpdate.getInstance(widget.documentID, calculateTotalDurationAndUpdateTrackDurations);
    getExistingBigJson();
    updateHasNicknameAudio().then((_) {
      _initPlaylist();
    });
    _loadAddressByNicknamePreference();
    speechToTextUltra = SpeechToTextUltra(
      languageName: widget.targetLanguage,
      ultraCallback: (String liveText, String finalText, bool isListening) {
        // Handle the callback
        print('Live Text: $liveText');
        print('Final Text: $finalText');
        print('Is Listening: $isListening');
        print('speechRecognitionActive: $speechRecognitionActive');
        if (mounted) {
          setState(() {
            liveTextSpeechToText = liveText;
          });
        } else {
          print('State not mounted for liveTextSpeechToText');
        }
      },
    );
    _repetitionsMode.addListener(() {
      updatePlaylistOnTheFly();
    });
    isPlaying.addListener(() async {
      if (isPlaying.value) {
        await _play();
      } else {
        await _pause();
      }
    });
  }

  String? getVoskModelUrl(String languageName) {
    // Get full language code (e.g., "en-US")
    final fullCode = supportedLanguageCodes[languageName];
    if (fullCode == null) {
      return null;
    }

    // Extract base language code (e.g., "en" from "en-US")
    if (fullCode == 'en-US' || fullCode == 'en-GB') {
      return voskModelUrls[fullCode];
    }

    final partialCode = fullCode.split('-')[0].toLowerCase();

    // Return URL if exists, null otherwise
    return voskModelUrls[partialCode];
  }

  Future<void> _initVosk() async {
    VoskFlutterPlugin vosk = VoskFlutterPlugin.instance();
    String? voskModelUrl = getVoskModelUrl(widget.targetLanguage);
    if (voskModelUrl == null) {
      _showLanguageNotSupportedDialog();
      return;
    } else {
      isLanguageSupported = true;
    }
    // String voskModelUrl = getVoskModelUrl(widget.targetLanguage)!;
    Future<String> enSmallModelPath = ModelLoader().loadFromNetwork(voskModelUrl);
    Future<Model> voskModel = vosk.createModel(await enSmallModelPath);

    final recognizer = await vosk.createRecognizer(
      model: await voskModel,
      sampleRate: 16000,
    );
    // For recognizing specific words
    // final recognizerWithGrammar = await vosk.createRecognizer(
    //   model: await voskModel,
    //   sampleRate: sampleRate,
    //   grammar: ['one', 'two', 'three'],
    // );
    // For ultra fast recognition
    // voskSpeechService.onPartial().forEach((partial) {
    //   setState(() {
    //     liveTextSpeechToText = partial;
    //   });
    // });

    voskSpeechService = await vosk.initSpeechService(recognizer);
    print("initSpeechService called");

    voskSpeechService!.onResult().forEach((result) {
      final String resultText = jsonDecode(result)['text'];
      print("result: $resultText");
      setState(() {
        liveTextSpeechToText = resultText;
      });
    });
    await voskSpeechService!.start();
  }

  void initializeSpeechRecognition() async {
    // If device is andoird initialize vosk
    if (!kIsWeb && Platform.isAndroid) {
      await _initVosk();
      return;
    }
    // TODO: Error handling
    // Initialize the speech recognition
    SpeechToText speechRecognition = await speechToTextUltra.startListening();

    // TODO: Error handling
    // Check if the specified language is supported
    isLanguageSupported = await speechToTextUltra.checkIfLanguageSupported(speechRecognition);

    if (!isLanguageSupported) {
      _showLanguageNotSupportedDialog();
      return;
    }
    //_initFeedbackAudioSources();
  }

  updateHasNicknameAudio() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String url = 'https://storage.googleapis.com/user_nicknames/${widget.userID}_1_nickname.mp3?timestamp=$timestamp';
    hasNicknameAudio = await urlExists(
      url,
    );
    if (mounted) {
      setState(() {
        hasNicknameAudio = hasNicknameAudio;
      });
    } else {
      print('State not mounted for hasNicknameAudio');
    }
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userID).get();

    if (mounted) {
      setState(() {
        _hasPremium = userDoc.data()?['premium'] ?? false;
      });
    } else {
      print('State not mounted for _hasPremium');
    }

    if (!_hasPremium) {
      await AdService.loadInterstitialAd();
    }
  }

  void getExistingBigJson() async {
    if (!widget.generating) {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('chatGPT_responses').doc(widget.documentID).collection('all_breakdowns').doc('updatable_big_json');
      final doc = await docRef.get();
      if (doc.exists) {
        existingBigJson = doc.data();
      }
    }
  }

  Future<bool> retryUrlExists(String url, {int retries = 10, Duration delay = const Duration(seconds: 1)}) async {
    for (int i = 1; i <= retries; i++) {
      bool exists = await urlExists(url);
      if (exists) {
        setState(() {
          isLoading = false;
        });
        return true;
      }
      setState(() {
        isLoading = true;
      });
      if (i == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('We\'re having trouble finding an audio file 🧐'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }

      await Future.delayed(delay);
    }
    return false;
  }

  Future<void> _showAudioErrorDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Error'),
          content: const Text('An error occurred while creating the audio 🧐. Check your internet connection and try again!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleFetchingUrlError(int? index) async {
    if (index != null) {
      final currentUrl = (playlist.children[index] as UriAudioSource).uri.toString();
      bool available = await retryUrlExists(currentUrl, retries: 10, delay: const Duration(seconds: 1));
      if (!available) {
        setState(() => isLoading = false);
        await _showAudioErrorDialog(context);
      }
    }
  }

  void _listenToPlayerStreams() {
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (isPlaying.value) {
          analyticsManager.storeAnalytics(widget.documentID, 'completed');
          _handleLessonCompletion();
        }
        _stop();
      }
    });

    player.currentIndexStream.listen((index) async {
      await _handleFetchingUrlError(index);

      print("index: $index");

      // Guard against null index
      if (index == null) {
        print('Warning: Received null index in stream');
        return;
      }

      if (index < script.length) {
        setState(() {
          currentTrack = script[index];
        });
        print('currentTrack: $currentTrack');
        if (speechRecognitionActive) {
          _handleTrackChangeToCompareSpeech(index);
        }
        setState(() {
          previousIndex = index;
        });
      }
    });
  }

  Future<void> _initPlaylist() async {
    List<String> fileUrls = [];
    for (var fileName in script) {
      String url = await _constructUrl(fileName);
      if (url != "") {
        fileUrls.add(url);
      } else {
        print("Empty string URL for $fileName");
      }
    }

    if (fileUrls.isNotEmpty) {
      List<AudioSource> audioSources = fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();
      playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: audioSources);
      await player.setAudioSource(playlist).catchError((error) {
        print("Error setting audio source: $error");
        return null;
      });

      await player.playerStateStream.where((state) => state.processingState == ProcessingState.ready).first;
      isPlaying.value = true;
    } else {
      print("No valid URLs available to initialize the playlist.");
    }
  }

  void buildFilesToCompare(List<dynamic> script) {
    filesToCompare = {};
    int occurrences = 0;
    for (int i = 0; i < script.length; i++) {
      String fileName = script[i];
      if (!fileName.startsWith('\$')) {
        // This file is included in the playlist
        if (fileName == 'five_second_break') {
          // Map the playlistIndex to the phrase
          if (i > 0 && script[i - 1].startsWith('\$')) {
            String fileNameWithDollar = script[i - 1];
            String fileName = fileNameWithDollar.replaceFirst('\$', '');
            setState(() {
              filesToCompare[i - occurrences - 1] = fileName;
            });
            occurrences++;
          } else {
            print('Warning: Expected a \$-prefixed string before five_second_break at index $i');
          }
        }
      }
    }
  }

  void updatePlaylist(snapshot) async {
    try {
      script = script_generator.parseAndCreateScript(snapshot.docs[0].data()["dialogue"] as List<dynamic>, widget.wordsToRepeat, widget.dialogue, _repetitionsMode);
    } catch (e) {
      print("Error parsing and creating script: $e");
      return;
    }

    buildFilesToCompare(script);

    script = script.where((fileName) => !fileName.startsWith('\$')).toList();

    var newScript = List.from(script);
    newScript.removeRange(0, playlist.children.length);

    // Filter out files that start with a '$'
    newScript = newScript.where((fileName) => !fileName.startsWith('\$')).toList();

    List<String> fileUrls = [];
    for (var fileName in newScript) {
      fileUrls.add(await _constructUrl(fileName));
    }

    final newTracks = fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();
    await playlist.addAll(newTracks);
    // if (!widget.generating && !isPlaying.value) {
    // isPlaying.value = true;
    // }

    updateNumber++;
  }

  void updatePlaylistOnTheFly() async {
    bool wasPlaying = isPlaying.value;
    int lastIndexBeforeUpdate = player.currentIndex!;
    if (!widget.generating) {
      isPlaying.value = false;
    }

    if (widget.generating) {
      print("Error: updatePlaylistOnTheFly() called while generating.");
      return;
    }

    if (existingBigJson == null) {
      print("Error: Required JSON data is null.");
      return;
    }

    try {
      script = script_generator.parseAndCreateScript(existingBigJson!["dialogue"] as List<dynamic>, widget.wordsToRepeat, widget.dialogue, _repetitionsMode);
    } catch (e) {
      print("Error parsing and creating script: $e");
      return;
    }

    buildFilesToCompare(script);

    script = script.where((fileName) => !fileName.startsWith('\$')).toList();

    var newScript = List.from(script);

    // Check if lastIndexBeforeUpdate is within the range of newScript
    if (lastIndexBeforeUpdate >= newScript.length) {
      await player.seek(Duration.zero, index: newScript.length - 10);
      _savePlayerPosition();
    }

    // Filter out files that start with a '$'
    newScript = newScript.where((fileName) => !fileName.startsWith('\$')).toList();

    List<String> fileUrls = [];
    for (var fileName in newScript) {
      fileUrls.add(await _constructUrl(fileName));
    }

    final newTracks = fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();

    await playlist.clear();
    await playlist.addAll(newTracks);
    await updateTrackLength();
    if (!widget.generating && wasPlaying) {
      isPlaying.value = true;
    }
  }

  void saveSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      latestSnapshot = snapshot.docs[0].data() as Map<String, dynamic>?;
    }
  }

  Future<void> updateTrackLength() async {
    CollectionReference colRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();
    if (querySnap.docs.isNotEmpty) {
      await calculateTotalDurationAndUpdateTrackDurations(querySnap);
    }
  }

  Future<String> _constructUrl(String fileName) async {
    if (fileName.startsWith("narrator_") || fileName == "one_second_break" || fileName == "five_second_break") {
      return "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_${widget.nativeLanguage}/$fileName.mp3";
    } else if (fileName == "nickname") {
      final List<int> numbers = List.generate(6, (i) => i)..shuffle();
      bool urlFound = false;
      String? validUrl;

      for (final randomNumber in numbers) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final url = "https://storage.googleapis.com/user_nicknames/${widget.userID}_${randomNumber}_nickname.mp3?timestamp=$timestamp";

        if (await urlExists(url)) {
          urlFound = true;
          validUrl = url;
          break;
        }
      }
      if (hasNicknameAudio && addressByNickname && urlFound) {
        return validUrl!;
      } else {
        // Generic greeting
        int randomNumber = Random().nextInt(5) + 1;
        return "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_${Uri.encodeComponent(widget.nativeLanguage)}/narrator_greetings_$randomNumber.mp3";
      }
    } else if (fileName == "audio_cue") {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return "https://storage.googleapis.com/narrator_audio_files/general/audio_cue.mp3?timestamp=$timestamp";
    } else {
      return "https://storage.googleapis.com/conversations_audio_files/${widget.documentID}/$fileName.mp3";
    }
  }

  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations.take(currentIndex).fold(Duration.zero, (total, d) => total + d);
  }

  Stream<PositionData> get _positionDataStream {
    int lastIndex = -1;
    return Rx.combineLatest3<Duration, Duration, int, PositionData?>(
      player.positionStream.where((_) => isPlaying.value),
      player.durationStream.whereType<Duration>(),
      player.currentIndexStream.whereType<int>().startWith(0),
      (position, duration, index) {
        bool hasIndexChanged = index != lastIndex;
        lastIndex = index;
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        Duration totalPosition = cumulativeDuration + position;

        if (hasIndexChanged) return null;
        if (position < duration) {
          return PositionData(position, duration, totalPosition);
        }
        return null;
      },
    ).where((positionData) => positionData != null).cast<PositionData>().distinct((prev, current) => prev.position == current.position);
  }

  int findTrackIndexForPosition(double milliseconds) {
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) return i;
    }
    return trackDurations.length - 1;
  }

  Future<void> calculateTotalDurationAndUpdateTrackDurations(QuerySnapshot snapshot) async {
    totalDuration = Duration.zero;
    trackDurations = List<Duration>.filled(script.length, Duration.zero);
    audioDurations!.addAll(snapshot.docs[0].data() as Map<String, dynamic>);
    audioDurations!.addAll(await getAudioDurationsFromNarratorStorage());

    if (audioDurations!.isNotEmpty) {
      for (int i = 0; i < script.length; i++) {
        String fileName = script[i];
        double durationInSeconds = audioDurations?[fileName] ?? 0.0;
        Duration duration = Duration(milliseconds: (durationInSeconds * 1000).round());
        totalDuration += duration;
        trackDurations[i] = duration;
      }
      setState(() {});
    }

    if (updateNumber == widget.dialogue.length || !widget.generating) {
      finalTotalDuration = trackDurations.fold(Duration.zero, (total, d) => total + d);
      setState(() {});
    }
  }

  Future<Map<String, dynamic>> getAudioDurationsFromNarratorStorage() async {
    if (cachedAudioDurations != null) {
      return cachedAudioDurations!;
    }

    CollectionReference colRef = FirebaseFirestore.instance.collection('narrator_audio_files_durations/google_tts/narrator_${widget.nativeLanguage}');
    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      DocumentSnapshot firstDoc = querySnap.docs.first;
      return firstDoc.data() as Map<String, dynamic>;
    }
    return {};
  }

  String accessBigJson(Map<String, dynamic> listWithBigJson, String path) {
    final pattern = RegExp(r'(\D+)|(\d+)');
    final matches = pattern.allMatches(path);

    dynamic currentMap = listWithBigJson;
    for (var match in matches) {
      final key = match.group(0)!;
      final cleanedKey = key.replaceAll(RegExp(r'^_|_$'), '');

      if (int.tryParse(cleanedKey) != null) {
        // If it's a number, parse it as an index
        int index = int.parse(cleanedKey);
        currentMap = currentMap[index];
      } else {
        // If it's not a number, use it as a string key
        currentMap = currentMap[cleanedKey];
      }

      // If at any point currentMap is null, the key path is invalid
      if (currentMap == null) {
        throw Exception("Invalid path: $path");
      }
    }
    return currentMap;
  }

  void _handleTrackChangeToCompareSpeech(int localCurrentIndex) async {
    if (_isSkipping) return;

    if (currentTrack == "five_second_break" && isLanguageSupported && localCurrentIndex > previousIndex && !isSliderMoving) {
      print("_handleTrackChangeToCompareSpeech called, time:${DateTime.now().toIso8601String()}");

      final audioFileName = filesToCompare[localCurrentIndex];
      if (audioFileName == null) {
        print("Error: filesToCompare[localCurrentIndex] is null for index $localCurrentIndex");
        return;
      }

      if (widget.generating && latestSnapshot != null) {
        setState(() {
          targetPhraseToCompareWith = accessBigJson(latestSnapshot!, audioFileName);
        });
      } else if (existingBigJson != null) {
        setState(() {
          targetPhraseToCompareWith = accessBigJson(existingBigJson!, audioFileName);
        });
      } else {
        print("Error: Required JSON data is null.");
        return;
      }

      if (kIsWeb || Platform.isIOS) {
        final String stringWhenStarting = liveTextSpeechToText;
        Future.delayed(const Duration(milliseconds: 4500), () => _compareSpeechWithPhrase(stringWhenStarting));
      } else {
        if (voskSpeechService == null) {
          print('voskSpeechService is null in _handleTrackChangeToCompareSpeech');
          return;
        }
        voskSpeechService!.reset();
        Future.delayed(const Duration(milliseconds: 4500), () => _compareSpeechWithPhrase());
      }
    }
  }

  Future<String?> _fetchPreviousTargetPhrase(String documentId, String? previousTargetTrack) async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentId).collection('target_phrases').doc('updatable_target_phrases').get();

      if (documentSnapshot.exists) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
        return data[previousTargetTrack] as String?;
      } else {
        print('Document does not exist');
        setState(() {
          speechRecognitionSupported = false;
        });
        return null;
      }
    } catch (e) {
      print('Error fetching previous target phrase: $e');
      return null;
    }
  }

  void _showLanguageNotSupportedDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Speech Recognition Not Supported'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${widget.targetLanguage} is not supported for speech recognition on your device, but we're working on it!"),
              SizedBox(height: 8),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  speechRecognitionActive = false;
                  isLanguageSupported = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  String getAddedCharacters(String newString, String previousString) {
    // Split the strings into word lists
    List<String> newWords = newString.split(RegExp(r'\s+'));
    List<String> previousWords = previousString.split(RegExp(r'\s+'));

    // Compare word-by-word and find differences
    int minLength = previousWords.length;
    for (int i = 0; i < minLength; i++) {
      if (newWords[i] != previousWords[i]) {
        // Word has been replaced; return from this point onward
        return newWords.skip(i).join(' ');
      }
    }

    // If all previous words match, return the new additions
    if (newWords.length > previousWords.length) {
      return newWords.skip(previousWords.length).join(' ');
    }

    // If no new words are detected, return an empty string
    return "";
  }

  void _compareSpeechWithPhrase([String? stringWhenStarting]) async {
    if (!isPlaying.value) {
      print("Returning early because player was paused");
      return;
    }
    if (targetPhraseToCompareWith != null && !isSliderMoving) {
      String normalizedLiveTextSpeechToText = _normalizeString(liveTextSpeechToText);

      String newSpeech;
      if ((kIsWeb || Platform.isIOS) && stringWhenStarting != null) {
        print("liveTextSpeechToText: $liveTextSpeechToText");
        print("stringWhenStarting: $stringWhenStarting");
        String normalizedStringWhenStarting = _normalizeString(stringWhenStarting);
        newSpeech = getAddedCharacters(normalizedLiveTextSpeechToText, normalizedStringWhenStarting);
      } else {
        newSpeech = normalizedLiveTextSpeechToText;
      }

      print("newSpeech: $newSpeech");

      if (newSpeech == '') {
        // TODO: Add feedback for no audio detected
        print("NO audio was detected!!!");
        return;
      }
      // Normalize both strings: remove punctuation and convert to lowercase
      String normalizedResponse = _normalizeString(newSpeech);
      // Duplicate normalizedResponse for web doubled text bug
      String doubledNormalizedResponse = '$normalizedResponse $normalizedResponse';
      String normalizedTargetPhrase = _normalizeString(targetPhraseToCompareWith!);

      print('you said: $normalizedResponse, timestamp: ${DateTime.now().toIso8601String()}');
      print('target phrase: $normalizedTargetPhrase, timestamp: ${DateTime.now().toIso8601String()}');

      // Calculate similarity
      double similarity = StringSimilarity.compareTwoStrings(
        normalizedResponse,
        normalizedTargetPhrase,
      );

      double similarityForDoubled = StringSimilarity.compareTwoStrings(
        doubledNormalizedResponse,
        normalizedTargetPhrase,
      );

      if (similarityForDoubled > similarity) {
        similarity = similarityForDoubled;
      }

      print('Similarity: $similarity');

      if (similarity >= 0.7) {
        print('Good job! You repeated the phrase correctly.');
        await _provideFeedback(isPositive: true);
      } else {
        print('Try again. The phrase didn\'t match.');
        await _provideFeedback(isPositive: false);
      }
    }
  }

// Helper method to normalize strings
  String _normalizeString(String input) {
    // Remove punctuation but preserve Unicode letters including Devanagari
    return input.replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '').toLowerCase();
    // return input.replaceAll(RegExp(r'[^\w\s]+'), '').toLowerCase();
  }

// Method to provide audio feedback
  Future<void> _provideFeedback({required bool isPositive}) async {
    // String answerUrl = isPositive ? 'https://storage.googleapis.com/pronunciation_feedback/correct_answer.mp3' : 'https://storage.googleapis.com/pronunciation_feedback/incorrect_answer.mp3';

    if (player.playing) {
      await player.pause();
    }

    // Create a separate AudioPlayer for feedback
    AudioPlayer feedbackPlayer = AudioPlayer();

    // Get the feedback audio URL
    String feedbackUrl = _getFeedbackAudioUrl(isPositive);
    print('Playing feedback audio from: $feedbackUrl'); // Add debug print

    // Set the audio source using the cloud URL
    await feedbackPlayer.setAudioSource(
      AudioSource.uri(Uri.parse(feedbackUrl)),
    );

    // Play the feedback
    await feedbackPlayer.play();

    // Release the feedback player resources
    await feedbackPlayer.dispose();

    await player.play();
  }

  // Add a new method to get random feedback audio URL
  String _getFeedbackAudioUrl(bool isPositive) {
    final random = Random();
    final num = isPositive ? random.nextInt(3) : random.nextInt(2) + 3; // 0-2 for positive, 3-4 for negative
    return 'https://storage.googleapis.com/pronunciation_feedback/feedback_${widget.nativeLanguage}_${isPositive ? "positive" : "negative"}_$num.mp3';
  }

  Future<void> _changePlaybackSpeed(double speed) async {
    await player.setSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  Future<void> _handleLessonCompletion() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _streakService.recordDailyActivity(userId);
      setState(() {
        _showStreak = true;
      });

      // Hide streak after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showStreak = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenWrapper(
      child: Stack(
        children: [
          // Main content
          PopScope(
            canPop: false,
            onPopInvoked: (bool didPop) async {
              if (didPop) return;
              final NavigatorState navigator = Navigator.of(context);
              if (!widget.generating) {
                if (isPlaying.value) await _pause();
                navigator.pop('reload');
              } else {
                if (isPlaying.value) await _pause();
                navigator.popUntil((route) => route.isFirst);
                navigator.pushReplacementNamed('/');
              }
            },
            child: FutureBuilder<int>(
              future: _getSavedPosition(),
              builder: (context, snapshot) {
                int savedPosition = snapshot.data ?? 0;
                return Scaffold(
                  appBar: AppBar(title: Text(widget.title)),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('check pronunciation:'),
                            Switch(
                              value: speechRecognitionActive,
                              onChanged: (bool value) {
                                if (value) {
                                  initializeSpeechRecognition();
                                } else if (!value && kIsWeb || (!kIsWeb && Platform.isIOS)) {
                                  speechToTextUltra.stopListening();
                                } else if (!value && !kIsWeb && Platform.isAndroid) {
                                  voskSpeechService?.stop();
                                  voskSpeechService?.dispose();
                                }
                                setState(() {
                                  speechRecognitionActive = value;
                                });
                              },
                            ),
                          ],
                        ),
                        DialogueList(
                          dialogue: widget.dialogue,
                          currentTrack: currentTrack,
                          wordsToRepeat: widget.wordsToRepeat,
                        ),
                        PositionSlider(
                          positionDataStream: _positionDataStream,
                          totalDuration: totalDuration,
                          finalTotalDuration: finalTotalDuration,
                          isPlaying: isPlaying.value,
                          savedPosition: savedPosition,
                          findTrackIndexForPosition: findTrackIndexForPosition,
                          player: player,
                          cumulativeDurationUpTo: cumulativeDurationUpTo,
                          pause: _pause,
                          onSliderChangeStart: () {
                            setState(() {
                              isSliderMoving = true;
                            });
                          },
                          onSliderChangeEnd: () {
                            setState(() {
                              isSliderMoving = false;
                            });
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32), // Adjust this value as needed
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous),
                                      onPressed: player.hasPrevious ? () => player.seekToPrevious() : null,
                                    ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isPlaying,
                                      builder: (context, playing, child) {
                                        return IconButton(
                                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                                          onPressed: () {
                                            isPlaying.value = !isPlaying.value;
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next),
                                      onPressed: player.hasNext
                                          ? () {
                                              setState(() {
                                                _isSkipping = true;
                                              });
                                              player.seekToNext();
                                              Future.delayed(const Duration(seconds: 1), () {
                                                setState(() {
                                                  _isSkipping = false;
                                                });
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    PopupMenuButton<RepetitionMode>(
                                      offset: const Offset(0, 40),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Repetitions',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<RepetitionMode>>[
                                        PopupMenuItem<RepetitionMode>(
                                          value: RepetitionMode.normal,
                                          child: Row(
                                            children: [
                                              const Text('Normal Repetitions'),
                                              if (_repetitionsMode.value == RepetitionMode.normal)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 8.0),
                                                  child: Icon(Icons.check, size: 18),
                                                ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem<RepetitionMode>(
                                          value: RepetitionMode.less,
                                          child: Row(
                                            children: [
                                              const Text('Less Repetitions'),
                                              if (_repetitionsMode.value == RepetitionMode.less)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 8.0),
                                                  child: Icon(Icons.check, size: 18),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (RepetitionMode value) {
                                        if (widget.generating) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Please wait until we finish generating your audio to change this setting!'),
                                              action: SnackBarAction(
                                                label: 'OK',
                                                onPressed: () {
                                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                },
                                              ),
                                            ),
                                          );
                                        } else {
                                          _repetitionsMode.value = value;
                                        }
                                      },
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.speed,
                                          size: 18,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        DropdownButton<double>(
                                          value: _playbackSpeed,
                                          isDense: true,
                                          underline: Container(), // Remove the default underline,
                                          icon: Icon(
                                            Icons.arrow_drop_down,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 0.7, child: Text('0.7x')),
                                            DropdownMenuItem(value: 0.8, child: Text('0.8x')),
                                            DropdownMenuItem(value: 0.9, child: Text('0.9x')),
                                            DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                                            DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                                            DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                                            DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                                          ],
                                          onChanged: (double? newValue) {
                                            if (newValue != null) {
                                              _changePlaybackSpeed(newValue);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Streak overlay
          if (_showStreak)
            Container(
              color: Colors.black54,
              child: Center(
                child: StreakDisplay(),
              ),
            ),

          // Loading spinner overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _savePlayerPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    final currentPosition = positionData.inMilliseconds;
    int currentIndex = player.currentIndex ?? 0;
    print("will now save position: $currentPosition, player.currentIndex: ${player.currentIndex}");
    await prefs.setInt('savedPosition_${widget.documentID}_${widget.userID}', currentPosition);
    await prefs.setInt('savedTrackIndex_${widget.documentID}_${widget.userID}', currentIndex);
    await prefs.setBool("now_playing_${widget.documentID}_${widget.userID}", true);

    final nowPlayingKey = "now_playing_${widget.userID}";
    final nowPlayingList = prefs.getStringList(nowPlayingKey) ?? [];
    if (!nowPlayingList.contains(widget.documentID)) {
      nowPlayingList.add(widget.documentID);
    }
    await prefs.setStringList(nowPlayingKey, nowPlayingList);
  }

  Future<void> _pause({bool analyticsOn = true}) async {
    _savePlayerPosition();
    player.pause();

    if (analyticsOn) {
      analyticsManager.storeAnalytics(widget.documentID, 'pause');
    }
  }

  Future<void> _play() async {
    print("_play() called");
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedTrackIndex = prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');

    print("savedPosition: $savedPosition, savedTrackIndex: $savedTrackIndex");
    if (savedPosition != null && savedTrackIndex != null) {
      print("will now seek to position: $savedPosition, index: $savedTrackIndex");
      await player.seek(Duration(milliseconds: savedPosition), index: savedTrackIndex);
      print("player.currentIndex: ${player.currentIndex}");
    }
    player.play();

    // Show ad for non-premium users every time they start playing
    if (!_hasPremium && !_hasShownInitialAd) {
      _hasShownInitialAd = true; // Prevent showing ad multiple times in same session
      print("Now showing add");
      await AdService.showInterstitialAd(
        onAdShown: () async {
          isPlaying.value = false;
        },
        onAdDismissed: () async {
          isPlaying.value = true;
        },
      );
    }

    analyticsManager.storeAnalytics(widget.documentID, 'play');
  }

  Future<void> _stop() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('savedPosition_${widget.documentID}_${widget.userID}');
    prefs.remove('savedTrackIndex_${widget.documentID}_${widget.userID}');
    prefs.remove("now_playing_${widget.documentID}_${widget.userID}");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_${widget.userID}");

    if (nowPlayingList != null) {
      nowPlayingList.remove(widget.documentID);
      await prefs.setStringList("now_playing_${widget.userID}", nowPlayingList);
    }

    player.stop();
    player.seek(Duration.zero, index: 0);
    isPlaying.value = false;
    setState(() {
      currentTrack = script[0];
    });
  }

  Future<int> _getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedIndex = prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');
    final position = savedPosition! + cumulativeDurationUpTo(savedIndex!).inMilliseconds;
    return position;
  }

  Future<void> _loadAddressByNicknamePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      addressByNickname = prefs.getBool('addressByNickname') ?? true;
    });
  }

  @override
  void dispose() {
    _repetitionsMode.dispose();
    isPlaying.dispose();
    firestoreService?.dispose();
    fileDurationUpdate?.dispose();
    player.dispose();
    if (!kIsWeb && Platform.isAndroid) {
      voskSpeechService!.stop();
      voskSpeechService!.dispose();
    } else {
      speechToTextUltra.dispose();
    }
    super.dispose();
  }
}
