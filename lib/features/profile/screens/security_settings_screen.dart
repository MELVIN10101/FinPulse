import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../data/local/database_helper.dart';

class AppLockState {
  static final ValueNotifier<bool> refreshTrigger = ValueNotifier(false);
  static void triggerRefresh() {
    refreshTrigger.value = !refreshTrigger.value;
  }
}

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _localAuth = LocalAuthentication();

  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loading = true;
  String _currentPin = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _db.getAllSettings();
      final hasPin = s['app_lock_pin'] ?? '';
      final available = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();

      if (!mounted) return;
      setState(() {
        _appLockEnabled = s['app_lock_enabled'] == 'true';
        _biometricEnabled = s['biometric'] == 'true';
        _currentPin = hasPin;
        _biometricAvailable = available || supported;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSetting(String k, String v) async {
    await _db.setSetting(k, v);
    AppLockState.triggerRefresh();
  }

  Future<void> _toggleAppLock(bool enable) async {
    if (enable) {
      // If no PIN set, prompt to set PIN
      if (_currentPin.isEmpty) {
        final newPin = await _showSetPinDialog();
        if (newPin == null) {
          // Cancelled
          return;
        }
        _currentPin = newPin;
      }
      setState(() => _appLockEnabled = true);
      await _saveSetting('app_lock_enabled', 'true');
      _showSnack('App Lock enabled');
    } else {
      // Prompt for PIN to disable
      final verified = await _showVerifyPinDialog('Enter PIN to disable App Lock');
      if (verified == true) {
        setState(() {
          _appLockEnabled = false;
          _biometricEnabled = false;
        });
        await _saveSetting('app_lock_enabled', 'false');
        await _saveSetting('biometric', 'false');
        _showSnack('App Lock disabled');
      }
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      try {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Confirm biometric to enable unlock',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        if (didAuth) {
          setState(() => _biometricEnabled = true);
          await _saveSetting('biometric', 'true');
          _showSnack('Biometric unlock enabled');
        }
      } on PlatformException catch (e) {
        _showSnack('Biometric verification failed: ${e.message}');
      }
    } else {
      setState(() => _biometricEnabled = false);
      await _saveSetting('biometric', 'false');
      _showSnack('Biometric unlock disabled');
    }
  }

  Future<void> _changePin() async {
    final verified = await _showVerifyPinDialog('Enter current PIN');
    if (verified == true) {
      final newPin = await _showSetPinDialog(title: 'Enter New PIN');
      if (newPin != null) {
        _currentPin = newPin;
        _showSnack('PIN updated successfully');
      }
    }
  }

  void _showSnack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
                    _label('PASSCODE LOCK'), const SizedBox(height: 12),
                    _card([
                      _toggle(
                        Icons.security_rounded,
                        'Enable App Lock',
                        'Require PIN to access app',
                        _appLockEnabled,
                        _toggleAppLock,
                      ),
                      if (_appLockEnabled && _currentPin.isNotEmpty) ...[
                        _div(),
                        _action(
                          Icons.pin_rounded,
                          'Change App PIN',
                          'Update your 4-digit security PIN',
                          null,
                          _changePin,
                        ),
                      ]
                    ]),
                    const SizedBox(height: 24),
                    if (_biometricAvailable) ...[
                      _label('BIOMETRICS'), const SizedBox(height: 12),
                      _card([
                        _toggle(
                          Icons.fingerprint_rounded,
                          'Biometric Unlock',
                          'Unlock with fingerprint or face ID',
                          _biometricEnabled,
                          _appLockEnabled ? _toggleBiometric : null,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          _appLockEnabled
                              ? 'Biometric unlock requires App Lock to be enabled.'
                              : 'Enable App Lock first to configure biometrics.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    ],
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
      const Expanded(child: Center(child: Text('Security & Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)))),
      const SizedBox(width: 36),
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));

  Widget _card(List<Widget> c) => Container(
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: c),
  );

  Widget _toggle(IconData icon, String title, String sub, bool val, ValueChanged<bool>? cb) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF94A3B8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: cb != null ? Colors.white : Colors.white38, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(sub, style: TextStyle(color: cb != null ? const Color(0xFF64748B) : Colors.white12, fontSize: 12)),
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

  // Set PIN dialog
  Future<String?> _showSetPinDialog({String title = 'Setup App PIN'}) async {
    final pinController1 = TextEditingController();
    final pinController2 = TextEditingController();
    final node1 = FocusNode();
    final node2 = FocusNode();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Define a 4-digit PIN to secure access to the app.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: pinController1,
              focusNode: node1,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Enter 4-digit PIN',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 0, fontSize: 14),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
              ),
              onChanged: (val) {
                if (val.length == 4) node2.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController2,
              focusNode: node2,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Confirm PIN',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 0, fontSize: 14),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              final pin1 = pinController1.text;
              final pin2 = pinController2.text;
              if (pin1.length != 4) {
                _showDialogError(ctx, 'PIN must be exactly 4 digits');
                return;
              }
              if (pin1 != pin2) {
                _showDialogError(ctx, 'PINs do not match');
                return;
              }
              await _db.setSetting('app_lock_pin', pin1);
              Navigator.pop(ctx, pin1);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Verify PIN dialog
  Future<bool?> _showVerifyPinDialog(String title) async {
    final pinController = TextEditingController();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Enter PIN',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 0, fontSize: 14),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
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
            onPressed: () {
              if (pinController.text == _currentPin) {
                Navigator.pop(ctx, true);
              } else {
                _showDialogError(ctx, 'Invalid PIN code');
              }
            },
            child: const Text('Verify', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDialogError(BuildContext ctx, String m) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
