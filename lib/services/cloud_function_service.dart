import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudFunctionService {
  static Future<void> generateNicknameAudio(String text, String userId) async {
    final url = 'https://europe-west1-noble-descent-420612.cloudfunctions.net/generate_nickname_audio';
    final response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'text': text,
        'user_id': userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate nickname audio');
    }
  }
}
