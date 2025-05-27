import 'package:audio_service/audio_service.dart';
import 'package:parakeet/services/audio_handler.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class BackgroundAudioService {
  static ParakeetAudioHandler? _audioHandler;
  static bool _isInitialized = false;
  static String? _artworkPath;

  // Initialize the audio service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Prepare artwork file
      await _prepareArtwork();

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
          preloadArtwork: true,
        ),
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio service: $e');
    }
  }

  // Prepare artwork by copying the asset to a file that can be accessed by URI
  static Future<void> _prepareArtwork() async {
    if (_artworkPath != null) return;

    try {
      if (kIsWeb) {
        // Web doesn't need special handling
        _artworkPath = 'assets/parakeet_icon.png';
        return;
      }

      // Load the asset as bytes
      final ByteData data;
      if (Platform.isAndroid) {
        data = await rootBundle.load('assets/parakeet_icon.png');
      } else {
        data = await rootBundle.load('assets/parakeet_icon_ios.png');
      }
      final List<int> bytes = data.buffer.asUint8List();

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/parakeet_icon.png');
      await file.writeAsBytes(bytes);

      // Store the file path
      _artworkPath = file.uri.toString();
      print('Artwork prepared at: $_artworkPath');
    } catch (e) {
      print('Error preparing artwork: $e');
      // Fallback to null
      _artworkPath = null;
    }
  }

  // Connect an audio player service to the background audio handler
  static void connectAudioPlayerService(AudioPlayerService audioPlayerService, String lessonTitle, String? category) {
    if (_audioHandler != null) {
      _audioHandler!.initialize(audioPlayerService);
      _audioHandler!.setCurrentMediaItem(
        lessonTitle,
        'Parakeet Language Learning',
        audioPlayerService.totalDuration,
        _artworkPath,
        category,
      );
    }
  }

  // Update the current lesson information
  static void updateLessonInfo(String title, Duration? duration, String? artworkUrl, String? category) {
    if (_audioHandler != null) {
      _audioHandler!.setCurrentMediaItem(title, 'Parakeet', duration, artworkUrl ?? _artworkPath, category);
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
