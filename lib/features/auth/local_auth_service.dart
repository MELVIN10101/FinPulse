import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/local/database_helper.dart';

/// Represents a locally-authenticated user (Linux/desktop path).
class LocalUser {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  const LocalUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
  });

  factory LocalUser.fromDbRow(Map<String, dynamic> row) => LocalUser(
        id: row['id'] as String,
        name: row['name'] as String,
        email: row['email'] as String,
        avatarUrl: (row['avatar_url'] as String?) ?? '',
      );
}

/// Platform-local authentication service using SQLite.
/// Used on Linux/Windows/macOS desktop targets.
class LocalAuthService {
  static final LocalAuthService instance = LocalAuthService._internal();
  LocalAuthService._internal();

  static const _sessionKey = 'local_auth_user_id';

  final _authController = StreamController<LocalUser?>.broadcast();
  LocalUser? _currentUser;

  Stream<LocalUser?> get authStateChanges => _authController.stream;
  LocalUser? get currentUser => _currentUser;

  // ─── Password hashing ─────────────────────────────────────────────────

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ─── Session persistence ───────────────────────────────────────────────

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionKey);
    if (userId != null) {
      final row = await DatabaseHelper.instance.getUserById(userId);
      if (row != null) {
        _currentUser = LocalUser.fromDbRow(row);
        _authController.add(_currentUser);
        return;
      }
    }
    _authController.add(null);
  }

  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // ─── Email / Password ──────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  Future<String?> signInWithEmail(String email, String password) async {
    final row = await DatabaseHelper.instance.getUserByEmail(email);
    if (row == null) return 'No account found for this email.';

    final hash = _hashPassword(password);
    if (row['password_hash'] != hash) return 'Incorrect password.';

    _currentUser = LocalUser.fromDbRow(row);
    await _saveSession(_currentUser!.id);
    _authController.add(_currentUser);
    return null;
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final exists = await DatabaseHelper.instance.emailExists(email);
    if (exists) return 'An account with this email already exists.';

    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final hash = _hashPassword(password);

    final created = await DatabaseHelper.instance.createUser(
      id: id,
      name: name,
      email: email,
      passwordHash: hash,
    );
    if (created == null) return 'Failed to create account. Please try again.';

    _currentUser = LocalUser(id: id, name: name, email: email);
    await _saveSession(id);
    _authController.add(_currentUser);
    return null;
  }

  // ─── Google OAuth2 (Desktop Browser Flow) ─────────────────────────────

  /// Opens browser for Google OAuth2. Listens on localhost for callback.
  /// Requires a Google Cloud OAuth2 "Desktop" or "Web" client-id with
  /// http://localhost as an allowed redirect URI.
  Future<String?> signInWithGoogle({
    required String clientId,
    int port = 54321,
  }) async {
    final redirectUri = 'http://localhost:$port';
    final scope = Uri.encodeComponent('openid email profile');
    final authUrl = Uri.parse(
      'https://accounts.google.com/o/oauth2/v2/auth'
      '?client_id=$clientId'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&response_type=token'
      '&scope=$scope',
    );

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        return 'Could not open browser for Google Sign-In.';
      }

      // Wait for the redirect (with 2-minute timeout)
      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Google Sign-In timed out.'),
      );

      // Google returns token in fragment (#), so we use a helper page
      final params = request.uri.queryParameters;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('<html><body>'
            '<script>window.close();</script>'
            '<h2>✅ Signed in! You can close this tab.</h2>'
            '</body></html>');
      await request.response.close();

      final accessToken = params['access_token'];
      if (accessToken == null) {
        // Fragment-based flow — token not in query params directly
        // Try the code from the page where JS posts back
        return 'Google Sign-In requires a client secret for desktop flow. '
            'Please use email/password login.';
      }

      // Fetch user info from Google
      final userInfoResp = await HttpClient()
          .getUrl(Uri.parse(
              'https://www.googleapis.com/oauth2/v3/userinfo?access_token=$accessToken'))
          .then((req) => req.close());

      final body = await utf8.decodeStream(userInfoResp);
      final json = jsonDecode(body) as Map<String, dynamic>;

      final googleId = json['sub'] as String;
      final email = json['email'] as String;
      final name = (json['name'] as String?) ?? email.split('@').first;
      final picture = (json['picture'] as String?) ?? '';

      // Upsert user
      Map<String, dynamic>? row = await DatabaseHelper.instance.getUserByEmail(email);
      if (row == null) {
        final id = 'google_$googleId';
        await DatabaseHelper.instance.createUser(
          id: id,
          name: name,
          email: email,
          passwordHash: '',
          avatarUrl: picture,
          googleId: googleId,
        );
        row = await DatabaseHelper.instance.getUserByEmail(email);
      } else {
        await DatabaseHelper.instance.updateUserGoogleId(email, googleId);
      }

      _currentUser = LocalUser.fromDbRow(row!);
      await _saveSession(_currentUser!.id);
      _authController.add(_currentUser);
      return null;
    } on TimeoutException catch (e) {
      return e.message ?? 'Google Sign-In timed out.';
    } catch (e) {
      return 'Google Sign-In failed: $e';
    } finally {
      await server?.close(force: true);
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _currentUser = null;
    await _clearSession();
    _authController.add(null);
  }

  void dispose() {
    _authController.close();
  }
}
