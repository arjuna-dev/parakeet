import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/ad_service.dart';
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
  Duration totalDuration = Duration.zero;
  Duration finalTotalDuration = Duration.zero;
  String? currentTrackName; // Track name of the current audio file

  StreamSubscription? playerStateSubscription;
  StreamSubscription? currentIndexSubscription;

  AudioPlayerService({
    required this.documentID,
    required this.userID,
    required this.hasPremium,
  }) {
    player = AudioPlayer();
    playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: []);
    analyticsManager = AnalyticsManager(userID, documentID);

    // Initialize player
    _init();
  }

  void _init() {
    player.setSpeed(playbackSpeed.value);
    analyticsManager.loadAnalyticsFromFirebase();

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
          analyticsManager.storeAnalytics(documentID, 'completed');
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
        onTrackChanged?.call(index);
      }
    });
  }

  // Callback for lesson completion
  Function? onLessonCompleted;

  // Callback for track changes
  Function(int)? onTrackChanged;

  // Initialize playlist with audio sources
  Future<void> initializePlaylist(List<AudioSource> audioSources) async {
    if (playlistInitialized || isDisposing) {
      print("Skipping playlist initialization: already initialized or disposing.");
      return;
    }

    if (audioSources.isNotEmpty) {
      playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: audioSources);
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
    await player.playerStateStream.where((state) => state.processingState == ProcessingState.ready).first;

    isPlaying.value = true;
  }

  Future<void> loadFirstTrack() async {
    await player.playerStateStream.where((state) => state.processingState == ProcessingState.ready).first;
    positionDataStream.listen((positionData) {
      positionData.position = const Duration(milliseconds: 0);
    });
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
    final savedTrackName = prefs.getString('savedTrackName_${documentID}_$userID');

    if (savedPosition != null && savedTrackName != null && savedTrackName.isNotEmpty) {
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
        await player.seek(Duration(milliseconds: savedPosition), index: trackIndex);
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

    analyticsManager.storeAnalytics(documentID, 'play');
  }

  // Pause audio
  Future<void> pause({bool analyticsOn = true}) async {
    await _savePlayerPosition();
    player.pause();

    if (analyticsOn) {
      analyticsManager.storeAnalytics(documentID, 'pause');
    }
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
          currentTrackName = parts.last.split('?').first; // Remove query parameters

          // If current track is a break track, save the previous track name instead
          if (currentTrackName == 'one_second_break.mp3' || currentTrackName == 'five_second_break.mp3') {
            // Get the previous track if it exists
            if (currentIndex > 0) {
              final prevAudioSource = playlist.children[currentIndex - 1];
              if (prevAudioSource is UriAudioSource) {
                final prevUri = prevAudioSource.uri.toString();
                final prevParts = prevUri.split('/');
                if (prevParts.isNotEmpty) {
                  currentTrackName = prevParts.last.split('?').first;
                  // Adjust the position to be at the end of the previous track
                  currentPosition = cumulativeDurationUpTo(currentIndex - 1).inMilliseconds;
                }
              }
            }
          }
        }
      }
    }

    await prefs.setInt('savedPosition_${documentID}_$userID', currentPosition);
    await prefs.setString('savedTrackName_${documentID}_$userID', currentTrackName ?? '');
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
    final savedPosition = prefs.getInt('savedPosition_${documentID}_$userID') ?? 0;
    final savedTrackName = prefs.getString('savedTrackName_${documentID}_$userID') ?? '';

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
        final position = savedPosition + cumulativeDurationUpTo(trackIndex).inMilliseconds;
        return position;
      }
    }

    return savedPosition;
  }

  // Calculate cumulative duration up to a specific index
  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations.take(currentIndex).fold(Duration.zero, (total, d) => total + d);
  }

  // Get current position synchronously for immediate UI updates
  Duration getCurrentPosition() {
    final currentIndex = player.currentIndex ?? 0;
    final currentPosition = player.position;
    final cumulativeDuration = cumulativeDurationUpTo(currentIndex);
    return cumulativeDuration + currentPosition;
  }

  // Find track index for a specific position
  int findTrackIndexForPosition(double milliseconds) {
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) return i;
    }
    return trackDurations.length - 1;
  }

  // Get current track index based on position for better synchronization
  int getCurrentTrackIndex() {
    final currentIndex = player.currentIndex ?? 0;
    final currentPosition = player.position;
    final cumulativeDuration = cumulativeDurationUpTo(currentIndex);
    final totalPosition = cumulativeDuration + currentPosition;

    // Use position-based tracking for more accurate results
    return findTrackIndexForPosition(totalPosition.inMilliseconds.toDouble());
  }

  // Position data stream for the slider
  Stream<PositionData> get positionDataStream {
    int lastIndex = -1;

    // Create a periodic stream that emits every 50ms for smoother updates
    final periodicStream = Stream.periodic(const Duration(milliseconds: 50));

    return Rx.combineLatest4<Duration, Duration, int, dynamic, PositionData?>(
      // Use a more frequent position stream and don't filter by playing state
      // This allows smooth updates even when paused for dragging
      player.positionStream,
      player.durationStream.whereType<Duration>(),
      player.currentIndexStream.whereType<int>().startWith(0),
      periodicStream.startWith(null), // Add periodic updates for smoother animation
      (position, duration, index, _) {
        bool hasIndexChanged = index != lastIndex;
        lastIndex = index;
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        Duration totalPosition = cumulativeDuration + position;

        if (position <= duration) {
          return PositionData(position, totalDuration, totalPosition);
        }
        return null;
      },
    )
        .where((positionData) => positionData != null)
        .cast<PositionData>()
        // Use a less restrictive distinct to allow more frequent updates for smoother animation
        .distinct((prev, current) => (prev.cumulativePosition.inMilliseconds ~/ 50) == (current.cumulativePosition.inMilliseconds ~/ 50));
  }

  // Set track durations
  void setTrackDurations(List<Duration> durations) {
    trackDurations = durations;
    totalDuration = durations.fold(Duration.zero, (total, d) => total + d);
  }

  // Set final total duration
  void setFinalTotalDuration() {
    finalTotalDuration = trackDurations.fold(Duration.zero, (total, d) => total + d);
  }

  // Dispose resources
  void dispose() {
    isDisposing = true;

    playerStateSubscription?.cancel();
    currentIndexSubscription?.cancel();

    isPlaying.dispose();
    playbackSpeed.dispose();

    player.dispose();
  }
}
