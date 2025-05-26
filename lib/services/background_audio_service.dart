import 'package:audio_service/audio_service.dart';
import 'package:parakeet/services/audio_handler.dart';
import 'package:parakeet/services/audio_player_service.dart';

class BackgroundAudioService {
  static ParakeetAudioHandler? _audioHandler;
  static bool _isInitialized = false;

  // Initialize the audio service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioHandler = await AudioService.init(
        builder: () => ParakeetAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.parakeet.audio.channel',
          androidNotificationChannelName: 'Parakeet Audio Playback',
          androidNotificationChannelDescription: 'Audio playback controls for Parakeet language learning',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          artDownscaleWidth: 80,
          artDownscaleHeight: 80,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
          preloadArtwork: false,
        ),
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio service: $e');
    }
  }

  // Connect an audio player service to the background audio handler
  static void connectAudioPlayerService(AudioPlayerService audioPlayerService, String lessonTitle) {
    if (_audioHandler != null) {
      _audioHandler!.initialize(audioPlayerService);
      _audioHandler!.setCurrentMediaItem(
        lessonTitle,
        'Parakeet Language Learning',
        audioPlayerService.finalTotalDuration,
        null, // You can add artwork URL here if available
      );
    }
  }

  // Update the current lesson information
  static void updateLessonInfo(String title, Duration? duration, String? artworkUrl) {
    if (_audioHandler != null) {
      _audioHandler!.setCurrentMediaItem(title, 'Parakeet', duration, artworkUrl);
    }
  }

  // Get the audio handler instance
  static ParakeetAudioHandler? get audioHandler => _audioHandler;

  // Check if the service is initialized
  static bool get isInitialized => _isInitialized;

  // Dispose the service
  static void dispose() {
    _audioHandler?.dispose();
    _audioHandler = null;
    _isInitialized = false;
  }
}
