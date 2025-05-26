import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/audio_player_service.dart';

class ParakeetAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AudioPlayerService? _audioPlayerService;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _currentIndexSubscription;

  // Initialize the audio handler with the audio player service
  void initialize(AudioPlayerService audioPlayerService) {
    _audioPlayerService = audioPlayerService;
    _setupListeners();
  }

  void _setupListeners() {
    if (_audioPlayerService == null) return;

    // Listen to player state changes
    _playerStateSubscription = _audioPlayerService!.player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: isPlaying,
        speed: _audioPlayerService!.playbackSpeed.value,
        queueIndex: _audioPlayerService!.player.currentIndex,
      ));
    });

    // Listen to position changes
    _positionSubscription = _audioPlayerService!.player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayerService!.player.durationStream.listen((duration) {
      if (duration != null) {
        final currentMediaItem = mediaItem.value;
        if (currentMediaItem != null) {
          mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }
    });

    // Listen to current index changes
    _currentIndexSubscription = _audioPlayerService!.player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
        playbackState.add(playbackState.value.copyWith(queueIndex: index));
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // Update the current media item and queue
  void setCurrentMediaItem(String title, String? artist, Duration? duration, String? artUri) {
    final newMediaItem = MediaItem(
      id: 'parakeet_lesson',
      album: 'Parakeet Language Learning',
      title: title,
      artist: artist ?? 'Parakeet',
      duration: duration,
      artUri: artUri != null ? Uri.parse(artUri) : null,
    );

    mediaItem.add(newMediaItem);
    queue.add([newMediaItem]);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> play() async {
    if (_audioPlayerService != null) {
      _audioPlayerService!.isPlaying.value = true;
    }
  }

  @override
  Future<void> pause() async {
    if (_audioPlayerService != null) {
      _audioPlayerService!.isPlaying.value = false;
    }
  }

  @override
  Future<void> stop() async {
    if (_audioPlayerService != null) {
      await _audioPlayerService!.stop();
    }

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_audioPlayerService != null) {
      final trackIndex = _audioPlayerService!.findTrackIndexForPosition(position.inMilliseconds.toDouble());
      final trackPosition = Duration(
        milliseconds: position.inMilliseconds - _audioPlayerService!.cumulativeDurationUpTo(trackIndex).inMilliseconds,
      );
      await _audioPlayerService!.player.seek(trackPosition, index: trackIndex);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_audioPlayerService != null && _audioPlayerService!.player.hasNext) {
      await _audioPlayerService!.player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audioPlayerService != null && _audioPlayerService!.player.hasPrevious) {
      await _audioPlayerService!.player.seekToPrevious();
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_audioPlayerService != null) {
      _audioPlayerService!.playbackSpeed.value = speed;
    }

    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_audioPlayerService != null && index >= 0 && index < _audioPlayerService!.playlist.children.length) {
      await _audioPlayerService!.player.seek(Duration.zero, index: index);
    }
  }

  // Custom action to set volume
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'setVolume':
        final volume = extras?['volume'] as double?;
        if (volume != null && _audioPlayerService != null) {
          await _audioPlayerService!.player.setVolume(volume);
        }
        break;
    }
  }

  // Clean up resources
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentIndexSubscription?.cancel();
  }
}
