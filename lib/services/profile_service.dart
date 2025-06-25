import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/screens/language_settings_screen.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {};
    }

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      return {
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'premium': userData['premium'] ?? false,
        'native_language': userData['native_language'] ?? 'English (US)',
        'target_language': userData['target_language'] ?? 'German',
        'language_level': userData['language_level'] ?? 'Absolute beginner (A1)',
      };
    }

    return {};
  }

  static Future<bool> navigateToLanguageSettings(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const LanguageSettingsScreen(),
      ),
    );

    // Return true if settings were updated, false otherwise
    return result ?? false;
  }

  static void launchURL(Uri url) async {
    await canLaunchUrl(url) ? await launchUrl(url) : throw 'Could not launch $url';
  }
}
