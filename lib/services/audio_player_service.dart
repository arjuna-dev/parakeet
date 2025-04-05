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
  final bool hasPremium;

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
      print("Skipping playlist initialization");
      return;
    }

    if (audioSources.isNotEmpty) {
      playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: audioSources);
      await player.setAudioSource(playlist).catchError((error) {
        print("Error setting audio source: $error");
        return null;
      });

      if (!isDisposing) {
        await player.playerStateStream.where((state) => state.processingState == ProcessingState.ready).first;
        isPlaying.value = true;
        playlistInitialized = true;
        print("Playlist initialized successfully");
      }
    } else {
      print("No valid URLs available to initialize the playlist.");
    }
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
    print("play() called");
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('savedPosition_${documentID}_$userID');
    final savedTrackIndex = prefs.getInt('savedTrackIndex_${documentID}_$userID');

    print("savedPosition: $savedPosition, savedTrackIndex: $savedTrackIndex");
    if (savedPosition != null && savedTrackIndex != null) {
      print("will now seek to position: $savedPosition, index: $savedTrackIndex");
      await player.seek(Duration(milliseconds: savedPosition), index: savedTrackIndex);
      print("player.currentIndex: ${player.currentIndex}");
    }
    player.play();

    // Show ad for non-premium users every time they start playing
    // Skip showing ads on web platform
    if (!kIsWeb && !hasPremium && !hasShownInitialAd) {
      hasShownInitialAd = true; // Prevent showing ad multiple times in same session
      print("Now showing ad");
      await AdService.showInterstitialAd(
        onAdShown: () async {
          isPlaying.value = false;
        },
        onAdDismissed: () async {
          isPlaying.value = true;
        },
      );
    }

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
    prefs.remove('savedTrackIndex_${documentID}_$userID');
    prefs.remove("now_playing_${documentID}_$userID");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_$userID");

    if (nowPlayingList != null) {
      nowPlayingList.remove(documentID);
      await prefs.setStringList("now_playing_$userID", nowPlayingList);
    }

    player.stop();
    player.seek(Duration.zero, index: 0);
    isPlaying.value = false;
  }

  // Save player position
  Future<void> _savePlayerPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    final currentPosition = positionData.inMilliseconds;
    int currentIndex = player.currentIndex ?? 0;
    print("will now save position: $currentPosition, player.currentIndex: ${player.currentIndex}");
    await prefs.setInt('savedPosition_${documentID}_$userID', currentPosition);
    await prefs.setInt('savedTrackIndex_${documentID}_$userID', currentIndex);
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
    final savedIndex = prefs.getInt('savedTrackIndex_${documentID}_$userID') ?? 0;
    final position = savedPosition + cumulativeDurationUpTo(savedIndex).inMilliseconds;
    return position;
  }

  // Calculate cumulative duration up to a specific index
  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations.take(currentIndex).fold(Duration.zero, (total, d) => total + d);
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

  // Position data stream for the slider
  Stream<PositionData> get positionDataStream {
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
