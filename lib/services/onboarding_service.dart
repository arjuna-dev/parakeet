import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:parakeet/utils/greetings_list_all_languages.dart';
import 'dart:math';
import 'dart:async';

class OnboardingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> saveUserData({
    required String? nativeLanguage,
    required String? nickname,
    required String? targetLanguage,
    required String? languageLevel,
    required Function(bool) setLoading,
    required BuildContext context,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    setLoading(true);

    try {
      // Save user data
      await _firestore.collection('users').doc(user.uid).update({
        'native_language': nativeLanguage,
        'nickname': nickname,
        'target_language': targetLanguage,
        'language_level': languageLevel,
        'onboarding_completed': true,
      });

      // Generate nickname greeting in native language
      if (nickname != null && nickname.isNotEmpty && nativeLanguage != null) {
        final selectedGreetings = greetingsList[nativeLanguage]!;
        final usedGreetingIndex = Random().nextInt(selectedGreetings.length);
        final randomGreeting = selectedGreetings[usedGreetingIndex];
        final userIdN = "${user.uid}_${nativeLanguage}_${usedGreetingIndex + 1}";

        // Generate initial greeting
        await CloudFunctionService.generateNicknameAudio("$randomGreeting $nickname!", user.uid, userIdN, nativeLanguage);
        await fetchAndPlayAudio(userIdN);

        // Generate remaining greetings in background
        unawaited(generateRemainingGreetings(user.uid, nickname, nativeLanguage, usedGreetingIndex));
      }

      return true;
    } catch (e) {
      print('Error saving user data or generating nickname: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving data. Please try again.'),
          ),
        );
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  static Future<void> fetchAndPlayAudio(String useridN) async {
    final player = AudioPlayer();
    bool audioFetched = false;

    while (!audioFetched) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await urlExists(
          'https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp=$timestamp',
        );

        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        await player.setUrl('https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp2=$timestamp2');
        audioFetched = true;
        player.play();
      } catch (e) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  static Future<void> generateRemainingGreetings(String userId, String nickname, String language, int usedIndex) async {
    try {
      final selectedGreetings = greetingsList[language]!;

      // Generate remaining greetings for selected language, skipping the used one
      for (var i = 0; i < selectedGreetings.length; i++) {
        if (i == usedIndex) continue; // Skip the greeting we already generated
        final greeting = selectedGreetings[i];
        final userIdN = "${userId}_${language}_${i + 1}";
        unawaited(CloudFunctionService.generateNicknameAudio("$greeting $nickname!", userId, userIdN, language));
      }
    } catch (e) {
      print("Error generating remaining greetings: $e");
    }
  }

  static Future<bool> urlExists(String url) async {
    try {
      final player = AudioPlayer();
      await player.setUrl(url);
      return true;
    } catch (e) {
      throw Exception('URL does not exist');
    }
  }

  static bool canProceed(int currentPage, String? nativeLanguage, String? nickname, String? targetLanguage, String? languageLevel, bool? notificationsEnabled) {
    switch (currentPage) {
      case 0:
        return nativeLanguage != null;
      case 1:
        return nickname != null && nickname.isNotEmpty;
      case 2:
        return targetLanguage != null;
      case 3:
        return languageLevel != null;
      case 4:
        return notificationsEnabled != null;
      default:
        return false;
    }
  }
}
