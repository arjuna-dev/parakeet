import 'package:parakeet/widgets/trial_modal.dart';
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

  Future<void> _initializeUserDocument(User user, BuildContext context) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    if (!userDoc.exists) {
      // Create new user document
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.displayName,
        'email': user.email,
        'premium': false,
      });
    } else if (userData != null && (!userData.containsKey('premium'))) {
      // Add premium field if it doesn't exist
      await _firestore.collection('users').doc(user.uid).update({
        'premium': false,
      });
    }

    // Show trial modal if user is not premium, and hasUsedTrial field doesn't exist or is false
    if (context.mounted &&
        ((!userDoc.exists) ||
            (userData != null &&
                (!userData.containsKey('premium') ||
                    userData['premium'] == false) &&
                (!userData.containsKey('hasUsedTrial') ||
                    userData['hasUsedTrial'] == false)))) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => TrialModal(userId: user.uid),
      );
    }
  }

  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          await _initializeUserDocument(userCredential.user!, context);
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
        await _initializeUserDocument(userCredential.user!, context);
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
