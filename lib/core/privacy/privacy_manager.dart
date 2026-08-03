import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';

class PrivacyManager extends ChangeNotifier {
  static final PrivacyManager instance = PrivacyManager._();
  PrivacyManager._();

  bool _isPrivacyMode = false;
  bool get isPrivacyMode => _isPrivacyMode;

  Future<void> init() async {
    final val = await DatabaseHelper.instance.getSetting('privacy_mode');
    _isPrivacyMode = val == 'true';
    notifyListeners();
  }

  Future<void> togglePrivacyMode() async {
    _isPrivacyMode = !_isPrivacyMode;
    await DatabaseHelper.instance.setSetting('privacy_mode', _isPrivacyMode.toString());
    notifyListeners();
  }

  static String formatAmount(double amount, {bool showSign = false, bool decimal = false}) {
    if (instance.isPrivacyMode) {
      final sign = showSign ? (amount < 0 ? '-' : '+') : '';
      return '$sign₹••••';
    }
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    
    String formatted = '';
    if (absAmount >= 1000) {
      final thousands = (absAmount / 1000).floor();
      final remainder = (absAmount % 1000).toInt();
      formatted = '$thousands,${remainder.toString().padLeft(3, '0')}';
    } else {
      formatted = decimal ? absAmount.toStringAsFixed(2) : absAmount.toStringAsFixed(0);
    }

    if (showSign) {
      final sign = isNegative ? '-' : '+';
      return '$sign₹$formatted';
    }
    return '₹$formatted';
  }
}
