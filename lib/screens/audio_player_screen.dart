import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:parakeet/utils/script_generator.dart' as script_generator;
import 'package:parakeet/widgets/audio_player_screen/animated_dialogue_list.dart';
import 'package:parakeet/widgets/audio_player_screen/position_slider.dart';
import 'package:parakeet/widgets/audio_player_screen/audio_controls.dart';
import 'package:parakeet/widgets/audio_player_screen/speech_recognition_toggle.dart';
import 'package:parakeet/widgets/profile_screen/streak_display.dart';
import 'package:parakeet/screens/lesson_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/main.dart';

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

  // Static method to ensure proper cleanup of any shared resources
  static void cleanupSharedResources() {
    print("AudioPlayerScreen - cleanupSharedResources called");
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
  }) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  // Services
  late AudioPlayerService _audioPlayerService;
  late SpeechRecognitionService _speechRecognitionService;
  late AudioGenerationService _audioGenerationService;
  late AudioDurationService _audioDurationService;
  late PlaylistGenerator _playlistGenerator;
  final StreakService _streakService = StreakService();
  UpdateFirestoreService? _firestoreService;
  FileDurationUpdate? _fileDurationUpdate;

  // State variables
  final ValueNotifier<RepetitionMode> _repetitionsMode = ValueNotifier(RepetitionMode.normal);
  final ValueNotifier<bool> _speechRecognitionActive = ValueNotifier(false);
  bool _isDisposing = false;
  bool _showStreak = false;
  bool _hasNicknameAudio = false;
  bool _addressByNickname = true;
  bool _isSliderMoving = false;
  int _updateNumber = 0;

  // Data variables
  List<dynamic> _script = [];
  String _currentTrack = '';
  Map<String, dynamic>? _latestSnapshot;
  Map<int, String> _filesToCompare = {};
  Map<String, dynamic>? _existingBigJson;
  bool _hasPremium = false;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _audioPlayerService = AudioPlayerService(
      documentID: widget.documentID,
      userID: widget.userID,
      hasPremium: _hasPremium,
    );

    _speechRecognitionService = SpeechRecognitionService(
      targetLanguage: widget.targetLanguage,
      nativeLanguage: widget.nativeLanguage,
      onLiveTextChanged: (String text) {
        if (mounted) {
          setState(() {});
        }
      },
    );

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

    // Initialize Firestore services
    _firestoreService = UpdateFirestoreService.getInstance(widget.documentID, widget.generating, _updatePlaylist, _updateTrackLength, _saveSnapshot);

    _fileDurationUpdate = FileDurationUpdate.getInstance(widget.documentID, _calculateTotalDurationAndUpdateTrackDurations);

    // Setup callbacks
    _audioPlayerService.onTrackChanged = _handleTrackChange;
    _audioPlayerService.onLessonCompleted = _handleLessonCompletion;

    // Initialize data
    if (!widget.generating) {
      _script = script_generator.createFirstScript(widget.dialogue);
      _currentTrack = _script.isNotEmpty ? _script[0] : '';
    }

    // Load preferences and data
    _loadAddressByNicknamePreference();
    _updateHasNicknameAudio().then((_) {
      _initializePlaylistGenerator();
      _initializePlaylist();
    });

    _checkPremiumStatus();
    _getExistingBigJson();

    // Setup listeners
    _repetitionsMode.addListener(_updatePlaylistOnTheFly);

    // If generating is true, create script and make second API call
    if (widget.generating) {
      _createScriptAndMakeSecondApiCall();
    }
  }

  void _initializePlaylistGenerator() {
    _playlistGenerator = PlaylistGenerator(
      documentID: widget.documentID,
      userID: widget.userID,
      nativeLanguage: widget.nativeLanguage,
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

    // Calculate track durations
    List<Duration> trackDurations = await _audioDurationService.calculateTrackDurations(filteredScript);
    _audioPlayerService.setTrackDurations(trackDurations);

    // Build files to compare map for speech recognition
    _filesToCompare = _audioDurationService.buildFilesToCompare(_script);
  }

  // Update playlist from Firestore snapshot
  void _updatePlaylist(QuerySnapshot snapshot) async {
    // Don't update if we're disposing or resources are already gone
    if (_isDisposing || _firestoreService == null) {
      print("Skipping updatePlaylist because widget is disposing");
      return;
    }

    try {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs[0].data();
        if (data != null && data is Map<String, dynamic> && data.containsKey("dialogue")) {
          _script = script_generator.parseAndCreateScript(data["dialogue"] as List<dynamic>, widget.wordsToRepeat, data["dialogue"] as List<dynamic>, _repetitionsMode);
        } else {
          print("Error: Invalid data format in snapshot");
          return;
        }
      } else {
        print("Error: No documents in snapshot");
        return;
      }
    } catch (e) {
      print("Error parsing and creating script: $e");
      return;
    }
    print(_script);

    _filesToCompare = _audioDurationService.buildFilesToCompare(_script);

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript = _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // Get new script items that aren't already in the playlist
    var newScript = List.from(filteredScript);
    newScript.removeRange(0, _audioPlayerService.playlist.children.length);

    // Generate audio sources for new items
    List<AudioSource> newAudioSources = await _playlistGenerator.generateAudioSources(newScript);

    // Add new tracks to playlist
    await _audioPlayerService.addToPlaylist(newAudioSources);

    // Increment update number
    _updateNumber++;
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

    // Set final total duration after a certain number of updates or if not generating
    if ((_updateNumber >= 4 || !widget.generating) && !_isDisposing) {
      print("Setting final total duration. Update number: $_updateNumber, generating: ${widget.generating}");
      _audioPlayerService.setFinalTotalDuration();
    }
  }

  Future<void> _updatePlaylistOnTheFly() async {
    if (_isDisposing || widget.generating) {
      return;
    }

    bool wasPlaying = _audioPlayerService.isPlaying.value;
    if (wasPlaying) {
      _audioPlayerService.isPlaying.value = false;
    }

    if (_existingBigJson == null) {
      print("Error: Required JSON data is null.");
      return;
    }

    // Generate script with repetition mode
    _script = _playlistGenerator.generateScriptWithRepetitionMode(
      _existingBigJson!["dialogue"] as List<dynamic>,
      widget.dialogue,
      _repetitionsMode.value,
    );

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

      if (_speechRecognitionActive.value) {
        _handleTrackChangeToCompareSpeech(index);
      }
    }
  }

  void _handleTrackChangeToCompareSpeech(int currentIndex) async {
    if (_speechRecognitionService.isSkipping || _isSliderMoving) return;

    if (_currentTrack == "five_second_break" && _speechRecognitionService.isLanguageSupported) {
      final audioFileName = _filesToCompare[currentIndex];
      if (audioFileName == null) {
        print("Error: filesToCompare[currentIndex] is null for index $currentIndex");
        return;
      }

      String targetPhrase;
      try {
        if (widget.generating && _latestSnapshot != null) {
          targetPhrase = _audioGenerationService.accessBigJson(_latestSnapshot!, audioFileName);
        } else if (_existingBigJson != null) {
          targetPhrase = _audioGenerationService.accessBigJson(_existingBigJson!, audioFileName);
        } else {
          print("Error: Required JSON data is null.");
          return;
        }

        _speechRecognitionService.setTargetPhraseToCompareWith(targetPhrase);

        // Capture the current speech text
        final String stringWhenStarting = _speechRecognitionService.liveTextSpeechToText;

        // Wait for user to speak and then compare
        Future.delayed(const Duration(milliseconds: 4500), () async {
          bool isCorrect = await _speechRecognitionService.compareSpeechWithPhrase(stringWhenStarting);

          // Pause playback to provide feedback
          if (_audioPlayerService.isPlaying.value) {
            await _audioPlayerService.pause(analyticsOn: false);
          }

          // Provide feedback
          await _speechRecognitionService.provideFeedback(isPositive: isCorrect);

          // Resume playback
          if (!_isDisposing) {
            _audioPlayerService.isPlaying.value = true;
          }
        });
      } catch (e) {
        print("Error in speech comparison: $e");
      }
    }
  }

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

      // Ensure script is created with the complete dialogue
      if (_script.isEmpty) {
        _script = _playlistGenerator.generateScript(completeDialogue);
        if (mounted) {
          setState(() {
            _currentTrack = _script.isNotEmpty ? _script[0] : '';
          });
        }
      }

      // Exit if widget is no longer mounted
      if (!mounted || _isDisposing) return;

      // Save script to Firestore
      await _audioGenerationService.saveScriptToFirestore(_script, completeDialogue);

      // Exit if widget is no longer mounted
      if (!mounted || _isDisposing) return;

      // Make the second API call
      await _audioGenerationService.makeSecondApiCall(_latestSnapshot!);

      // Add user to active creation
      await _audioGenerationService.addUserToActiveCreation();

      // Initialize playlist after a delay to allow audio files to be generated
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && !_audioPlayerService.playlistInitialized) {
          print("Fallback: Initializing playlist after timeout");
          _initializePlaylist();
        }
      });
    } catch (e) {
      print('Error creating script and making second API call: $e');
    }
  }

  Future<void> _getExistingBigJson() async {
    if (!widget.generating) {
      _existingBigJson = await _audioGenerationService.getExistingBigJson();
    }
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
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _streakService.recordDailyActivity(userId);
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
  }

  void _toggleSpeechRecognition(bool value) async {
    if (value) {
      bool isSupported = await _speechRecognitionService.initializeSpeechRecognition();
      if (!isSupported) {
        _showLanguageNotSupportedDialog();
        return;
      }
    } else {
      _speechRecognitionService.stopListening();
    }

    _speechRecognitionActive.value = value;
    _speechRecognitionService.speechRecognitionActive = value;
  }

  void _showLanguageNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LanguageNotSupportedDialog(
          targetLanguage: widget.targetLanguage,
          onDismiss: () {
            setState(() {
              _speechRecognitionActive.value = false;
              _speechRecognitionService.isLanguageSupported = false;
              _speechRecognitionService.speechRecognitionActive = false;
            });
          },
        );
      },
    );
  }

  void _onAllDialogueDisplayed() {
    if (_isDisposing) return;

    print("All dialogue items have been displayed, initializing playlist");
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

            print("AudioPlayerScreen - onPopInvoked() called with generating: ${widget.generating}");

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
                        SpeechRecognitionToggle(
                          speechRecognitionService: _speechRecognitionService,
                          isActive: _speechRecognitionActive,
                          onToggle: _toggleSpeechRecognition,
                        ),
                        AnimatedDialogueList(
                          dialogue: widget.dialogue,
                          currentTrack: _currentTrack,
                          wordsToRepeat: widget.wordsToRepeat,
                          documentID: widget.documentID,
                          useStream: widget.generating,
                          generating: widget.generating,
                          onAllDialogueDisplayed: widget.generating ? _onAllDialogueDisplayed : null,
                        ),
                        // Audio generation message
                        if (widget.generating && !_audioPlayerService.playlistInitialized)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Generating audio files...",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        PositionSlider(
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
                              _speechRecognitionService.isSliderMoving = true;
                            });
                          },
                          onSliderChangeEnd: () {
                            setState(() {
                              _isSliderMoving = false;
                              _speechRecognitionService.isSliderMoving = false;
                            });
                          },
                        ),
                        AudioControls(
                          audioPlayerService: _audioPlayerService,
                          repetitionMode: _repetitionsMode,
                          generating: widget.generating,
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
    print("AudioPlayerScreen - dispose() called for documentID: ${widget.documentID}");
    _isDisposing = true;

    // Dispose of Firestore services
    _firestoreService?.dispose();
    _firestoreService = null;

    _fileDurationUpdate?.dispose();
    _fileDurationUpdate = null;

    // Dispose of services
    _audioPlayerService.dispose();
    _speechRecognitionService.dispose();

    // Dispose of notifiers
    _repetitionsMode.dispose();
    _speechRecognitionActive.dispose();

    super.dispose();
  }
}
