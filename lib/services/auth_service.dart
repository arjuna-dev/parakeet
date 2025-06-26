import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> _initializeUserDocument(User user, BuildContext context, {String? signInProvider, String? appleFirstName}) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    if (!userDoc.exists) {
      // Create new user document with sign-in provider info
      Map<String, dynamic> newUserData = {
        'name': user.displayName ?? appleFirstName,
        'email': user.email,
        'premium': false,
        'onboarding_completed': false,
        'sign_in_provider': signInProvider,
      };

      // For Apple Sign In users, pre-populate nickname with their first name to comply with Apple requirements
      if (signInProvider == 'apple.com' && (user.displayName != null || appleFirstName != null)) {
        newUserData['nickname'] = user.displayName ?? appleFirstName;
      }

      await _firestore.collection('users').doc(user.uid).set(newUserData);

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }
    } else if (userData != null) {
      bool needsOnboarding = !userData.containsKey('onboarding_completed') || userData['onboarding_completed'] == false;

      // Update missing fields for existing users
      Map<String, dynamic> updates = {};
      if (!userData.containsKey('onboarding_completed')) {
        updates['onboarding_completed'] = false;
      }
      if (!userData.containsKey('premium')) {
        updates['premium'] = false;
      }
      if (!userData.containsKey('sign_in_provider')) {
        updates['sign_in_provider'] = signInProvider;
      }

      // For existing Apple users, ensure nickname is set to comply with Apple requirements
      if (signInProvider == 'apple.com' && !userData.containsKey('nickname') && (user.displayName != null || appleFirstName != null)) {
        updates['nickname'] = user.displayName ?? appleFirstName;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }

      if (needsOnboarding) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/onboarding');
          return;
        }
      }
    }
  }

  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleSignInAccount = await _googleSignIn.signIn();
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          await _initializeUserDocument(userCredential.user!, context, signInProvider: 'google.com');
        }

        return userCredential.user;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
    }
    return null;
  }

  Future<User?> signInWithApple(BuildContext context) async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        // Extract first name (given name) from Apple credential if available
        String? appleFirstName;
        if (appleCredential.givenName != null && appleCredential.givenName!.isNotEmpty) {
          appleFirstName = appleCredential.givenName!.trim();
        }

        await _initializeUserDocument(
          userCredential.user!,
          context,
          signInProvider: 'apple.com',
          appleFirstName: appleFirstName,
        );
      }

      return userCredential.user;
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Delete the user's data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();

        await user.delete();
      }
    } catch (e) {
      print('Error deleting account: $e');
      rethrow; // Rethrow the error to handle it in the UI
    }
  }
}
