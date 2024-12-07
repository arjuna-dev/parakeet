import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudFunctionService {
  static Future<void> generateNicknameAudio(String text, String userId, String useridN) async {
    const url = 'https://europe-west1-noble-descent-420612.cloudfunctions.net/generate_nickname_audio';
    final response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'text': text,
        'user_id': userId,
        'user_id_N': useridN,
      }),
    );

    if (response.statusCode == 429) {
      // TODO: show snackbar explaining that the user has reached the limit of nickname generation for today
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to generate nickname audio');
    }
  }
}
