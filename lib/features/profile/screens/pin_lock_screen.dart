import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../data/local/database_helper.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool isCancelable;

  const PinLockScreen({
    super.key,
    required this.onSuccess,
    this.isCancelable = false,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _db = DatabaseHelper.instance;
  final _localAuth = LocalAuthentication();

  String _correctPin = '';
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _enteredPin = '';
  String _errorMessage = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityInfo();
  }

  Future<void> _loadSecurityInfo() async {
    try {
      final s = await _db.getAllSettings();
      _correctPin = s['app_lock_pin'] ?? '';
      _biometricEnabled = s['biometric'] == 'true';

      final available = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      _biometricAvailable = available || supported;

      setState(() => _loading = false);

      if (_biometricEnabled && _biometricAvailable) {
        // Auto-authenticate with delay so view mounts nicely
        Future.delayed(const Duration(milliseconds: 300), _authenticateBiometric);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Unlock FinPulse',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (didAuth) {
        widget.onSuccess();
      }
    } on PlatformException catch (e) {
      setState(() => _errorMessage = 'Biometric error: ${e.message}');
    }
  }

  void _onNumberTap(int number) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += number.toString();
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _verifyPin() {
    if (_enteredPin == _correctPin) {
      widget.onSuccess();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Icon and title
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFF3B82F6), size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'FinPulse Secure',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your passcode to unlock',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                    const SizedBox(height: 40),

                    // Pin Indicators (dots)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? const Color(0xFF3B82F6) : Colors.transparent,
                            border: Border.all(
                              color: filled ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Error Message
                    SizedBox(
                      height: 20,
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Spacer(),

                    // Keypad
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _keypadButton(1),
                            _keypadButton(2),
                            _keypadButton(3),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _keypadButton(4),
                            _keypadButton(5),
                            _keypadButton(6),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _keypadButton(7),
                            _keypadButton(8),
                            _keypadButton(9),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Biometric key
                            _biometricButton(),
                            _keypadButton(0),
                            // Backspace key
                            _backspaceButton(),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),

                    if (widget.isCancelable) ...[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _keypadButton(int number) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onNumberTap(number);
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _biometricButton() {
    final showIcon = _biometricAvailable && _biometricEnabled;
    return GestureDetector(
      onTap: showIcon ? _authenticateBiometric : null,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: showIcon
            ? const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF3B82F6),
                size: 32,
              )
            : null,
      ),
    );
  }

  Widget _backspaceButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onBackspace();
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.backspace_outlined,
          color: Colors.white60,
          size: 20,
        ),
      ),
    );
  }
}
