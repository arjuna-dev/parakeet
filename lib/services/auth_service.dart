import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      print('Attempting to sign in with Google...');
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      if (googleSignInAccount != null) {
        print('Google Sign-In account retrieved: ${googleSignInAccount.email}');
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        print(
            'Google Sign-In authentication retrieved: accessToken=${googleSignInAuthentication.accessToken}, idToken=${googleSignInAuthentication.idToken}');
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        print('Firebase user signed in: ${userCredential.user?.email}');
        return userCredential.user;
      } else {
        print('Google Sign-In account is null');
      }
    } catch (e) {
      print('Error signing in with Google: $e');
    }
    return null;
  }

  // Sign in with Apple
  Future<User?> signInWithApple() async {
    try {
      // Request Apple ID credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an OAuth credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      return userCredential.user;
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }

  // Sign out from all providers
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
