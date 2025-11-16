import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'email': email,
      'password': password,

      'lastSignIn': FieldValue.serverTimestamp(),
      'provider': 'password',
    }, SetOptions(merge: true));
    return cred;
  }

  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    bool isDeveloper = false,
    String? devCode,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'password': password,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeveloper': isDeveloper,
      if (devCode != null && devCode.isNotEmpty) 'devCode': devCode,
      'isActive': true,
    }, SetOptions(merge: true));
    return cred;
  }

  Future<bool> validateDevCode(String code) async {
    if (code.trim().isEmpty) return false;
    final snap = await _db
        .collection('devCodes')
        .where('code', isEqualTo: code.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) {
      throw Exception('Google sign-in aborted');
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user!;
    await _db.collection('users').doc(user.uid).set({
      'name': user.displayName ?? '',
      'email': user.email,
      'password': null,
      'photoURL': user.photoURL,
      'provider': 'google',
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}

String friendlyAuthMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a moment.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'email-already-in-use':
        return 'This email address is already in use by another account.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'operation-not-allowed':
        return 'This sign-in method is currently disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  final msg = error.toString();
  if (msg.contains('Google sign-in aborted')) {
    return 'Google sign-in was canceled.';
  }
  return 'Something went wrong. Please try again.';
}
