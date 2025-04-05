import 'package:cloud_firestore/cloud_firestore.dart';

class AudioDurationService {
  final String documentID;
  final String nativeLanguage;

  Map<String, dynamic> audioDurations = {};
  Future<Map<String, dynamic>>? cachedAudioDurations;

  AudioDurationService({
    required this.documentID,
    required this.nativeLanguage,
  }) {
    cachedAudioDurations = getAudioDurationsFromNarratorStorage();
  }

  /// Calculate total duration and update track durations
  Future<List<Duration>> calculateTrackDurations(List<dynamic> script) async {
    List<Duration> trackDurations = List<Duration>.filled(script.length, Duration.zero);

    // Get audio durations from Firestore
    await _loadAudioDurations();

    if (audioDurations.isNotEmpty) {
      for (int i = 0; i < script.length; i++) {
        String fileName = script[i];
        double durationInSeconds = audioDurations[fileName] ?? 0.0;
        Duration duration = Duration(milliseconds: (durationInSeconds * 1000).round());
        trackDurations[i] = duration;
      }
    }

    return trackDurations;
  }

  /// Load audio durations from Firestore
  Future<void> _loadAudioDurations() async {
    // Get file durations from Firestore
    CollectionReference colRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentID).collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      audioDurations.addAll(querySnap.docs[0].data() as Map<String, dynamic>);
    }

    // Add narrator audio durations
    audioDurations.addAll(await getAudioDurationsFromNarratorStorage());
  }

  /// Get audio durations from narrator storage
  Future<Map<String, dynamic>> getAudioDurationsFromNarratorStorage() async {
    if (cachedAudioDurations != null) {
      return cachedAudioDurations!;
    }

    CollectionReference colRef = FirebaseFirestore.instance.collection('narrator_audio_files_durations/google_tts/narrator_$nativeLanguage');
    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      DocumentSnapshot firstDoc = querySnap.docs.first;
      return firstDoc.data() as Map<String, dynamic>;
    }
    return {};
  }

  /// Build a map of playlist indices to file names for speech comparison
  Map<int, String> buildFilesToCompare(List<dynamic> script) {
    Map<int, String> filesToCompare = {};
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
            filesToCompare[i - occurrences - 1] = fileName;
            occurrences++;
          } else {
            print('Warning: Expected a \$-prefixed string before five_second_break at index $i');
          }
        }
      }
    }

    return filesToCompare;
  }
}
