import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final player = AudioPlayer();

  // Function to play audio files according to the script order
  Future<void> playAudioFromScript(
      Map<String, dynamic> script, String response_db_id) async {
    try {
      // Iterate over the script to play files in order
      for (var fileName in script["script"]) {
        String fileUrl;
        if (fileName.startsWith("narrator_")) {
          fileUrl =
              "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_english/$fileName.mp3";
        } else {
          fileUrl =
              "https://storage.googleapis.com/all_audio_files/$response_db_id/$fileName.mp3";
        }

        // Load the audio from the URL
        await player.setUrl(fileUrl);

        // Play the audio
        player.play();

        // Wait for the audio to finish before continuing
        await player.playerStateStream.firstWhere(
            (state) => state.processingState == ProcessingState.completed);
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }
}
