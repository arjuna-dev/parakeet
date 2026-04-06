import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/services/audio_generation_service.dart';
import 'package:parakeet/services/audio_duration_service.dart';
import 'package:parakeet/services/update_firestore_service.dart';
import 'package:parakeet/services/file_duration_update_service.dart';
import 'package:parakeet/services/background_audio_service.dart';
import 'package:parakeet/utils/audio_url_builder.dart';
import 'package:parakeet/utils/playlist_generator.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/script_generator.dart';
import 'package:parakeet/widgets/audio_player_screen/animated_dialogue_list.dart';
import 'package:parakeet/widgets/audio_player_screen/animated_grammar_section_list.dart';
import 'package:parakeet/widgets/audio_player_screen/position_slider.dart';
import 'package:parakeet/widgets/audio_player_screen/audio_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/widgets/audio_player_screen/review_words_dialog.dart';
import 'package:parakeet/widgets/audio_player_screen/audio_info.dart';
import 'package:parakeet/services/category_level_service.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/audio_player_manager.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/theme/theme.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String? category;
  final String documentID;
  final List<dynamic> dialogue;
  final List<dynamic> segments;
  final String userID;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final String languageLevel;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;
  final int numberOfTurns;
  final String lessonType;
  final AudioPlayerService? existingService;
  final bool isEmbedded;

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
    this.segments = const [],
    required this.userID,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.languageLevel,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
    required this.generating,
    required this.numberOfTurns,
    this.lessonType = 'conversation',
    this.existingService,
    this.isEmbedded = false,
  }) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  // Services
  late AudioPlayerService _audioPlayerService;

  late AudioGenerationService _audioGenerationService;
  late AudioDurationService _audioDurationService;
  late PlaylistGenerator _playlistGenerator;
  UpdateFirestoreService? _firestoreService;
  FileDurationUpdate? _fileDurationUpdate;

  // State variables
  final ValueNotifier<RepetitionMode> _repetitionsMode =
      ValueNotifier(RepetitionMode.normal);

  List<dynamic>? _wordsToRepeat;
  bool _isDisposing = false;
  bool _hasNicknameAudio = false;
  bool _addressByNickname = true;

  int _updateNumber = 0;
  late bool _generating;
  bool _isCompleted = false;
  bool _allDialogueGenerated = false;
  Timer? _positionMonitorTimer;

  // Data variables
  late List<dynamic> _dialogue;
  late List<dynamic> _segments;
  List<dynamic> _script = [];
  Map<String, dynamic> _scriptAndWordCards = {};
  Map<String, DocumentReference> _allUsedWordsCardsRefsMap = {};
  String _currentTrack = '';
  Map<String, dynamic>? _latestSnapshot;

  Map<String, dynamic>? _existingBigJson;
  bool _hasPremium = false;
  int _grammarPart1SegmentCount = 0;
  bool _hasAutoStartedGrammarPlayback = false;
  bool _suppressGrammarAutoplay = false;
  bool _grammarDurationLocked = false;

  bool _hasReadyGrammarPart1Batch(Map<String, dynamic>? data) {
    final audioParts = data?['audio_parts'] as List<dynamic>? ?? const [];
    return audioParts.any(
      (part) => part.toString().startsWith('grammar_part_1_batch_'),
    );
  }

  bool get _shouldReuseLockedPlaybackState =>
      widget.existingService != null &&
      !_generating &&
      _audioPlayerService.playlistInitialized &&
      _audioPlayerService.finalTotalDuration.value > Duration.zero;

  @override
  void initState() {
    super.initState();
    // Initialize _generating with widget.generating
    _generating = widget.generating;

    // For non-generating mode, all dialogue is already available
    _allDialogueGenerated = !widget.generating;

    // Make a mutable copy of the initial dialogue that we can update over time
    _dialogue = List<dynamic>.from(widget.dialogue);
    _segments = List<dynamic>.from(widget.segments);

    _wordsToRepeat = widget.wordsToRepeat;

    // Initialize services
    if (widget.existingService != null) {
      _audioPlayerService = widget.existingService!;
    } else {
      _audioPlayerService = AudioPlayerService(
        documentID: widget.documentID,
        userID: widget.userID,
        hasPremium: _hasPremium,
      );
    }

    _audioPlayerService.isPlaying.addListener(_handlePlayingStateChanged);

    _audioGenerationService = AudioGenerationService(
      documentID: widget.documentID,
      userID: widget.userID,
      title: widget.title,
      nativeLanguage: widget.nativeLanguage,
      targetLanguage: widget.targetLanguage,
      languageLevel: widget.languageLevel,
      wordsToRepeat: widget.wordsToRepeat,
      scriptDocumentId: widget.scriptDocumentId,
      lessonType: widget.lessonType,
      requestedTopic: widget.title,
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
      languageLevel: widget.languageLevel,
      hasNicknameAudio: false, // Will be updated later
      addressByNickname: true, // Will be updated later
      wordsToRepeat: widget.wordsToRepeat,
      lessonType: widget.lessonType,
    );

    // Initialize Firestore services
    _firestoreService = UpdateFirestoreService.getInstance(
      widget.documentID,
      widget.generating,
      widget.lessonType,
      _updatePlaylist,
      _updateTrackLength,
      _saveSnapshot,
    );

    _fileDurationUpdate = FileDurationUpdate.getInstance(
        widget.documentID, _calculateTotalDurationAndUpdateTrackDurations);

    // Setup callbacks
    _audioPlayerService.onTrackChanged = _handleTrackChange;
    _audioPlayerService.onLessonCompleted = _handleLessonCompletion;

    // Setup position-based track monitoring for better synchronization
    _setupPositionBasedTrackMonitoring();

    // Setup listeners
    _repetitionsMode.addListener(_updatePlaylistOnTheFly);

    // Begin the sequential initialization process
    _sequentialInitialization();

    // Check completion status
    _checkCompletionStatus();
  }

  // Sequentially handle all initialization steps in the correct order
  void _sequentialInitialization() async {
    try {
      // Step 1: Check premium status
      await _checkPremiumStatus();
      _audioPlayerService.hasPremium = _hasPremium;

      // Step 2: Load preferences first
      await _loadAddressByNicknamePreference();

      // Step 3: Update nickname audio status
      await _updateHasNicknameAudio();

      // Step 4: Initialize playlist generator with the correct values
      _initializePlaylistGenerator();

      // Step 5: Load script based on mode
      if (!widget.generating) {
        await _getExistingBigJson();
        // For non-generating mode, we need to wait for script creation
        if (_existingBigJson != null) {
          if (widget.lessonType == 'grammar') {
            _segments =
                List<dynamic>.from(_existingBigJson!['segments'] ?? _segments);
            _dialogue =
                List<dynamic>.from(_existingBigJson!['dialogue'] ?? _dialogue);
            _grammarPart1SegmentCount =
                (_existingBigJson!['part_1_segment_count'] as num?)?.toInt() ??
                    _grammarPart1SegmentCount;
          }
          // Convert to a properly handled Future chain
          _scriptAndWordCards =
              await _playlistGenerator.generateScriptWithRepetitionMode(
            _existingBigJson!,
            _dialogue,
            _repetitionsMode.value,
            widget.category ?? 'Custom Lesson',
            segments: _segments,
          );

          _script = _scriptAndWordCards['script'] ?? [];
          _allUsedWordsCardsRefsMap =
              _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? [];
          _currentTrack = _script.isNotEmpty ? _script[0] : '';

          if (mounted) {
            setState(() {
              _script = _scriptAndWordCards['script'] ?? [];
              _allUsedWordsCardsRefsMap =
                  _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? [];
              _currentTrack = _script.isNotEmpty ? _script[0] : '';
            });
          } else {
            return; // Exit if widget is no longer mounted
          }
        } else {
          print("Error: _existingBigJson is null for non-generating mode");
        }
        if (_shouldReuseLockedPlaybackState) {
          if (_audioPlayerService.playlistFileNames.isNotEmpty) {
            _script =
                List<dynamic>.from(_audioPlayerService.playlistFileNames);
          }
          _currentTrack = _pickTrackNameForPlaylistIndex(
                  _audioPlayerService.player.currentIndex ?? 0) ??
              (_script.isNotEmpty ? _script[0] : '');
          if (mounted) {
            setState(() {});
          }
        } else {
          await _initializePlaylist();
        }

        // Ensure durations are loaded even if playlist was already initialized
        if (!_shouldReuseLockedPlaybackState &&
            (_audioPlayerService.trackDurations.isEmpty ||
                _audioPlayerService.totalDuration.value == Duration.zero)) {
          print("Track durations not set, calculating now...");
          List<dynamic> filteredScript =
              _script.where((fileName) => !fileName.startsWith('\$')).toList();
          final resolved = await _playlistGenerator
              .resolveScriptEntriesWithUrls(filteredScript);
          List<Duration> trackDurations =
              await _audioDurationService.calculateTrackDurations(resolved);
          _audioPlayerService.setTrackDurations(trackDurations,
              alignedFileNames: resolved);
          if (!widget.generating) {
            _audioPlayerService.setFinalTotalDuration();
            if (widget.lessonType == 'grammar') {
              _grammarDurationLocked = true;
            }
          }
          if (mounted) {
            setState(() {}); // Trigger rebuild with updated durations
          }
        }
      } else {
        if (widget.lessonType == 'grammar') {
          _createGrammarScriptFromFirstApiOnly();
        } else {
          _createScriptAndMakeSecondApiCall();
        }
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
      languageLevel: widget.languageLevel,
      hasNicknameAudio: _hasNicknameAudio,
      addressByNickname: _addressByNickname,
      wordsToRepeat: widget.wordsToRepeat,
      lessonType: widget.lessonType,
      availabilityChecker: _audioDurationService.hasAudioForFile,
    );
  }

  Future<void> _initializePlaylist() async {
    if (_audioPlayerService.playlistInitialized || _isDisposing) {
      return;
    }

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript =
        _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // One pass: playlist skips entries with empty URLs; durations must match indices.
    final built =
        await _playlistGenerator.buildAudioSourcesFromScript(filteredScript);

    List<Duration> trackDurations = await _audioDurationService
        .calculateTrackDurations(built.resolvedScript);
    _audioPlayerService.setTrackDurations(trackDurations,
        alignedFileNames: built.resolvedScript);

    if (!widget.generating) {
      _audioPlayerService.setFinalTotalDuration();
      if (widget.lessonType == 'grammar') {
        _grammarDurationLocked = true;
      }

      // Update background audio service with final duration
      BackgroundAudioService.updateLessonInfo(
        widget.title,
        _audioPlayerService.finalTotalDuration.value,
        null, // You can add artwork URL here if available
        widget.category,
      );
    }

    // Initialize playlist
    await _audioPlayerService.initializePlaylist(built.sources);

    if (!_audioPlayerService.playlistInitialized) {
      print('Playlist not initialized (no audio sources or player skipped).');
      return;
    }

    // Connect to background audio service
    BackgroundAudioService.connectAudioPlayerService(
        _audioPlayerService, widget.title, widget.category);

    // Rebuild before playFirstTrack: that call waits for ProcessingState.ready
    // (buffering). Without setState here, PositionSlider keeps "Loading lesson..."
    // until the player is ready because StreamBuilder does not rebuild when only
    // playlistInitialized flips on the service.
    if (mounted) {
      setState(() {});
    }

    final shouldAutoStartGrammar = widget.lessonType == 'grammar' &&
        _generating &&
        !_hasAutoStartedGrammarPlayback &&
        !_suppressGrammarAutoplay &&
        (_latestSnapshot?['part_1_complete'] == true) &&
        _hasReadyGrammarPart1Batch(_latestSnapshot);

    final shouldAutoStart =
        widget.lessonType != 'grammar' || shouldAutoStartGrammar;

    // For grammar, auto-start only once: right after Part 1 is fully complete
    // and the player is first initialized. Later batch updates must not restart
    // playback if the user has paused manually.
    if (shouldAutoStart) {
      await _audioPlayerService.playFirstTrack();
      if (shouldAutoStartGrammar) {
        _hasAutoStartedGrammarPlayback = true;
      }
    }
    if (mounted) {
      setState(() {});
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

    Map<String, dynamic>? snapshotData;

    try {
      if (snapshot.docs.isEmpty) {
        print("Error: No documents in snapshot");
        return;
      }

      final data = snapshot.docs[0].data();
      if (data == null ||
          data is! Map<String, dynamic> ||
          !(data.containsKey(
              widget.lessonType == 'grammar' ? "segments" : "dialogue"))) {
        print("Error: Invalid data format in snapshot");
        return;
      }
      snapshotData = data;

      if (widget.lessonType == 'grammar' &&
          snapshotData['part_1_complete'] != true) {
        _latestSnapshot = Map<String, dynamic>.from(snapshotData);
        return;
      }

      if (widget.lessonType == 'grammar' && data['segments'] is List) {
        _segments = List<dynamic>.from(data['segments'] as List<dynamic>);
      }
      if (widget.lessonType == 'grammar' && data['dialogue'] is List) {
        _dialogue = List<dynamic>.from(data['dialogue'] as List<dynamic>);
      }
      if (widget.lessonType == 'grammar') {
        _grammarPart1SegmentCount =
            (data['part_1_segment_count'] as num?)?.toInt() ??
                _grammarPart1SegmentCount;
      }

      final scriptData =
          await _playlistGenerator.generateScriptWithRepetitionMode(
              data,
              _dialogue,
              _repetitionsMode.value,
              widget.category ?? 'Custom Lesson',
              segments: _segments);

      _script = scriptData['script'] ?? [];
      _allUsedWordsCardsRefsMap = scriptData['allUsedWordsCardsRefsMap'] ?? [];
    } catch (e) {
      print("Error parsing and creating script: $e");
      return;
    }

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript =
        _script.where((fileName) => !fileName.startsWith('\$')).toList();

    // Resolved script is 1:1 with playlist rows (empty URLs omitted).
    final fullResolved =
        await _playlistGenerator.resolveScriptEntriesWithUrls(filteredScript);
    final playlistLen = _audioPlayerService.playlist.children.length;
    if (widget.lessonType == 'grammar' &&
        !_audioPlayerService.playlistInitialized &&
        snapshotData?['part_1_complete'] == true &&
        _hasReadyGrammarPart1Batch(snapshotData) &&
        fullResolved.isNotEmpty) {
      _latestSnapshot = Map<String, dynamic>.from(snapshotData!);
      if (mounted && !_isDisposing) {
        setState(() {
          _currentTrack = fullResolved.first.toString();
        });
      }
      await _initializePlaylist();
      return;
    }
    if (playlistLen > fullResolved.length) {
      return;
    }
    final newNames = fullResolved.sublist(playlistLen);
    final newAudioSources =
        await _playlistGenerator.audioSourcesForNames(newNames);

    List<Duration> trackDurations =
        await _audioDurationService.calculateTrackDurations(fullResolved);
    _audioPlayerService.setTrackDurations(trackDurations,
        alignedFileNames: fullResolved);

    if (newAudioSources.isNotEmpty) {
      await _audioPlayerService.addToPlaylist(newAudioSources);
    }

    // Increment update number
    _updateNumber++;

    if (widget.lessonType == 'grammar') {
      final snapshotDataMap = snapshotData ?? const <String, dynamic>{};
      final audioParts =
          snapshotDataMap['audio_parts'] as List<dynamic>? ?? const [];

      final isComplete =
          snapshotDataMap['part_2_complete'] == true &&
          snapshotDataMap.containsKey('timestamp') &&
          audioParts.isNotEmpty;
      if (isComplete) {
        await _audioGenerationService.saveScriptToFirestore(
          _script,
          const [],
          _dialogue,
          widget.category ?? 'Custom Lesson',
          segments: _segments,
          audioParts: audioParts,
          part1SegmentCount: _grammarPart1SegmentCount,
        );
        _audioPlayerService.setFinalTotalDuration();
        _grammarDurationLocked = true;
        if (mounted && !_isDisposing) {
          setState(() {
            _generating = false;
            _allDialogueGenerated = true;
          });
        }
      }
      return;
    }

    // Check if we've reached the numberOfTurns and set _generating to false if so
    if (_updateNumber >= widget.numberOfTurns) {
      // Only set final total duration when all dialogue is complete
      _audioPlayerService.setFinalTotalDuration();
      if (widget.lessonType == 'grammar') {
        _grammarDurationLocked = true;
      }
      if (mounted && !_isDisposing) {
        setState(() {
          _generating = false;
          _allDialogueGenerated = true;
        });
      }
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
    if (_shouldReuseLockedPlaybackState) return;

    CollectionReference colRef = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(widget.documentID)
        .collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();
    if (querySnap.docs.isNotEmpty) {
      await _calculateTotalDurationAndUpdateTrackDurations(querySnap);
    }
  }

  // Calculate total duration and update track durations
  Future<void> _calculateTotalDurationAndUpdateTrackDurations(
      QuerySnapshot snapshot) async {
    if (_isDisposing) return;
    if (_shouldReuseLockedPlaybackState) return;
    if (widget.lessonType == 'grammar' &&
        _grammarDurationLocked &&
        _audioPlayerService.finalTotalDuration.value > Duration.zero) {
      return;
    }

    // Filter script to remove files that start with '$'
    List<dynamic> filteredScript =
        _script.where((fileName) => !fileName.startsWith('\$')).toList();

    final resolved =
        await _playlistGenerator.resolveScriptEntriesWithUrls(filteredScript);
    List<Duration> trackDurations =
        await _audioDurationService.calculateTrackDurations(resolved);
    _audioPlayerService.setTrackDurations(trackDurations,
        alignedFileNames: resolved);

    // Set final total duration after reaching numberOfTurns or if not generating
    if ((_updateNumber >= widget.numberOfTurns || !_generating) &&
        !_isDisposing) {
      _audioPlayerService.setFinalTotalDuration();
      if (widget.lessonType == 'grammar') {
        _grammarDurationLocked = true;
      }
    }
  }

  Future<void> _updatePlaylistOnTheFly() async {
    if (_isDisposing || _generating) {
      return;
    }
    if (widget.lessonType == 'grammar') {
      _grammarDurationLocked = false;
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
    _scriptAndWordCards =
        await _playlistGenerator.generateScriptWithRepetitionMode(
      _existingBigJson!,
      _dialogue,
      _repetitionsMode.value,
      widget.category ?? 'Custom Lesson',
      segments: _segments,
    );

    _script = _scriptAndWordCards['script'] ?? [];
    _allUsedWordsCardsRefsMap =
        _scriptAndWordCards['allUsedWordsCardsRefsMap'] ?? {};

    // Filter script
    List<dynamic> filteredScript = _playlistGenerator.filterScript(_script);

    final built =
        await _playlistGenerator.buildAudioSourcesFromScript(filteredScript);

    // Update playlist
    await _audioPlayerService.updatePlaylist(built.sources);

    List<Duration> trackDurations = await _audioDurationService
        .calculateTrackDurations(built.resolvedScript);
    _audioPlayerService.setTrackDurations(trackDurations,
        alignedFileNames: built.resolvedScript);

    _audioPlayerService.setFinalTotalDuration();
    if (widget.lessonType == 'grammar') {
      _grammarDurationLocked = true;
    }

    // Resume playback if it was playing before
    if (wasPlaying) {
      _audioPlayerService.isPlaying.value = true;
    }
  }

  // Setup position-based track monitoring for better synchronization
  void _setupPositionBasedTrackMonitoring() {
    // Monitor position changes more frequently for better track synchronization
    _positionMonitorTimer?.cancel();
    _positionMonitorTimer =
        Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_isDisposing) {
        timer.cancel();
        return;
      }

      if (!mounted ||
          _script.isEmpty ||
          _audioPlayerService.trackDurations.isEmpty) {
        return;
      }

      try {
        // Get the current track index based on position
        final positionBasedIndex = _audioPlayerService.getCurrentTrackIndex();

        final newTrack = _pickTrackNameForPlaylistIndex(positionBasedIndex);
        if (newTrack != null && newTrack != _currentTrack) {
          if (mounted) {
            setState(() {
              _currentTrack = newTrack;
            });
          }
        }
      } catch (e) {
        // Silently handle errors to avoid disrupting playback
        print("Position-based track monitoring error: $e");
      }
    });
  }

  String? _pickTrackNameForPlaylistIndex(int index) {
    if (index < 0) return null;
    final names = _audioPlayerService.playlistFileNames;
    if (index < names.length) {
      return names[index].toString();
    }
    if (index < _script.length) {
      return _script[index].toString();
    }
    return null;
  }

  void _handleTrackChange(int index) {
    if (_isDisposing) return;

    final name = _pickTrackNameForPlaylistIndex(index);
    if (name != null && mounted) {
      setState(() {
        _currentTrack = name;
      });
    }
  }

  Future<void> _createScriptAndMakeSecondApiCall() async {
    try {
      // First, wait for the first dialogue part to appear (15 second timeout)
      Map<String, dynamic>? firstDialogueData =
          await _audioGenerationService.waitForFirstDialogue();

      // If widget is no longer mounted, exit early
      if (!mounted || _isDisposing) return;

      // If we don't get the first dialogue within 15 seconds, show error and redirect
      if (firstDialogueData == null) {
        _showTimeoutErrorAndRedirect();
        return;
      }

      // Update dialogue with the first part that appeared
      if (firstDialogueData['dialogue'] != null) {
        List<dynamic> partialDialogue = firstDialogueData['dialogue'];
        _dialogue = partialDialogue;
        if (mounted) {
          setState(() {});
        }
      }

      // Now wait for the complete dialogue to be generated
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
        _script = createFirstScript(completeDialogue, widget.languageLevel);
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
      List<dynamic> keywordsUsedInDialogue =
          _latestSnapshot!['keywords_used'] ?? [];
      keywordsUsedInDialogue = keywordsUsedInDialogue
          .map((word) => word
              .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
              .toLowerCase())
          .toList();
      setState(() {
        _wordsToRepeat = keywordsUsedInDialogue;
      });

      // Save script to Firestore
      await _audioGenerationService.saveScriptToFirestore(
          _script,
          keywordsUsedInDialogue,
          completeDialogue,
          widget.category ?? 'Custom Lesson');

      // Slot was reserved when the lesson started (tryReserveActiveCreationSlot).

      // Start playback from first-API audio (intro + dialogue lines) immediately.
      // The second API runs in the background; Firestore snapshots extend the playlist.
      if (mounted && !_audioPlayerService.playlistInitialized) {
        await _initializePlaylist();
      }

      if (!mounted || _isDisposing) return;

      // Do not await: second API can take minutes (full TTS + big JSON). Waiting here
      // left playlistInitialized false and hid controls ("stuck on loading").
      unawaited(() async {
        try {
          await _audioGenerationService.makeSecondApiCall(
              _latestSnapshot!, keywordsUsedInDialogue);
        } catch (e) {
          debugPrint('Second API call failed: $e');
        }
      }());
    } catch (e) {
      print('Error creating script and making second API call: $e');
    }
  }

  Future<void> _createGrammarScriptFromFirstApiOnly() async {
    try {
      _latestSnapshot =
          await _audioGenerationService.waitForInitialGrammarLessonPlayback();

      if (!mounted || _isDisposing) return;
      if (_latestSnapshot == null) {
        print(
            'Initial grammar playback not ready yet; live Firestore updates will keep trying.');
        return;
      }

      _segments = List<dynamic>.from(_latestSnapshot!['segments'] ?? []);
      _dialogue = List<dynamic>.from(_latestSnapshot!['dialogue'] ?? []);
      _grammarPart1SegmentCount =
          (_latestSnapshot!['part_1_segment_count'] as num?)?.toInt() ??
              _segments.length;
        if (mounted) {
          setState(() {});
        }

      if (_script.isEmpty) {
        _script = createGrammarPodcastScript(_latestSnapshot!);
        if (mounted) {
          setState(() {
            _currentTrack = _script.isNotEmpty ? _script[0] : '';
          });
        }
      }

      await _audioGenerationService.saveScriptToFirestore(
        _script,
        const [],
        _dialogue,
        widget.category ?? 'Custom Lesson',
        segments: _segments,
        audioParts: _latestSnapshot!['audio_parts'] as List<dynamic>? ?? const [],
        part1SegmentCount: _grammarPart1SegmentCount,
      );

      if (mounted && !_audioPlayerService.playlistInitialized) {
        await _initializePlaylist();
      }

      final shouldAutoPlayGrammarNow =
          mounted &&
          !_isDisposing &&
          !_hasAutoStartedGrammarPlayback &&
          !_suppressGrammarAutoplay &&
          _audioPlayerService.playlistInitialized &&
          (_latestSnapshot?['part_1_complete'] == true) &&
          _hasReadyGrammarPart1Batch(_latestSnapshot);

      if (shouldAutoPlayGrammarNow) {
        await _audioPlayerService.playFirstTrack();
        _hasAutoStartedGrammarPlayback = true;
        if (mounted) {
          setState(() {});
        }
      }

      unawaited(() async {
        try {
          await _audioGenerationService.makeSecondGrammarApiCall(
            _latestSnapshot!,
          );
        } catch (e) {
          print('Error making second grammar API call: $e');
        }
      }());
    } catch (e) {
      print('Error creating grammar script from first API: $e');
    }
  }

  Future<void> _getExistingBigJson() async {
    _existingBigJson = await _audioGenerationService.getExistingBigJson();
  }

  Future<void> _updateHasNicknameAudio() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String url =
        'https://storage.googleapis.com/user_nicknames/${widget.userID}_${widget.nativeLanguage}_1_nickname.mp3?timestamp=$timestamp';
    _hasNicknameAudio = await AudioUrlBuilder.urlExists(url);

    if (mounted) {
      setState(() {});
    }
  }

  void _handlePlayingStateChanged() {
    if (_isDisposing || widget.lessonType != 'grammar') return;
    if (!_hasAutoStartedGrammarPlayback) return;
    if (_audioPlayerService.isPlaying.value) return;

    final state = _audioPlayerService.player.playerState;
    if (state.processingState == ProcessingState.completed) {
      return;
    }

    _suppressGrammarAutoplay = true;
  }

  void _handleManualPause() {
    if (widget.lessonType != 'grammar') return;
    _suppressGrammarAutoplay = true;
    _hasAutoStartedGrammarPlayback = true;
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
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userID)
        .get();

    if (mounted) {
      setState(() {
        _hasPremium = userDoc.data()?['premium'] ?? false;
      });
    }
  }

  void _showTimeoutErrorAndRedirect() {
    if (!mounted) return;

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Oops, something went wrong! Please try again.',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 3),
        backgroundColor: const Color(0xFF1A4D3A),
      ),
    );

    // Go back to previous screen after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _handleLessonCompletion() async {
    // Show completion dialog when lesson finishes
    if (!_isCompleted) {
      bool completed = await _markAsCompleted();

      // Only show vocabulary review if user confirmed completion
      if (completed) {
        await _showVocabularyReview();
      }
    } else {
      // If already completed, show vocabulary review directly
      await _showVocabularyReview();
    }
  }

  Future<void> _showVocabularyReview() async {
    // show list of words that were used and ask user to review them
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReviewWordsDialog(
          words: _allUsedWordsCardsRefsMap,
          userID: widget.userID,
        );
      },
    );
  }

  Future<void> _checkCompletionStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(widget.documentID)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isCompleted = data['completed'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error checking completion status: $e');
    }
  }

  Future<bool> _markAsCompleted() async {
    // Pause audio before showing dialog
    bool wasPlaying = _audioPlayerService.isPlaying.value;
    if (wasPlaying) {
      _audioPlayerService.isPlaying.value = false;
    }

    // Show confirmation dialog
    bool? shouldComplete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: ParakeetDialogTheme.background(cs),
          surfaceTintColor: Colors.transparent,
          shape: ParakeetDialogTheme.alertShape(cs),
          title: Text(
            'Complete Lesson',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to mark this lesson as completed?',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    // If user cancelled, keep audio paused and return false
    if (shouldComplete != true) {
      return false;
    }

    // User confirmed, proceed with completion
    try {
      // Use set with merge: true to create the field if it doesn't exist
      await FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(widget.documentID)
          .set({'completed': true}, SetOptions(merge: true));

      // Update category level progress if this is a category lesson
      if (widget.category != null && widget.category != 'Custom Lesson') {
        // Get current level to record lesson completion for the correct level
        final categoryLevel = await CategoryLevelService.getCategoryLevel(
          widget.category!,
          widget.targetLanguage,
        );

        await CategoryLevelService.recordCompletedLesson(
          widget.category!,
          widget.targetLanguage,
          categoryLevel.currentLevel,
        );
      }

      if (mounted) {
        setState(() {
          _isCompleted = true;
        });
      }

      // Check if level was completed and show appropriate message
      String completionMessage = 'Lesson marked as completed!';
      if (widget.category != null && widget.category != 'Custom Lesson') {
        final updatedLevel = await CategoryLevelService.getCategoryLevel(
          widget.category!,
          widget.targetLanguage,
        );

        if (updatedLevel.isLevelCompleted && updatedLevel.canAccessNextLevel) {
          completionMessage =
              'Level ${updatedLevel.currentLevel - 1} completed! Level ${updatedLevel.currentLevel} unlocked!';
        } else if (updatedLevel.isLevelCompleted &&
            updatedLevel.currentLevel == CategoryLevelService.maxLevel) {
          completionMessage =
              'Congratulations! You\'ve mastered all levels in ${widget.category}!';
        }
      }

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(completionMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error marking lesson as completed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to mark lesson as completed. Please try again.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Resume audio if it was playing and completion failed
      if (wasPlaying) {
        _audioPlayerService.isPlaying.value = true;
      }
      return false;
    }

    // Return true if successfully completed
    return true;
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
    if (_isDisposing || !mounted) return;

    setState(() {
      _allDialogueGenerated = true;
    });

    if (!_audioPlayerService.playlistInitialized) {
      _initializePlaylist();
    }
  }

  void _seekToTime(Duration targetTime) async {
    if (_isDisposing) return;

    // If the player is paused, start playing first
    if (!_audioPlayerService.isPlaying.value) {
      _audioPlayerService.isPlaying.value = true;
      // Wait a brief moment for the player to start playing
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Find which track index contains this time
    final trackIndex = _audioPlayerService
        .findTrackIndexForPosition(targetTime.inMilliseconds.toDouble());

    // Calculate the position within that track
    final cumulativeDurationUpToTrack =
        _audioPlayerService.cumulativeDurationUpTo(trackIndex);
    final positionInTrack = targetTime - cumulativeDurationUpToTrack;

    // Ensure the position is not negative
    final seekPosition =
        positionInTrack.isNegative ? Duration.zero : positionInTrack;

    try {
      // Seek to the specific position
      await _audioPlayerService.player.seek(seekPosition, index: trackIndex);
    } catch (e) {
      print('Error seeking to time: $e');
      // If seeking fails, try alternative approach
      try {
        // First seek to the track index
        await _audioPlayerService.player.seek(Duration.zero, index: trackIndex);
        // Wait briefly then seek to the position
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayerService.player.seek(seekPosition);
      } catch (e2) {
        print('Alternative seek also failed: $e2');
      }
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
            if (didPop) {
              return;
            }

            if (widget.isEmbedded) {
              // If embedded, just collapse instead of popping
              // But we should still respect the generating check if we want to prevent closing
              if (widget.generating && !_allDialogueGenerated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        "Please wait for the lesson to finish generating."),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              // Collapse the player
              Provider.of<AudioPlayerManager>(context, listen: false)
                  .collapse();
              return;
            }

            // Only allow pop if not generating or all dialogue is generated
            if (widget.generating && !_allDialogueGenerated) {
              // Optionally show a message to the user that they can't go back yet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text("Please wait for the lesson to finish generating."),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            // Set disposing flag to prevent any async operations from using disposed resources
            _isDisposing = true;

            final NavigatorState navigator = Navigator.of(context);

            // Always pause audio regardless of generation state
            if (_audioPlayerService.isPlaying.value) {
              await _audioPlayerService.pause();
            }

            // Clean up any shared resources
            AudioPlayerScreen.cleanupSharedResources();

            // Always go back to previous screen (CategoryDetailScreen or other)
            if (navigator.canPop()) {
              navigator.pop('reload');
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: widget.isEmbedded
                  ? GestureDetector(
                      onTap: () {
                        // Only allow collapse if dialogue is fully generated
                        if (_allDialogueGenerated) {
                          Provider.of<AudioPlayerManager>(context,
                                  listen: false)
                              .collapse();
                        }
                      },
                      onPanUpdate: (details) {
                        // Collapse when dragging down, only if dialogue is fully generated
                        if (details.delta.dy > 0 && _allDialogueGenerated) {
                          Provider.of<AudioPlayerManager>(context,
                                  listen: false)
                              .collapse();
                        }
                      },
                      child: AudioInfo(title: widget.title),
                    )
                  : AudioInfo(title: widget.title),
              automaticallyImplyLeading: widget.isEmbedded
                  ? false
                  : (!widget.generating || _allDialogueGenerated),
              leading: widget.isEmbedded
                  ? IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: _allDialogueGenerated
                          ? () {
                              Provider.of<AudioPlayerManager>(context,
                                      listen: false)
                                  .collapse();
                            }
                          : null, // Disable button if dialogue not fully generated
                    )
                  : null,
            ),
            body: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A2F2A),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // SpeechRecognitionToggle(
                      //   speechRecognitionService: _speechRecognitionService,
                      //   isActive: _speechRecognitionActive,
                      //   onToggle: _toggleSpeechRecognition,
                      // ),
                      Expanded(
                        child: widget.lessonType == 'grammar'
                            ? AnimatedGrammarSectionList(
                                segments: _segments,
                                currentTrack: _currentTrack,
                                audioPlayerService: _audioPlayerService,
                                documentID: widget.documentID,
                                part1SegmentCount: _grammarPart1SegmentCount,
                                useStream: widget.generating,
                                generating: widget.isEmbedded
                                    ? false
                                    : widget.generating,
                                onAllSectionsDisplayed: widget.generating
                                    ? _onAllDialogueDisplayed
                                    : null,
                              )
                            : AnimatedDialogueList(
                                dialogue: _dialogue,
                                currentTrack: _currentTrack,
                                wordsToRepeat: _wordsToRepeat ?? [],
                                documentID: widget.documentID,
                                useStream: widget.generating,
                                generating: widget.isEmbedded
                                    ? false
                                    : widget.generating,
                                onAllDialogueDisplayed: widget.generating
                                    ? _onAllDialogueDisplayed
                                    : null,
                                script: _script,
                                trackDurations:
                                    _audioPlayerService.trackDurations,
                                onSeekToTime: _seekToTime,
                              ),
                      ),
                      // Position slider - fixed height
                      PositionSlider(
                        audioPlayerService: _audioPlayerService,
                        findTrackIndexForPosition:
                            _audioPlayerService.findTrackIndexForPosition,
                        player: _audioPlayerService.player,
                        cumulativeDurationUpTo:
                            _audioPlayerService.cumulativeDurationUpTo,
                        pause: ({bool analyticsOn = true}) =>
                            _audioPlayerService.pause(analyticsOn: analyticsOn),
                        onSliderChangeStart: () {
                          // Slider interaction started
                        },
                        onSliderChangeEnd: () {
                          // Slider interaction ended
                        },
                      ),
                      // Audio controls - fixed height
                      AudioControls(
                        audioPlayerService: _audioPlayerService,
                        repetitionMode: _repetitionsMode,
                        generating: _generating,
                        hasWordsToReview: _allUsedWordsCardsRefsMap.isNotEmpty,
                        onReviewWords: _showVocabularyReview,
                        onManualPause: _handleManualPause,
                        isCompleted: _isCompleted,
                        onMarkCompleted: _markAsCompleted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _isDisposing = true;
    _audioPlayerService.isPlaying.removeListener(_handlePlayingStateChanged);
    _positionMonitorTimer?.cancel();
    _positionMonitorTimer = null;
    if (widget.generating) {
      LessonService.releaseActiveCreationSlot(widget.userID, widget.documentID);
    }
    _repetitionsMode.removeListener(_updatePlaylistOnTheFly);

    // Dispose background audio service connection
    BackgroundAudioService.audioHandler?.dispose();

    // Cancel subscriptions
    _firestoreService?.dispose();
    _fileDurationUpdate?.dispose();

    // Only dispose the service if we created it (not embedded/injected)
    // OR if we want to ensure cleanup when the screen is permanently closed.
    // But if it's embedded, the Manager handles disposal.
    if (widget.existingService == null) {
      _audioPlayerService.dispose();
    } else {
      // If we are using an existing service, we should just remove our listeners
      _audioPlayerService.onTrackChanged = null;
      _audioPlayerService.onLessonCompleted = null;
    }

    // Dispose value notifiers
    _repetitionsMode.dispose();
    // _speechRecognitionActive.dispose();

    super.dispose();
  }
}
