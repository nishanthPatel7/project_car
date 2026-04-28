import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../frontend/app_director.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Auth State Stream
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-specific Google flow
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile-specific Google flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: (googleAuth as dynamic).idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    // Clear stale role selection so it doesn't carry over to next login
    NavigationService.intendedEntry = null;
    try {
      await _googleSignIn.signOut();
    } catch (_) {} // Handle cases where not signed in with Google
    await _auth.signOut();
  }
}
