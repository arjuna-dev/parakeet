import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithGoogle() async {
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
        return userCredential.user;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
    }
    return null;
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
