import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/local/database_helper.dart';
import '../../../core/theme/theme_manager.dart';
import '../../auth/auth_service.dart';
import 'privacy_policy_screen.dart';
import 'security_settings_screen.dart';
import '../../../core/privacy/privacy_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  bool _darkMode = true;
  bool _notifications = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    if (!mounted) return;
    setState(() {
      _darkMode = ThemeManager.instance.themeMode == ThemeMode.dark;
      _notifications = s['notifications'] != 'false';
      _loading = false;
    });
  }

  Future<void> _save(String k, bool v) => _db.setSetting(k, v.toString());

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          _snack('Enable notifications in device Settings');
          await openAppSettings();
          return;
        }
      }
    }
    setState(() => _notifications = enabled);
    await _save('notifications', enabled);
    _snack(enabled ? 'Notifications enabled' : 'Notifications disabled');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : Column(children: [
                _header(),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 24),
                    _label('APPEARANCE'), const SizedBox(height: 12),
                    _card([
                      _toggle(
                        Icons.dark_mode_rounded,
                        'Dark Mode',
                        'Use dark theme',
                        _darkMode,
                        (v) {
                          setState(() => _darkMode = v);
                          ThemeManager.instance.setThemeMode(v);
                        },
                      )
                    ]),
                    const SizedBox(height: 24),
                    _label('NOTIFICATIONS'), const SizedBox(height: 12),
                    _card([
                      _toggle(
                        Icons.notifications_outlined,
                        'Push Notifications',
                        'Get spending alerts',
                        _notifications,
                        _toggleNotifications,
                      )
                    ]),
                    const SizedBox(height: 24),
                    _label('SECURITY'), const SizedBox(height: 12),
                    _card([
                      ListenableBuilder(
                        listenable: PrivacyManager.instance,
                        builder: (context, _) {
                          return _toggle(
                            Icons.visibility_off_outlined,
                            'Incognito View',
                            'Hide balances and transaction amounts',
                            PrivacyManager.instance.isPrivacyMode,
                            (_) => PrivacyManager.instance.togglePrivacyMode(),
                          );
                        },
                      ),
                      _div(),
                      _action(
                        Icons.lock_outline_rounded,
                        'App Lock & Passcode',
                        'Manage PIN and biometric security',
                        null,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
                        ).then((_) => _loadSettings()),
                      )
                    ]),
                    const SizedBox(height: 24),
                    _label('AI ASSISTANT'), const SizedBox(height: 12),
                    _card([
                       _action(
                         Icons.settings_suggest_rounded,
                         'Gemini API Key',
                         'Configure custom Gemini API key',
                         null,
                         _changeGeminiApiKey,
                       )
                    ]),
                    const SizedBox(height: 24),
                    _label('DATA'), const SizedBox(height: 12),
                    _card([
                      _action(
                        Icons.delete_sweep_rounded,
                        'Reset Financial Data',
                        'Delete all transactions and goals',
                        const Color(0xFFEF4444),
                        _confirmReset,
                      ),
                      if (AuthService.instance.currentUser != null) ...[
                        _div(),
                        _action(
                          Icons.no_accounts_rounded,
                          'Delete Account',
                          'Permanently delete your profile and account',
                          const Color(0xFFEF4444),
                          _confirmDeleteAccount,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    _label('ABOUT'), const SizedBox(height: 12),
                    _card([
                      _action(
                        Icons.privacy_tip_outlined,
                        'Privacy Policy',
                        null,
                        null,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                        ),
                      ),
                      _div(),
                      _action(Icons.info_outline_rounded, 'App Version', null, null, null, trailing: const Text('1.0.0', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
                    ]),
                    const SizedBox(height: 40),
                  ]),
                )),
              ]),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context), child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFF0D1117), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
      )),
      const Expanded(child: Center(child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)))),
      const SizedBox(width: 36),
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));

  Widget _card(List<Widget> c) => Container(
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: c),
  );

  Widget _toggle(IconData icon, String title, String sub, bool val, ValueChanged<bool> cb) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF94A3B8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ])),
      Switch.adaptive(value: val, onChanged: cb, activeColor: const Color(0xFF3B82F6), inactiveTrackColor: const Color(0xFF1E293B)),
    ]),
  );

  Widget _action(IconData icon, String title, String? sub, Color? iconC, VoidCallback? onTap, {Widget? trailing}) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), color: Colors.transparent, child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: (iconC ?? const Color(0xFF94A3B8)).withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconC ?? const Color(0xFF94A3B8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        if (sub != null) ...[const SizedBox(height: 3), Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))],
      ])),
      trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
    ])),
  );

  Widget _div() => Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 72);

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: const Color(0xFF1E293B), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  void _confirmReset() async {
    final pwController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Financial Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete all transactions and goals.\n\nEnter your password to confirm.',
                style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: pwController,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 18,
                      ),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            TextButton(
              onPressed: () async {
                final profile = await _db.getUserProfile();
                final email = profile.email;
                final userRow = await _db.getUserByEmail(email);

                final isGoogleUser = email.contains('google') || (userRow != null && userRow['password_hash'] == '');
                if (isGoogleUser) {
                  Navigator.pop(ctx, true);
                  return;
                }

                final error = await AuthService.instance.signInWithEmail(email, pwController.text.trim());
                if (error != null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: const Text('Incorrect password'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _db.resetFinancialData();
      _snack('All financial data has been reset');
    }
  }

  void _confirmDeleteAccount() async {
    final pwController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account, synced cloud data, and all local transaction history.\n\nEnter your password to confirm.',
                style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: pwController,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 18,
                      ),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            TextButton(
              onPressed: () async {
                final profile = await _db.getUserProfile();
                final email = profile.email;
                final userRow = await _db.getUserByEmail(email);

                final isGoogleUser = email.contains('google') || (userRow != null && userRow['password_hash'] == '');
                if (isGoogleUser) {
                  Navigator.pop(ctx, true);
                  return;
                }

                final error = await AuthService.instance.signInWithEmail(email, pwController.text.trim());
                if (error != null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: const Text('Incorrect password'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Delete Permanently', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _db.resetFinancialData();
      await AuthService.instance.deleteAccount();
      if (mounted) {
        _snack('Your account and data have been permanently deleted.');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _changeGeminiApiKey() async {
    final keyController = TextEditingController();
    final existingKey = await _db.getSetting('gemini_api_key') ?? '';
    keyController.text = existingKey;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gemini API Key',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your custom Gemini API Key to enable natural conversational chat with the AI Coach.',
              style: TextStyle(color: Color(0xFF94A3B8), height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2535),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: keyController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final key = keyController.text.trim();
      await _db.setSetting('gemini_api_key', key);
      _snack(key.isNotEmpty ? 'Gemini API Key updated' : 'Gemini API Key removed');
    }
  }
}

