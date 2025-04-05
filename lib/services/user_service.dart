import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  // Function to get user language settings
  static Future<Map<String, String>> getUserLanguageSettings({
    String defaultNativeLanguage = 'English (US)',
    String defaultTargetLanguage = 'German',
    String defaultLanguageLevel = 'Absolute beginner (A1)',
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    try {
      final DocumentSnapshot doc = await firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'nativeLanguage': data['native_language'] ?? defaultNativeLanguage,
          'targetLanguage': data['target_language'] ?? defaultTargetLanguage,
          'languageLevel': data['language_level'] ?? defaultLanguageLevel,
        };
      }
    } catch (e) {
      print('Error fetching user language settings: $e');
    }
    return {
      'nativeLanguage': defaultNativeLanguage,
      'targetLanguage': defaultTargetLanguage,
      'languageLevel': defaultLanguageLevel,
    };
  }
}
