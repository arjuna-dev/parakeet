import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/services/speech_recognition_service.dart';
import 'package:parakeet/services/audio_generation_service.dart';
import 'package:parakeet/services/audio_duration_service.dart';
import 'package:parakeet/services/streak_service.dart';
import 'package:parakeet/services/update_firestore_service.dart';
import 'package:parakeet/services/file_duration_update_service.dart';
import 'package:parakeet/utils/audio_url_builder.dart';
import 'package:parakeet/utils/playlist_generator.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/script_generator.dart';
import 'package:parakeet/widgets/audio_player_screen/animated_dialogue_list.dart';
import 'package:parakeet/widgets/audio_player_screen/position_slider.dart';
import 'package:parakeet/widgets/audio_player_screen/audio_controls.dart';
import 'package:parakeet/widgets/audio_player_screen/speech_recognition_toggle.dart';
import 'package:parakeet/widgets/profile_screen/streak_display.dart';
import 'package:parakeet/screens/lesson_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/widgets/audio_player_screen/review_words_dialog.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String? category;
  final String documentID;
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final String languageLevel;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;
  final int numberOfTurns;

  // Static method to ensure proper cleanup of any shared resources
  static void cleanupSharedResources() {
    // Force garbage collection of any shared services
    UpdateFirestoreService.forceCleanup();
    FileDurationUpdate.forceCleanup();
  }

  const AudioPlayerScreen({
    Key? key,
    this.category,
    required this.documentID,
    required this.dialogue,
    required this.userID,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.languageLevel,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
    required this.generating,
    required this.numberOfTurns,
  }) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  // Services
  late AudioPlayerService _audioPlayerService;
  // late SpeechRecognitionService _speechRecognitionService;
  late AudioGenerationService _audioGenerationService;
  late AudioDurationService _audioDurationService;
  late PlaylistGenerator _playlistGenerator;
  final StreakService _streakService = StreakService();
  UpdateFirestoreService? _firestoreService;
  FileDurationUpdate? _fileDurationUpdate;

  // State variables
  final ValueNotifier<RepetitionMode> _repetitionsMode = ValueNotifier(RepetitionMode.normal);
  // final ValueNotifier<bool> _speechRecognitionActive = ValueNotifier(false);
  List<dynamic>? _wordsToRepeat;
  bool _isDisposing = false;
  bool _showStreak = false;
  bool _hasNicknameAudio = false;
  bool _addressByNickname = true;
  bool _isSliderMoving = false;
  int _updateNumber = 0;
  late bool _generating;

  // Data variables
  late List<dynamic> _dialogue;
  List<dynamic> _script = [];
  Map<String, dynamic> _scriptAndWordCards = {};
  Map<String, DocumentReference> _allUsedWordsCardsRefsMap = {};
  String _currentTrack = '';
  Map<String, dynamic>? _latestSnapshot;
  Map<int, String> _filesToCompare = {};
  Map<String, dynamic>? _existingBigJson;
  bool _hasPremium = false;

  @override
  void initState() {
    super.initState();
    // Initialize _generating with widget.generating
    _generating = widget.generating;

    // Make a mutable copy of the initial dialogue that we can update over time
    _dialogue = List<dynamic>.from(widget.dialogue);

    _wordsToRepeat = widget.wordsToRepeat;

    // Initialize services
    _audioPlayerService = AudioPlayerService(
      documentID: widget.documentID,
      userID: widget.userID,
      hasPremium: _hasPremium,
    );

    // _speechRecognitionService = SpeechRecognitionService(
    //   targetLanguage: widget.targetLanguage,
    //   nativeLanguage: widget.nativeLanguage,
    //   onLiveTextChanged: (String text) {
    //     if (mounted) {
    //       setState(() {});
    //     }
    //   },
    // );

    _audioGenerationService = AudioGenerationService(
      documentID: widget.documentID,
      userID: widget.userID,
      title: widget.title,
      nativeLanguage: widget.nativeLanguage,
      targetLanguage: widget.targetLanguage,
      languageLevel: widget.languageLevel,
      wordsToRepeat: widget.wordsToRepeat,
      scriptDocumentId: widget.scriptDocumentId,
    );

    _audioDurationService = AudioDurationService(
      documentID: widget.documentID,
      nativeLanguage: widget.nativeLanguage,
    );

    // Initialize PlaylistGenerator early to avoid LateInitializationError
    _playlistGenerator = PlaylistGenerator(
      documentID: widget.documentID,
      userID: widget.userID,
      nativeLanguage: widget.nativeLanguage,
      targetLanguage: widget.targetLanguage,
      hasNicknameAudio: false, // Will be updated later
      addressByNickname: true, // Will be updated later
      wordsToRepeat: widget.wordsToRepeat,
    );

    // Initialize Firestore services
    _firestoreService = UpdateFirestoreService.getInstance(widget.documentID, widget.generating, _updatePlaylist, _updateTrackLength, _saveSnapshot);

    _fileDurationUpdate = FileDurationUpdate.getInstance(widget.documentID, _calculateTotalDurationAndUpdateTrackDurations);

    // Setup callbacks
    _audioPlayerService.onTrackChanged = _handleTrackChange;
    _audioPlayerService.onLessonCompleted = _handleLessonCompletion;

    // Setup listeners
    _repetitionsMode.addListener(_updatePlaylistOnTheFly);

    // Begin the sequential initialization process
    _sequentialInitialization();
  }

  // Sequentially handle all initialization steps in the correct order
  void _sequentialInitialization() async {
    try {
      // Step 1: Check premium status in parallel
      _checkPremiumStatus();

      // Step 2: Initialize playlist generator with the required values
      _initializePlaylistGenerator();

      // Step 3: Load preferences
      await _loadAddressByNicknamePreference();

      // Step 4: Update nickname audio status
      await _updateHasNicknameAudio();

      // Step 5: Load script based on mode
      if (!widget.generating) {
        await _getExistingBigJson();
        // For non-generating mode, we need to wait for script creation
        if (_existingBigJson != null) {
          // Convert to a properly handled Future chain
          _scriptAndWordCards = await _playlistGenerator.generateScriptWithRepetitionMode(
            _existingBigJson!,
            _dialogue,
            _repetitionsMode.value,
            widget.category ?? 'Custom Lesson',
          );

          _script = _scriptAndWordCards['script'] ?? [];
          _allUsedWordsCardsRefsMap = _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? [];
          _currentTrack = _script.isNotEmpty ? _script[0] : '';

          if (mounted) {
            setState(() {
              _script = _scriptAndWordCards['script'] ?? [];
              _allUsedWordsCardsRefsMap = _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? [];
              _currentTrack = _script.isNotEmpty ? _script[0] : '';
            });
          } else {
            return; // Exit if widget is no longer mounted
          }
        } else {
          print("Error: _existingBigJson is null for non-generating mode");
        }
        await _initializePlaylist();
      } else {
        _createScriptAndMakeSecondApiCall();
      }
    } catch (e) {
      print("Error in sequential initialization: $e");
    }
  }

  // Update PlaylistGenerator with current values
  void _initializePlaylistGenerator() {
    _playlistGenerator = PlaylistGenerator(
      documentID: widget.documentID,
      userID: widget.userID,
      nativeLanguage: widget.nativeLanguage,
      targetLanguage: widget.targetLanguage,
      hasNicknameAudio: _hasNicknameAudio,
      addressByNickname: _addressByNickname,
      wordsToRepeat: widget.wordsToRepeat,
    );
  }

  Future<void> _initializePlaylist() async {
    if (_audioPlayerService.playlistInitialized || _isDisposing) {
      return;
    }

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript = _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // Generate audio sources
    List<AudioSource> audioSources = await _playlistGenerator.generateAudioSources(filteredScript);

    // Initialize playlist
    await _audioPlayerService.initializePlaylist(audioSources);

    // Play first track only for non-generating mode
    if (!widget.generating) {
      await _audioPlayerService.playFirstTrack();
    } else {
      await _audioPlayerService.loadFirstTrack();
    }
    _audioPlayerService.playlistInitialized = true;
    setState(() {});

    //Calculate track durations
    List<Duration> trackDurations = await _audioDurationService.calculateTrackDurations(filteredScript);
    _audioPlayerService.setTrackDurations(trackDurations);

    if (!widget.generating) {
      _audioPlayerService.setFinalTotalDuration();
      // Build files to compare map for speech recognition
      _filesToCompare = _audioDurationService.buildFilesToCompare(_script);
    }
  }

  // Update playlist from Firestore snapshot
  void _updatePlaylist(QuerySnapshot snapshot) async {
    // If it is not generating return
    if (!_generating) {
      return;
    }
    // Don't update if we're disposing or resources are already gone
    if (_isDisposing || _firestoreService == null) {
      return;
    }

    try {
      if (snapshot.docs.isEmpty) {
        print("Error: No documents in snapshot");
        return;
      }

      final data = snapshot.docs[0].data();
      if (data == null || data is! Map<String, dynamic> || !data.containsKey("dialogue")) {
        print("Error: Invalid data format in snapshot");
        return;
      }

      final scriptData = await _playlistGenerator.generateScriptWithRepetitionMode(data, _dialogue, _repetitionsMode.value, widget.category ?? 'Custom Lesson');

      _script = scriptData['script'] ?? [];
      _allUsedWordsCardsRefsMap = scriptData['allUsedWordsCardsRefsMap'] ?? [];
    } catch (e) {
      print("Error parsing and creating script: $e");
      return;
    }

    _filesToCompare = _audioDurationService.buildFilesToCompare(_script);

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript = _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // Get new script items that aren't already in the playlist
    var newScript = List.from(filteredScript);
    newScript.removeRange(0, _audioPlayerService.playlist.children.length);

    // Generate audio sources for new items
    List<AudioSource> newAudioSources = await _playlistGenerator.generateAudioSources(newScript);

    // Update playlist
    await _audioPlayerService.addToPlaylist(newAudioSources);
    // Calculate track durations
    List<Duration> trackDurations = await _audioDurationService.calculateTrackDurations(filteredScript);
    _audioPlayerService.setTrackDurations(trackDurations);

    _audioPlayerService.setFinalTotalDuration();

    // Increment update number
    _updateNumber++;

    // Check if we've reached the numberOfTurns and set _generating to false if so
    if (_updateNumber >= widget.numberOfTurns) {
      setState(() {
        _generating = false;
      });
    }
  }

  // Save snapshot from Firestore
  void _saveSnapshot(QuerySnapshot snapshot) {
    if (_isDisposing) return;

    if (snapshot.docs.isNotEmpty) {
      _latestSnapshot = snapshot.docs[0].data() as Map<String, dynamic>?;
    }
  }

  // Update track length from Firestore
  Future<void> _updateTrackLength() async {
    if (_isDisposing) return;

    CollectionReference colRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();
    if (querySnap.docs.isNotEmpty) {
      await _calculateTotalDurationAndUpdateTrackDurations(querySnap);
    }
  }

  // Calculate total duration and update track durations
  Future<void> _calculateTotalDurationAndUpdateTrackDurations(QuerySnapshot snapshot) async {
    if (_isDisposing) return;

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript = _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // Calculate track durations
    List<Duration> trackDurations = await _audioDurationService.calculateTrackDurations(filteredScript);
    _audioPlayerService.setTrackDurations(trackDurations);

    // Set final total duration after reaching numberOfTurns or if not generating
    if ((_updateNumber >= widget.numberOfTurns || !widget.generating) && !_isDisposing) {
      _audioPlayerService.setFinalTotalDuration();
    }
  }

  Future<void> _updatePlaylistOnTheFly() async {
    if (_isDisposing || _generating) {
      return;
    }

    bool wasPlaying = _audioPlayerService.isPlaying.value;
    if (wasPlaying) {
      _audioPlayerService.isPlaying.value = false;
    }

    await _getExistingBigJson();

    if (_existingBigJson == null) {
      print("Error: Required JSON data is null.");
      return;
    }

    // Generate script with repetition mode
    _scriptAndWordCards = await _playlistGenerator.generateScriptWithRepetitionMode(
      _existingBigJson!,
      _dialogue,
      _repetitionsMode.value,
      widget.category ?? 'Custom Lesson',
    );

    _script = _scriptAndWordCards['script'] ?? [];
    _allUsedWordsCardsRefsMap = _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? {};

    // Build files to compare map
    _filesToCompare = _audioDurationService.buildFilesToCompare(_script);

    // Filter script
    List<dynamic> filteredScript = _playlistGenerator.filterScript(_script);

    // Generate audio sources
    List<AudioSource> audioSources = await _playlistGenerator.generateAudioSources(filteredScript);

    // Update playlist
    await _audioPlayerService.updatePlaylist(audioSources);

    // Calculate track durations
    List<Duration> trackDurations = await _audioDurationService.calculateTrackDurations(filteredScript);
    _audioPlayerService.setTrackDurations(trackDurations);

    _audioPlayerService.setFinalTotalDuration();

    // Resume playback if it was playing before
    if (wasPlaying) {
      _audioPlayerService.isPlaying.value = true;
    }
  }

  void _handleTrackChange(int index) {
    if (_isDisposing) return;

    if (index < _script.length && mounted) {
      String newTrack = _script[index];

      setState(() {
        _currentTrack = newTrack;
      });

      // if (_speechRecognitionActive.value) {
      //   _handleTrackChangeToCompareSpeech(index);
      // }
    }
  }

  // void _handleTrackChangeToCompareSpeech(int currentIndex) async {
  //   if (_speechRecognitionService.isSkipping || _isSliderMoving) return;

  //   if (_currentTrack == "five_second_break" && _speechRecognitionService.isLanguageSupported) {
  //     final audioFileName = _filesToCompare[currentIndex];
  //     if (audioFileName == null) {
  //       print("Error: filesToCompare[currentIndex] is null for index $currentIndex");
  //       return;
  //     }

  //     String targetPhrase;
  //     try {
  //       if (widget.generating && _latestSnapshot != null) {
  //         targetPhrase = _audioGenerationService.accessBigJson(_latestSnapshot!, audioFileName);
  //       } else if (_existingBigJson != null) {
  //         targetPhrase = _audioGenerationService.accessBigJson(_existingBigJson!, audioFileName);
  //       } else {
  //         print("Error: Required JSON data is null.");
  //         return;
  //       }

  //       _speechRecognitionService.setTargetPhraseToCompareWith(targetPhrase);

  //       // Capture the current speech text
  //       final String stringWhenStarting = _speechRecognitionService.liveTextSpeechToText;

  //       // Wait for user to speak and then compare
  //       Future.delayed(const Duration(milliseconds: 4500), () async {
  //         bool isCorrect = await _speechRecognitionService.compareSpeechWithPhrase(stringWhenStarting);

  //         // Pause playback to provide feedback
  //         if (_audioPlayerService.isPlaying.value) {
  //           await _audioPlayerService.pause(analyticsOn: false);
  //         }

  //         // Provide feedback
  //         await _speechRecognitionService.provideFeedback(isPositive: isCorrect);

  //         // Resume playback
  //         if (!_isDisposing) {
  //           _audioPlayerService.isPlaying.value = true;
  //         }
  //       });
  //     } catch (e) {
  //       print("Error in speech comparison: $e");
  //     }
  //   }
  // }

  Future<void> _createScriptAndMakeSecondApiCall() async {
    try {
      // Wait for dialogue to be fully generated
      _latestSnapshot = await _audioGenerationService.waitForCompleteDialogue();

      // If widget is no longer mounted, exit early
      if (!mounted || _isDisposing) return;

      // If we don't have the latest snapshot, we can't proceed
      if (_latestSnapshot == null) {
        print('Error: No dialogue data available for script creation');
        return;
      }

      // Get the complete dialogue from the latest snapshot
      List<dynamic> completeDialogue = _latestSnapshot!['dialogue'] ?? [];
      _dialogue = completeDialogue;
      if (mounted) {
        setState(() {});
      }

      // Ensure script is created with the complete dialogue
      if (_script.isEmpty) {
        _script = createFirstScript(completeDialogue);
        if (mounted) {
          setState(() {
            _currentTrack = _script.isNotEmpty ? _script[0] : '';
          });
        }
      }

      // Exit if widget is no longer mounted
      if (!mounted || _isDisposing) return;

      // wait until the the first api call is complete (last item in the _latestSnapshot)
      while (!_latestSnapshot!.containsKey('voice_2_id')) {
        await Future.delayed(const Duration(seconds: 1));
      }

      // Get keywords used in dialogue and set _wordsToRepeat to them
      List<dynamic> keywordsUsedInDialogue = _latestSnapshot!['keywords_used'] ?? [];
      keywordsUsedInDialogue = keywordsUsedInDialogue.map((word) => word.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').toLowerCase()).toList();
      setState(() {
        _wordsToRepeat = keywordsUsedInDialogue;
      });

      // Save script to Firestore
      await _audioGenerationService.saveScriptToFirestore(_script, keywordsUsedInDialogue, completeDialogue, widget.category ?? 'Custom Lesson');

      // Add user to active creation
      await _audioGenerationService.addUserToActiveCreation();

      // Make the second API call
      await _audioGenerationService.makeSecondApiCall(_latestSnapshot!, keywordsUsedInDialogue);

      // Initialize playlist after a delay to allow audio files to be generated
      if (mounted && !_audioPlayerService.playlistInitialized) {
        _initializePlaylist();
      }
    } catch (e) {
      print('Error creating script and making second API call: $e');
    }
  }

  Future<void> _getExistingBigJson() async {
    _existingBigJson = await _audioGenerationService.getExistingBigJson();
  }

  Future<void> _updateHasNicknameAudio() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String url = 'https://storage.googleapis.com/user_nicknames/${widget.userID}_${widget.nativeLanguage}_1_nickname.mp3?timestamp=$timestamp';
    _hasNicknameAudio = await AudioUrlBuilder.urlExists(url);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAddressByNicknamePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _addressByNickname = prefs.getBool('addressByNickname') ?? true;
      });
    }
  }

  Future<void> _checkPremiumStatus() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userID).get();

    if (mounted) {
      setState(() {
        _hasPremium = userDoc.data()?['premium'] ?? false;
      });
    }
  }

  Future<void> _handleLessonCompletion() async {
    // show list of words that were used and ask user to review them
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReviewWordsDialog(words: _allUsedWordsCardsRefsMap);
      },
    );

    // Record streak after review is completed
    await _streakService.recordDailyActivity(widget.userID);
    if (mounted) {
      setState(() {
        _showStreak = true;
      });
    }

    // Hide streak after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showStreak = false;
        });
      }
    });
  }

  // void _toggleSpeechRecognition(bool value) async {
  //   if (value) {
  //     bool isSupported = await _speechRecognitionService.initializeSpeechRecognition();
  //     if (!isSupported) {
  //       _showLanguageNotSupportedDialog();
  //       return;
  //     }
  //   } else {
  //     _speechRecognitionService.stopListening();
  //   }

  //   _speechRecognitionActive.value = value;
  //   _speechRecognitionService.speechRecognitionActive = value;
  // }

  // void _showLanguageNotSupportedDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return LanguageNotSupportedDialog(
  //         targetLanguage: widget.targetLanguage,
  //         onDismiss: () {
  //           setState(() {
  //             _speechRecognitionActive.value = false;
  //             _speechRecognitionService.isLanguageSupported = false;
  //             _speechRecognitionService.speechRecognitionActive = false;
  //           });
  //         },
  //       );
  //     },
  //   );
  // }

  void _onAllDialogueDisplayed() {
    if (_isDisposing) return;

    if (!_audioPlayerService.playlistInitialized) {
      _initializePlaylist();
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

            // Set disposing flag to prevent any async operations from using disposed resources
            _isDisposing = true;

            final NavigatorState navigator = Navigator.of(context);

            // Always pause audio regardless of generation state
            if (_audioPlayerService.isPlaying.value) {
              await _audioPlayerService.pause();
            }

            // Clean up any shared resources
            AudioPlayerScreen.cleanupSharedResources();

            // Reset any LessonDetailScreen state before navigating
            LessonDetailScreen.resetStaticState();

            if (widget.generating) {
              // Navigate to home screen and clear stack
              navigator.pushNamedAndRemoveUntil('/create_lesson', (route) => false);
            } else {
              // Normal navigation if not generating
              navigator.pop('reload');
            }
          },
          child: FutureBuilder<int>(
            future: _audioPlayerService.getSavedPosition(),
            builder: (context, snapshot) {
              int savedPosition = snapshot.data ?? 0;
              return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E2E),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // SpeechRecognitionToggle(
                        //   speechRecognitionService: _speechRecognitionService,
                        //   isActive: _speechRecognitionActive,
                        //   onToggle: _toggleSpeechRecognition,
                        // ),
                        AnimatedDialogueList(
                          dialogue: _dialogue,
                          currentTrack: _currentTrack,
                          wordsToRepeat: _wordsToRepeat ?? [],
                          documentID: widget.documentID,
                          useStream: widget.generating,
                          generating: widget.generating,
                          onAllDialogueDisplayed: widget.generating ? _onAllDialogueDisplayed : null,
                        ),
                        PositionSlider(
                          audioPlayerService: _audioPlayerService,
                          positionDataStream: _audioPlayerService.positionDataStream,
                          totalDuration: _audioPlayerService.totalDuration,
                          finalTotalDuration: _audioPlayerService.finalTotalDuration,
                          isPlaying: _audioPlayerService.isPlaying.value,
                          savedPosition: savedPosition,
                          findTrackIndexForPosition: _audioPlayerService.findTrackIndexForPosition,
                          player: _audioPlayerService.player,
                          cumulativeDurationUpTo: _audioPlayerService.cumulativeDurationUpTo,
                          pause: ({bool analyticsOn = true}) => _audioPlayerService.pause(analyticsOn: analyticsOn),
                          onSliderChangeStart: () {
                            setState(() {
                              _isSliderMoving = true;
                              // _speechRecognitionService.isSliderMoving = true;
                            });
                          },
                          onSliderChangeEnd: () {
                            setState(() {
                              _isSliderMoving = false;
                              // _speechRecognitionService.isSliderMoving = false;
                            });
                          },
                        ),
                        AudioControls(
                          audioPlayerService: _audioPlayerService,
                          repetitionMode: _repetitionsMode,
                          generating: _generating,
                        ),
                      ],
                    ),
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
      ],
    ));
  }

  @override
  void dispose() {
    _isDisposing = true;

    // Dispose of Firestore services
    _firestoreService?.dispose();
    _firestoreService = null;

    _fileDurationUpdate?.dispose();
    _fileDurationUpdate = null;

    // Dispose of services
    _audioPlayerService.dispose();
    // _speechRecognitionService.dispose();

    // Dispose of notifiers
    _repetitionsMode.dispose();
    // _speechRecognitionActive.dispose();

    super.dispose();
  }
}
