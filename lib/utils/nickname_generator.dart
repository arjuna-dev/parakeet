import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:parakeet/utils/greetings_list_all_languages.dart';
import 'constants.dart';

/// A helper function to check and update the user's daily call count for
/// generating a nickname, enforcing a limit (e.g., 10/day).
///
/// Returns `true` if the user can proceed with the nickname generation,
/// otherwise `false`.
Future<bool> _checkAndUpdateCallCount() async {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final today = "${DateTime.now().year}"
      "-${DateTime.now().month.toString().padLeft(2, '0')}"
      "-${DateTime.now().day.toString().padLeft(2, '0')}";

  try {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('api_call_count').doc('generate_nickname');

      final userDocSnapshot = await transaction.get(userDocRef);

      if (!userDocSnapshot.exists) {
        // If document doesn't exist, create it with count 1
        transaction.set(userDocRef, {
          'last_call_date': today,
          'call_count': 1,
        });
        return true;
      } else {
        // Document exists, check count and date
        if (userDocSnapshot.get('last_call_date') == today) {
          final callCount = userDocSnapshot.get('call_count') as int;
          if (callCount >= 10) {
            // Limit reached
            return false;
          } else {
            // Increment count
            transaction.update(userDocRef, {
              'call_count': FieldValue.increment(1),
            });
            return true;
          }
        } else {
          // New day, reset count
          transaction.set(userDocRef, {
            'last_call_date': today,
            'call_count': 1,
          });
          return true;
        }
      }
    });
  } catch (e) {
    print('Error in transaction: $e');
    return false;
  }
}

/// Saves the given [nickname] to the current user's Firestore document.
Future<void> _saveNicknameToFirestore(String nickname) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  await userDocRef.set(
    {'nickname': nickname},
    SetOptions(merge: true),
  );
}

/// (Optional) Fetches and plays the generated audio file for the given [userIdN].
///
/// You can remove this entire function if you do not want to automatically
/// play audio. Just skip calling this function in [generateNicknameAudioFiles].
Future<void> _fetchAndPlayAudio(String userIdN, AudioPlayer player) async {
  bool audioFetched = false;

  while (!audioFetched) {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioUrl = 'https://storage.googleapis.com/user_nicknames/${userIdN}_nickname.mp3?ts=$timestamp';

      // Make sure the file exists before setting up the audio player
      final exists = await urlExists(audioUrl);
      if (!exists) {
        // Wait a bit and try again
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      await player.setUrl(audioUrl);
      audioFetched = true;
      await player.play();
    } catch (e) {
      // If file not yet available or network error, retry after delay
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}

/// Generates all remaining greetings for the given [nickname], skipping
/// the [usedGreetingIndex].
///
/// This function calls the cloud function to generate the audio files
/// for each greeting but does not wait for them all to complete.
Future<void> _generateRemainingGreetings({
  required String nickname,
  required String language,
  required int usedGreetingIndex,
}) async {
  try {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final selectedGreetings = greetingsList[language] ?? [];

    for (int i = 0; i < selectedGreetings.length; i++) {
      if (i == usedGreetingIndex) continue; // Skip the greeting we used
      final greeting = selectedGreetings[i];
      final userIdN = "${userId}_${i + 1}";

      // Fire off the request without awaiting (runs in the background)
      unawaited(
        CloudFunctionService.generateNicknameAudio(
          "$greeting $nickname!",
          userId,
          userIdN,
          language,
        ),
      );
    }
  } catch (e) {
    // This handles errors that might occur while queueing remaining greetings.
    print("Error queuing remaining greetings: $e");
  }
}

Future<String?> fetchCurrentNickname() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data.containsKey('nickname') && data['nickname'].isNotEmpty) {
        return data['nickname'];
      }
    }
  }
  return null;
}

/// This function encapsulates the entire logic for generating a nickname,
/// creating the audio files, and optionally playing the audio.
///
/// [nickname] - the desired nickname (e.g. "John")
/// [language] - the language selected (must match a key in `greetingsList`)
/// [shouldPlayAudio] - set to `true` if you want to play the greeting audio
///
/// Throws an exception if the nickname is empty, the language is invalid,
/// or the daily call limit is reached.
Future<void> generateNicknameAudioFiles({
  required String language,
  bool shouldPlayAudio = false,
}) async {
  final nickname = await fetchCurrentNickname();
  // Basic validations
  if (nickname != null && nickname.trim().isEmpty) {
    print("No nickname stored");
    return;
  }
  if (!greetingsList.containsKey(language)) {
    print('Invalid language: $language');
    return;
  }

  // Check daily call limit
  final canProceed = await _checkAndUpdateCallCount();
  if (!canProceed) {
    print("Daily call limit for nickname generation reached.");
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("No user is logged in.");
  }

  // Generate random greeting
  final selectedGreetings = greetingsList[language]!;
  final usedGreetingIndex = Random().nextInt(selectedGreetings.length);
  final randomGreeting = selectedGreetings[usedGreetingIndex];

  // The audio filename "suffix" to differentiate between multiple greetings
  final userIdN = "${user.uid}_0";

  // Step 1: Generate the nickname audio (main greeting)
  await CloudFunctionService.generateNicknameAudio(
    "$randomGreeting $nickname!",
    user.uid,
    userIdN,
    language,
  );

  // Step 2: (Optional) fetch and play the main greeting audio
  if (shouldPlayAudio) {
    final player = AudioPlayer();
    await _fetchAndPlayAudio(userIdN, player);
    // Dispose of the player when done
    player.dispose();
  }

  // Step 3: Generate the remaining greetings in the background
  _generateRemainingGreetings(
    nickname: nickname!,
    language: language,
    usedGreetingIndex: usedGreetingIndex,
  );

  // If you want a return value to confirm success, you could return a status
  // or simply let this function complete.
  print("Nickname audio generation complete for '$nickname' in $language.");
}

/// A tiny helper to silence the "unawaited" linter warning if you want to
/// fire-and-forget the background calls. Otherwise, you can remove this
/// and just ignore the linter warnings.
void unawaited(Future<void> future) {}
