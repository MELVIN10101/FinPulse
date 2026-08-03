import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

/// Firebase-backed authentication for Android / iOS.
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Init (call once at app startup on mobile) ─────────────────────────────

  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize();
  }

  // ─── Auth state ────────────────────────────────────────────────────────────

  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  AppUser? get currentUser => _mapUser(_auth.currentUser);

  AppUser? _mapUser(User? u) {
    if (u == null) return null;
    return AppUser(
      id: u.uid,
      name: u.displayName ?? u.email?.split('@').first ?? 'User',
      email: u.email ?? '',
      avatarUrl: u.photoURL ?? '',
    );
  }

  // ─── Email / Password ──────────────────────────────────────────────────────

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  // ─── Google Sign-In (google_sign_in v7) ────────────────────────────────────

  Future<String?> signInWithGoogle() async {
    try {
      // Authenticate (account picker / Credential Manager). Throws on cancel.
      final googleUser = await GoogleSignIn.instance.authenticate();

      // Authorise for email/profile to get the access token
      final GoogleSignInClientAuthorization authorization =
          await googleUser.authorizationClient.authorizeScopes(
        ['email', 'profile'],
      );

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleUser.authentication.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancel') || msg.contains('Cancel')) {
        return 'Google sign-in cancelled.';
      }
      return msg;
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
      await GoogleSignIn.instance.signOut();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method for this email.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
