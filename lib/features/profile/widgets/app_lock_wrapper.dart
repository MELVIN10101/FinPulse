import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';
import '../screens/pin_lock_screen.dart';
import '../screens/security_settings_screen.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _appLockEnabled = false;
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockState.refreshTrigger.addListener(_onSettingsRefreshed);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLockState.refreshTrigger.removeListener(_onSettingsRefreshed);
    super.dispose();
  }

  void _onSettingsRefreshed() {
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    try {
      final s = await DatabaseHelper.instance.getAllSettings();
      final enabled = s['app_lock_enabled'] == 'true';
      final pin = s['app_lock_pin'] ?? '';

      if (enabled && pin.isNotEmpty) {
        setState(() {
          _appLockEnabled = true;
        });
      } else {
        setState(() {
          _appLockEnabled = false;
          _isLocked = false;
        });
      }
    } catch (_) {
      setState(() {
        _appLockEnabled = false;
        _isLocked = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_appLockEnabled) return;

    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockStatus().then((_) {
        if (!_appLockEnabled) return;

        if (_backgroundTime != null) {
          final difference = DateTime.now().difference(_backgroundTime!);
          // Lock if backgrounded for more than 2 seconds
          if (difference.inSeconds > 2) {
            setState(() {
              _isLocked = true;
            });
          }
        } else {
          // No background timestamp recorded, safety lock
          setState(() {
            _isLocked = true;
          });
        }
      });
    }
  }

  void _onUnlocked() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked && _appLockEnabled) {
      return PinLockScreen(
        onSuccess: _onUnlocked,
        isCancelable: false,
      );
    }
    return widget.child;
  }
}
