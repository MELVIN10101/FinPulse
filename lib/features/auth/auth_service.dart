import 'dart:async';
import 'dart:io';
import 'local_auth_service.dart';
import 'firebase_auth_service.dart';

/// Unified auth user model exposed to the UI.
class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
  });

  factory AppUser.fromLocal(LocalUser u) =>
      AppUser(id: u.id, name: u.name, email: u.email, avatarUrl: u.avatarUrl);
}

/// Platform-aware authentication facade.
/// Desktop (Linux/Windows/macOS): delegates to [LocalAuthService].
/// Mobile (Android/iOS): delegates to [FirebaseAuthService].
class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  // ─── Auth state stream ─────────────────────────────────────────────────

  Stream<AppUser?> get authStateChanges {
    if (_isDesktop) {
      return LocalAuthService.instance.authStateChanges
          .map((u) => u != null ? AppUser.fromLocal(u) : null);
    }
    return FirebaseAuthService.instance.authStateChanges;
  }

  AppUser? get currentUser {
    if (_isDesktop) {
      final u = LocalAuthService.instance.currentUser;
      return u != null ? AppUser.fromLocal(u) : null;
    }
    return FirebaseAuthService.instance.currentUser;
  }

  // ─── Init ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isDesktop) {
      await LocalAuthService.instance.restoreSession();
    } else {
      // Initialize Google Sign-In SDK (required by google_sign_in v7)
      await FirebaseAuthService.instance.initialize();
    }
    // Firebase session persistence is handled automatically on mobile.
  }

  // ─── Sign In ───────────────────────────────────────────────────────────

  Future<String?> signInWithEmail(String email, String password) async {
    if (_isDesktop) {
      return LocalAuthService.instance.signInWithEmail(email, password);
    }
    return FirebaseAuthService.instance.signInWithEmail(email, password);
  }

  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isDesktop) {
      return LocalAuthService.instance
          .signUpWithEmail(name: name, email: email, password: password);
    }
    return FirebaseAuthService.instance
        .signUpWithEmail(name: name, email: email, password: password);
  }

  /// Google Sign-In.
  /// On desktop: browser OAuth flow (requires [clientId]).
  /// On mobile: native Google Sign-In via Firebase.
  Future<String?> signInWithGoogle({String clientId = ''}) async {
    if (_isDesktop) {
      if (clientId.isEmpty) {
        return 'Google Client ID not configured. '
            'Add your OAuth2 Client ID from Google Cloud Console.';
      }
      return LocalAuthService.instance.signInWithGoogle(clientId: clientId);
    }
    return FirebaseAuthService.instance.signInWithGoogle();
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (_isDesktop) {
      await LocalAuthService.instance.signOut();
    } else {
      await FirebaseAuthService.instance.signOut();
    }
  }
}
