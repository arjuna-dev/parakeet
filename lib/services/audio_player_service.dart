import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parakeet/widgets/audio_player_screen/position_data.dart';

class AudioPlayerService {
  final String documentID;
  final String userID;
  bool hasPremium = false;

  late AudioPlayer player;
  late ConcatenatingAudioSource playlist;
  late AnalyticsManager analyticsManager;

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);
  bool playlistInitialized = false;
  bool hasShownInitialAd = false;
  bool isDisposing = false;

  List<Duration> trackDurations = [];
  /// One file name per playlist index (same order as [playlist.children]); empty URLs omitted.
  List<dynamic> playlistFileNames = [];
  List<Duration> _trackStartOffsets = [];
  final ValueNotifier<Duration> totalDuration =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> finalTotalDuration =
      ValueNotifier<Duration>(Duration.zero);
  String? currentTrackName; // Track name of the current audio file

  StreamSubscription? playerStateSubscription;
  StreamSubscription? currentIndexSubscription;
  /// Keeps [trackDurations] aligned with decoded segment lengths from [player].
  StreamSubscription? _decoderDurationSubscription;
  StreamSubscription? _decoderIndexSubscription;

  int? _lastDecoderIndex;
  Duration _lastDurationForIndex = Duration.zero;

  /// Watchdog: retry stalled segments, then skip to next (see [_playbackWatchdogTick]).
  Timer? _playbackWatchdog;
  int? _watchdogPlaylistIndex;
  Duration? _watchdogLastPosition;
  DateTime? _watchdogLastProgressAt;
  DateTime? _bufferingOrLoadingSince;
  DateTime? _endOfTrackHangSince;
  int _recoveryAttemptsForSegment = 0;
  bool _recoveryInFlight = false;

  static const Duration _watchdogInterval = Duration(seconds: 2);
  static const Duration _positionStallThreshold = Duration(seconds: 12);
  static const Duration _bufferingTimeout = Duration(seconds: 18);
  static const Duration _endOfTrackHangThreshold = Duration(seconds: 4);
  static const int _maxSegmentRetries = 3;

  /// Single broadcast stream so UI (StreamBuilder) does not resubscribe on every
  /// rebuild — e.g. collapsing/expanding the persistent player was creating a new
  /// combineLatest pipeline each time and resetting / desyncing the slider time.
  late final Stream<PositionData> positionDataStream;

  AudioPlayerService({
    required this.documentID,
    required this.userID,
    required this.hasPremium,
  }) {
    // Eager preparation: buffer each segment before it is needed so the next clip
    // is ready at concat boundaries. Lazy prep can hand off too early on slow
    // networks and clip the tail of the previous file.
    player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        darwinLoadControl: DarwinLoadControl(
          automaticallyWaitsToMinimizeStalling: true,
          preferredForwardBufferDuration: Duration(seconds: 6),
        ),
      ),
    );
    playlist =
        ConcatenatingAudioSource(useLazyPreparation: false, children: []);
    analyticsManager = AnalyticsManager(userID);

    // Initialize player
    _init();
  }

  void _init() {
    player.setSpeed(playbackSpeed.value);

    // Setup listeners
    playbackSpeed.addListener(() {
      player.setSpeed(playbackSpeed.value);
    });

    isPlaying.addListener(() async {
      if (isPlaying.value) {
        await play();
      } else {
        await pause();
      }
    });

    // Listen to player state changes
    playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (isDisposing) return;

      if (playerState.processingState == ProcessingState.completed) {
        if (isPlaying.value) {
          analyticsManager.storeAction('lesson_completed', documentID);
          // Notify completion
          onLessonCompleted?.call();
        }
        stop();
      }
    });

    // Listen to current index changes
    currentIndexSubscription = player.currentIndexStream.listen((index) {
      if (isDisposing) return;

      // Notify index change
      if (index != null) {
        _logNowPlayingFile(index);
        onTrackChanged?.call(index);
      }
    });

    positionDataStream = _buildPositionDataStream().asBroadcastStream();

    // Index: commit previous segment's decoded length (avoids stale duration+index pairs).
    _decoderIndexSubscription = player.currentIndexStream.listen((idx) {
      if (isDisposing) return;
      if (!playlistInitialized || trackDurations.isEmpty) return;
      if (idx == null || idx < 0 || idx >= trackDurations.length) return;
      if (_lastDecoderIndex != null && idx != _lastDecoderIndex) {
        if (_lastDurationForIndex > Duration.zero) {
          _commitTrackDurationFromDecoder(
              _lastDecoderIndex!, _lastDurationForIndex);
        }
        _lastDurationForIndex = Duration.zero;
      }
      _lastDecoderIndex = idx;
    });

    _decoderDurationSubscription = player.durationStream.listen((dur) {
      if (isDisposing) return;
      if (!playlistInitialized || trackDurations.isEmpty) return;
      final idx = player.currentIndex;
      if (idx == null || idx < 0 || idx >= trackDurations.length) return;
      if (dur == null || dur <= Duration.zero) return;
      _lastDurationForIndex = dur;
      _commitTrackDurationFromDecoder(idx, dur);
    });

    _playbackWatchdog =
        Timer.periodic(_watchdogInterval, (_) => _playbackWatchdogTick());
  }

  void _resetDecoderSyncState() {
    _lastDecoderIndex = null;
    _lastDurationForIndex = Duration.zero;
  }

  void _commitTrackDurationFromDecoder(int index, Duration decoded) {
    if (index < 0 || index >= trackDurations.length) return;
    if (decoded <= Duration.zero) return;
    final prev = trackDurations[index];
    final merged = decoded > prev ? decoded : prev;
    if (merged == prev) return;
    trackDurations[index] = merged;
    _recomputeTotalDurationsFromTrackList();
  }

  void _recomputeTotalDurationsFromTrackList() {
    _trackStartOffsets = _buildTrackStartOffsets(trackDurations);
    final sum = trackDurations.fold(Duration.zero, (a, b) => a + b);
    totalDuration.value = sum;
  }

  List<Duration> _buildTrackStartOffsets(List<Duration> durations) {
    final offsets = <Duration>[];
    var running = Duration.zero;
    for (final duration in durations) {
      offsets.add(running);
      running += duration;
    }
    return offsets;
  }

  void _playbackWatchdogTick() {
    if (isDisposing || !playlistInitialized || !isPlaying.value) return;
    if (playlist.children.isEmpty) return;

    final state = player.playerState;
    final idx = player.currentIndex ?? 0;
    final pos = player.position;
    final dur = player.duration;

    if (idx != _watchdogPlaylistIndex) {
      _watchdogPlaylistIndex = idx;
      _recoveryAttemptsForSegment = 0;
      _watchdogLastPosition = pos;
      _watchdogLastProgressAt = DateTime.now();
      _bufferingOrLoadingSince = null;
      _endOfTrackHangSince = null;
      return;
    }

    if (_watchdogLastPosition != null) {
      const advance = Duration(milliseconds: 80);
      if ((pos - _watchdogLastPosition!).abs() > advance) {
        _recoveryAttemptsForSegment = 0;
        _watchdogLastProgressAt = DateTime.now();
      }
    }
    _watchdogLastPosition = pos;

    final waitingOnStream = state.processingState == ProcessingState.buffering ||
        state.processingState == ProcessingState.loading;
    if (waitingOnStream) {
      _bufferingOrLoadingSince ??= DateTime.now();
      if (DateTime.now().difference(_bufferingOrLoadingSince!) >
          _bufferingTimeout) {
        _bufferingOrLoadingSince = null;
        unawaited(_recoverStuckPlayback('buffer'));
      }
      return;
    }
    _bufferingOrLoadingSince = null;

    final nearEndOfCurrentItem = dur != null &&
        dur > Duration.zero &&
        pos >= dur - const Duration(milliseconds: 200);
    if (nearEndOfCurrentItem && player.hasNext) {
      _endOfTrackHangSince ??= DateTime.now();
      if (DateTime.now().difference(_endOfTrackHangSince!) >
          _endOfTrackHangThreshold) {
        _endOfTrackHangSince = null;
        unawaited(_skipToNextAfterEndHang());
      }
      return;
    }
    _endOfTrackHangSince = null;

    if (!state.playing) return;
    if (state.processingState != ProcessingState.ready) return;

    final lastAdv = _watchdogLastProgressAt;
    if (lastAdv == null) return;
    if (nearEndOfCurrentItem) return;

    if (DateTime.now().difference(lastAdv) > _positionStallThreshold) {
      unawaited(_recoverStuckPlayback('stall'));
    }
  }

  /// Skip when the current item has ended but the concat source did not advance.
  Future<void> _skipToNextAfterEndHang() async {
    if (isDisposing || !isPlaying.value || _recoveryInFlight) return;
    if (!player.hasNext) return;
    _recoveryInFlight = true;
    try {
      if (kDebugMode) {
        debugPrint(
            '[AudioPlayer] end-of-segment hang: seekToNext doc=$documentID');
      }
      await player.seekToNext();
      await player.play();
      _watchdogLastProgressAt = DateTime.now();
      analyticsManager.storeAction('audio_playback_end_hang_skip_next', documentID);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AudioPlayer] seekToNext after end hang failed: $e');
      }
    } finally {
      _recoveryInFlight = false;
    }
  }

  /// Retry from start of current segment up to [_maxSegmentRetries], then [seekToNext].
  Future<void> _recoverStuckPlayback(String reason) async {
    if (isDisposing || !isPlaying.value || _recoveryInFlight) return;
    _recoveryInFlight = true;
    try {
      final idx = player.currentIndex ?? 0;

      if (_recoveryAttemptsForSegment < _maxSegmentRetries) {
        _recoveryAttemptsForSegment++;
        if (kDebugMode) {
          debugPrint(
              '[AudioPlayer] stuck ($reason): retry $_recoveryAttemptsForSegment/$_maxSegmentRetries at index $idx doc=$documentID');
        }
        try {
          await player.seek(Duration.zero, index: idx);
          await player.play();
          _watchdogLastProgressAt = DateTime.now();
          _bufferingOrLoadingSince = null;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AudioPlayer] stuck retry seek failed: $e');
          }
        }
        analyticsManager.storeAction('audio_playback_stuck_retry',
            '${documentID}_i${idx}_r${_recoveryAttemptsForSegment}_$reason');
        return;
      }

      if (player.hasNext) {
        if (kDebugMode) {
          debugPrint(
              '[AudioPlayer] stuck: skipping to next after retries doc=$documentID');
        }
        _recoveryAttemptsForSegment = 0;
        try {
          await player.seekToNext();
          await player.play();
          _watchdogLastProgressAt = DateTime.now();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AudioPlayer] seekToNext after stuck failed: $e');
          }
        }
        analyticsManager.storeAction(
            'audio_playback_stuck_skip_next', '${documentID}_from_$idx');
      } else {
        if (kDebugMode) {
          debugPrint(
              '[AudioPlayer] stuck on last segment; stopping doc=$documentID');
        }
        isPlaying.value = false;
        analyticsManager.storeAction(
            'audio_playback_stuck_last_segment_stop', documentID);
      }
    } finally {
      _recoveryInFlight = false;
    }
  }

  Stream<PositionData> _buildPositionDataStream() {
    final periodicStream = Stream.periodic(const Duration(milliseconds: 50));

    return Rx.combineLatest4<Duration, Duration, int, dynamic, PositionData>(
      player.positionStream,
      player.durationStream.whereType<Duration>(),
      player.currentIndexStream
          .whereType<int>()
          .startWith(player.currentIndex ?? 0),
      periodicStream.startWith(null),
      (position, duration, index, _) {
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        final Duration clampedInTrack = duration > Duration.zero &&
                position > duration
            ? duration
            : position;
        Duration totalPosition = cumulativeDuration + clampedInTrack;

        return PositionData(
            clampedInTrack, totalDuration.value, totalPosition);
      },
    ).distinct((prev, current) =>
        (prev.cumulativePosition.inMilliseconds ~/ 50) ==
        (current.cumulativePosition.inMilliseconds ~/ 50));
  }

  /// Debug log for which playlist file is currently playing (console in `flutter run`).
  void _logNowPlayingFile(int index) {
    if (!kDebugMode) return;
    if (index < 0 || index >= playlist.children.length) {
      debugPrint('[AudioPlayer] now playing: index $index (out of range)');
      return;
    }
    final audioSource = playlist.children[index];
    if (audioSource is UriAudioSource) {
      final uri = audioSource.uri.toString();
      final parts = uri.split('/');
      final fileName =
          parts.isNotEmpty ? parts.last.split('?').first : uri;
      debugPrint(
          '[AudioPlayer] now playing: $fileName  [index=$index doc=$documentID]');
    } else {
      debugPrint(
          '[AudioPlayer] now playing: index=$index (${audioSource.runtimeType}) doc=$documentID');
    }
  }

  // Callback for lesson completion
  Function? onLessonCompleted;

  // Callback for track changes
  Function(int)? onTrackChanged;

  // Initialize playlist with audio sources
  Future<void> initializePlaylist(List<AudioSource> audioSources) async {
    if (playlistInitialized || isDisposing) {
      print(
          "Skipping playlist initialization: already initialized or disposing.");
      return;
    }

    if (audioSources.isNotEmpty) {
      playlist = ConcatenatingAudioSource(
          useLazyPreparation: false, children: audioSources);
      await player.setAudioSource(playlist).catchError((error) {
        print("Error setting audio source: $error");
        return null;
      });

      if (!isDisposing) {
        playlistInitialized = true;
      }
    } else {
      print("No valid URLs available to initialize the playlist.");
    }
  }

  Future<void> playFirstTrack() async {
    await player.playerStateStream
        .where((state) => state.processingState == ProcessingState.ready)
        .first;

    isPlaying.value = true;
  }

  Future<void> loadFirstTrack() async {
    await player.playerStateStream
        .where((state) => state.processingState == ProcessingState.ready)
        .first;
  }

  // Update playlist with new audio sources
  Future<void> updatePlaylist(List<AudioSource> newAudioSources) async {
    if (isDisposing) return;

    await playlist.clear();
    await playlist.addAll(newAudioSources);
  }

  // Add tracks to existing playlist
  Future<void> addToPlaylist(List<AudioSource> newTracks) async {
    if (isDisposing) return;
    await playlist.addAll(newTracks);
  }

  // Play audio
  Future<void> play() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('savedPosition_${documentID}_$userID');
    final savedTrackName =
        prefs.getString('savedTrackName_${documentID}_$userID');

    if (savedPosition != null &&
        savedTrackName != null &&
        savedTrackName.isNotEmpty) {
      // Find the index of the saved track name in the playlist
      int? trackIndex;
      for (int i = 0; i < playlist.children.length; i++) {
        final audioSource = playlist.children[i];
        if (audioSource is UriAudioSource) {
          final uri = audioSource.uri.toString();
          final parts = uri.split('/');
          if (parts.isNotEmpty) {
            final trackName = parts.last.split('?').first;
            if (trackName == savedTrackName) {
              trackIndex = i;
              break;
            }
          }
        }
      }

      if (trackIndex != null) {
        await player.seek(Duration(milliseconds: savedPosition),
            index: trackIndex);
      }
    }
    player.play();

    // Show ad for non-premium users every time they start playing
    // Skip showing ads on all platforms
    // if (!kIsWeb && !hasPremium && !hasShownInitialAd) {
    //   hasShownInitialAd = true; // Prevent showing ad multiple times in same session
    //   await AdService.showInterstitialAd(
    //     onAdShown: () async {
    //       isPlaying.value = false;
    //     },
    //     onAdDismissed: () async {
    //       isPlaying.value = true;
    //     },
    //   );
    // }
  }

  // Pause audio
  Future<void> pause({bool analyticsOn = true}) async {
    await _savePlayerPosition();
    player.pause();
  }

  // Stop audio
  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('savedPosition_${documentID}_$userID');
    prefs.remove('savedTrackName_${documentID}_$userID');
    prefs.remove("now_playing_${documentID}_$userID");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_$userID");

    if (nowPlayingList != null) {
      nowPlayingList.remove(documentID);
      await prefs.setStringList("now_playing_$userID", nowPlayingList);
    }

    player.stop();
    player.seek(Duration.zero, index: 0);
    isPlaying.value = false;
    currentTrackName = null;
  }

  // Save player position
  Future<void> _savePlayerPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    int currentPosition = positionData.inMilliseconds;
    int currentIndex = player.currentIndex ?? 0;

    // Get the current track name from the playlist
    if (currentIndex >= 0 && currentIndex < playlist.children.length) {
      final audioSource = playlist.children[currentIndex];
      if (audioSource is UriAudioSource) {
        // Extract track name from the URI
        final uri = audioSource.uri.toString();
        final parts = uri.split('/');
        if (parts.isNotEmpty) {
          currentTrackName =
              parts.last.split('?').first; // Remove query parameters

          // If current track is a break track, save the previous track name instead
          if (currentTrackName == 'one_second_break.mp3' ||
              currentTrackName == 'five_second_break.mp3') {
            // Get the previous track if it exists
            if (currentIndex > 0) {
              final prevAudioSource = playlist.children[currentIndex - 1];
              if (prevAudioSource is UriAudioSource) {
                final prevUri = prevAudioSource.uri.toString();
                final prevParts = prevUri.split('/');
                if (prevParts.isNotEmpty) {
                  currentTrackName = prevParts.last.split('?').first;
                  // Adjust the position to be at the end of the previous track
                  currentPosition =
                      cumulativeDurationUpTo(currentIndex - 1).inMilliseconds;
                }
              }
            }
          }
        }
      }
    }

    await prefs.setInt('savedPosition_${documentID}_$userID', currentPosition);
    await prefs.setString(
        'savedTrackName_${documentID}_$userID', currentTrackName ?? '');
    await prefs.setBool("now_playing_${documentID}_$userID", true);

    final nowPlayingKey = "now_playing_$userID";
    final nowPlayingList = prefs.getStringList(nowPlayingKey) ?? [];
    if (!nowPlayingList.contains(documentID)) {
      nowPlayingList.add(documentID);
    }
    await prefs.setStringList(nowPlayingKey, nowPlayingList);
  }

  // Get saved position
  Future<int> getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition =
        prefs.getInt('savedPosition_${documentID}_$userID') ?? 0;
    final savedTrackName =
        prefs.getString('savedTrackName_${documentID}_$userID') ?? '';

    if (savedTrackName.isNotEmpty) {
      // Find the index of the saved track name in the playlist
      int? trackIndex;
      for (int i = 0; i < playlist.children.length; i++) {
        final audioSource = playlist.children[i];
        if (audioSource is UriAudioSource) {
          final uri = audioSource.uri.toString();
          final parts = uri.split('/');
          if (parts.isNotEmpty) {
            final trackName = parts.last.split('?').first;
            if (trackName == savedTrackName) {
              trackIndex = i;
              break;
            }
          }
        }
      }

      if (trackIndex != null) {
        final position =
            savedPosition + cumulativeDurationUpTo(trackIndex).inMilliseconds;
        return position;
      }
    }

    return savedPosition;
  }

  int _safePlaylistIndex(int index) {
    if (index < 0) return 0;
    int max = index;
    if (trackDurations.isNotEmpty && max >= trackDurations.length) {
      max = trackDurations.length - 1;
    }
    if (playlist.children.isNotEmpty && max >= playlist.children.length) {
      max = playlist.children.length - 1;
    }
    return max;
  }

  // Calculate cumulative duration up to a specific index
  Duration cumulativeDurationUpTo(int currentIndex) {
    final idx = _safePlaylistIndex(currentIndex);
    if (idx <= 0) return Duration.zero;
    if (_trackStartOffsets.length == trackDurations.length &&
        idx < _trackStartOffsets.length) {
      return _trackStartOffsets[idx];
    }
    return trackDurations
        .take(idx)
        .fold(Duration.zero, (total, d) => total + d);
  }

  // Get current position synchronously for immediate UI updates
  Duration getCurrentPosition() {
    final currentIndex = _safePlaylistIndex(player.currentIndex ?? 0);
    final currentPosition = player.position;
    final cumulativeDuration = cumulativeDurationUpTo(currentIndex);
    return cumulativeDuration + currentPosition;
  }

  // Find track index for a specific position
  int findTrackIndexForPosition(double milliseconds) {
    if (trackDurations.isEmpty) return 0;
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) return i;
    }
    int last = trackDurations.length - 1;
    final maxPlaylist = playlist.children.length - 1;
    if (maxPlaylist >= 0 && last > maxPlaylist) {
      last = maxPlaylist;
    }
    return last;
  }

  // Get current track index based on position for better synchronization
  int getCurrentTrackIndex() {
    final currentIndex = player.currentIndex;
    if (currentIndex != null) {
      return _safePlaylistIndex(currentIndex);
    }
    return findTrackIndexForPosition(player.position.inMilliseconds.toDouble());
  }

  // Set track durations (optionally the file names aligned 1:1 with playlist indices)
  void setTrackDurations(List<Duration> durations,
      {List<dynamic>? alignedFileNames}) {
    if (alignedFileNames != null) {
      final nextNames = List<dynamic>.from(alignedFileNames);
      final mergedDurations = <Duration>[];

      for (int i = 0; i < nextNames.length; i++) {
        final incoming = i < durations.length ? durations[i] : Duration.zero;
        final hasSameTrackAtIndex = i < playlistFileNames.length &&
            playlistFileNames[i].toString() == nextNames[i].toString();

        if (hasSameTrackAtIndex && i < trackDurations.length) {
          final existing = trackDurations[i];
          mergedDurations.add(existing > incoming ? existing : incoming);
        } else {
          mergedDurations.add(incoming);
        }
      }

      playlistFileNames = nextNames;
      trackDurations = mergedDurations;
    } else if (trackDurations.length == durations.length &&
        trackDurations.isNotEmpty) {
      trackDurations = List<Duration>.generate(
        durations.length,
        (index) => trackDurations[index] > durations[index]
            ? trackDurations[index]
            : durations[index],
      );
    } else {
      trackDurations = durations;
    }
    _resetDecoderSyncState();
    _recomputeTotalDurationsFromTrackList();
  }

  // Set final total duration
  void setFinalTotalDuration() {
    finalTotalDuration.value =
        trackDurations.fold(Duration.zero, (total, d) => total + d);
  }

  void clearFinalTotalDuration() {
    finalTotalDuration.value = Duration.zero;
  }

  // Dispose resources
  void dispose() {
    isDisposing = true;

    _playbackWatchdog?.cancel();
    _playbackWatchdog = null;

    playerStateSubscription?.cancel();
    currentIndexSubscription?.cancel();
    _decoderDurationSubscription?.cancel();
    _decoderIndexSubscription?.cancel();

    isPlaying.dispose();
    playbackSpeed.dispose();
    totalDuration.dispose();
    finalTotalDuration.dispose();

    player.dispose();
  }
}
