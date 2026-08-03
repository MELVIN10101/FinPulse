import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../local/database_helper.dart';
import '../models/transaction_model.dart';
import '../../core/constants/categories_data.dart';
import 'local_ai_classifier.dart';

/// Handles SMS permission, bulk historical SMS import, and real-time SMS parsing.
class SMSService {
  static const _platform = MethodChannel('sms_channel');

  // ─────────────────────────────────────────────────────────────────────────
  // Permission
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Historical SMS import (inbox scan on first launch)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads the last [limit] inbox SMS messages and inserts any new
  /// transaction-related ones into the database (with deduplication).
  Future<int> fetchTransactionSMS({int limit = 500}) async {
    final granted = await requestSmsPermission();
    if (!granted) {
      print('SMSService: SMS permission denied');
      return 0;
    }

    int imported = 0;
    try {
      final List<dynamic> messages =
          await _platform.invokeMethod('getSms', {'limit': limit});

      for (final msg in messages) {
        final body = (msg['body'] as String?) ?? '';
        final senderRaw = (msg['sender'] as String?) ?? '';
        final dateMs = (msg['date'] as int?) ?? 0;
        final smsId = (msg['id'] as String?) ?? '';

        final parsed = parseSms(body: body, sender: senderRaw, dateMs: dateMs);
        if (parsed == null) continue;

        final rowId = await DatabaseHelper.instance.insertTransactionDeduped(
          smsId: 'hist_$smsId',
          tx: parsed,
        );
        if (rowId != -1) imported++;
      }
    } catch (e) {
      print('SMSService.fetchTransactionSMS error: $e');
    }
    return imported;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pending SMS cache (written by SmsProcessorService when app was closed)
  // ─────────────────────────────────────────────────────────────────────────

  /// Drains the SharedPreferences cache of SMS messages that arrived while
  /// the app was closed. Returns newly added transaction models.
  Future<List<TransactionModel>> drainPendingSms() async {
    final added = <TransactionModel>[];
    try {
      final List<dynamic> pending =
          await _platform.invokeMethod('getPendingSms');
      for (final msg in pending) {
        final body = (msg['body'] as String?) ?? '';
        final sender = (msg['sender'] as String?) ?? '';
        final dateMs = (msg['date'] as int?) ?? 0;

        final tx = parseSms(body: body, sender: sender, dateMs: dateMs);
        if (tx == null) continue;

        // Build a deterministic ID from content (no native sms_id for cached msgs)
        final smsId = _fingerprintSms(body: body, sender: sender, dateMs: dateMs);
        final rowId = await DatabaseHelper.instance.insertTransactionDeduped(
          smsId: 'bg_$smsId',
          tx: tx,
        );
        if (rowId != -1) added.add(tx);
      }
    } catch (e) {
      print('SMSService.drainPendingSms error: $e');
    }
    return added;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMS Parsing
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a [TransactionModel] if [body] looks like a financial SMS,
  /// or `null` if not a transaction message.
  TransactionModel? parseSms({
    required String body,
    required String sender,
    required int dateMs,
  }) {
    if (!isTransactionMessage(body)) return null;

    final amount = extractAmount(body);
    if (amount <= 0) return null;

    final type = _detectType(body);
    final merchant = extractMerchant(body);
    final category = detectCategory(merchant, body, type);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(dateMs).toIso8601String();

    return TransactionModel(
      amount: type == 'Credit' ? amount : -amount,
      merchant: merchant,
      category: category,
      type: type == 'Credit' ? 'income' : 'expense',
      timestamp: timestamp,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool isTransactionMessage(String body) {
    final b = body.toLowerCase();
    return b.contains('debited') ||
        b.contains('credited') ||
        b.contains('debit') ||
        b.contains('credit') ||
        b.contains('upi') ||
        b.contains('payment') ||
        b.contains('transferred') ||
        b.contains('transaction') ||
        b.contains('spent') ||
        b.contains('withdraw') ||
        b.contains('purchase') ||
        b.contains('rs.') ||
        b.contains('rs ') ||
        b.contains('inr') ||
        b.contains('₹') ||
        b.contains('send kiya') ||
        b.contains('sent kiya') ||
        b.contains('received hua') ||
        b.contains('recieved hua') ||
        b.contains('credit hua') ||
        b.contains('transfer kiya');
  }

  String _detectType(String body) {
    final b = body.toLowerCase();
    // Strong credit signals
    if (b.contains('credited') ||
        b.contains('credit') ||
        b.contains('received') ||
        b.contains('received hua') ||
        b.contains('recieved hua') ||
        b.contains('credit hua') ||
        b.contains('refund') ||
        b.contains('cashback') ||
        b.contains('salary')) {
      return 'Credit';
    }
    return 'Debit';
  }

  double extractAmount(String body) {
    // Patterns ordered from most-specific to least-specific:
    final patterns = [
      // ₹1,234.56 or ₹1234.56 or ₹ 1,234
      RegExp(r'₹\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Rs. 1,234.56 or Rs 1234
      RegExp(r'Rs\.?\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // INR 1,234.56
      RegExp(r'INR\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // "debited by 500" / "credited with 2000" / Hinglish "transfer kiya 500"
      RegExp(r'(?:debited|credited|debit|credit|spent|paid|amount|kiya|transfer|bheja)\s+(?:of\s+|by\s+|with\s+|:?\s*)?(?:Rs\.?|INR|₹)?\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // Generic number that looks like a currency amount
      RegExp(r'\b(\d{1,8}(?:,\d{3})*(?:\.\d{1,2})?)\b'),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(body);
      if (m != null) {
        final raw = m.group(1)?.replaceAll(',', '') ?? '0';
        final val = double.tryParse(raw) ?? 0;
        if (val >= 1) return val; // Ignore sub-rupee amounts
      }
    }
    return 0;
  }

  String extractMerchant(String body) {
    // Patterns to extract the payee / merchant name
    final patterns = [
      // "to <NAME>" — UPI/NEFT transfers
      RegExp(r'\bto\s+([A-Za-z][A-Za-z0-9 &.\-]{1,30}?)(?:\s*(?:on|via|upi|ref|ac|\.|,|$))', caseSensitive: false),
      // "at <MERCHANT>"
      RegExp(r'\bat\s+([A-Za-z][A-Za-z0-9 &.\-]{1,30}?)(?:\s*(?:on|for|upi|ref|\.|,|$))', caseSensitive: false),
      // "VPA <name@bank>"
      RegExp(r'VPA\s+([A-Za-z0-9._@-]+)', caseSensitive: false),
      // "towards <MERCHANT>"
      RegExp(r'\btowards\s+([A-Za-z][A-Za-z0-9 &.\-]{1,30}?)(?:\s*(?:\.|,|$))', caseSensitive: false),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(body);
      if (m != null) {
        final raw = m.group(1)?.trim() ?? '';
        if (raw.isNotEmpty && raw.length > 1) return _cleanMerchant(raw);
      }
    }
    return 'Unknown';
  }

  String _cleanMerchant(String raw) {
    // Remove trailing noise words
    return raw
        .replaceAll(RegExp(r'\s+(on|via|upi|ref|a\/c|ac).*$', caseSensitive: false), '')
        .trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Category detection (unchanged logic, preserved from original)
  // ─────────────────────────────────────────────────────────────────────────

  String detectCategory(String merchant, String body, String type) {
    final detected = AppCategories.detectCategory(merchant, body);
    if (detected != 'Other') return detected;

    // Use on-device local AI classifier prediction
    final prediction = LocalAIClassifier.instance.predict('$merchant $body');
    if (prediction.category != 'Other' && prediction.confidence >= 0.6) {
      return prediction.category;
    }
    
    // If it's a Credit but didn't match any specific rules, return 'Other' (uncategorized)
    // so it shows up in the uncategorized list for the user to map.
    return 'Other';
  }


  // ─────────────────────────────────────────────────────────────────────────
  // Fingerprint for background-cached SMS (no native sms_id available)
  // ─────────────────────────────────────────────────────────────────────────

  String _fingerprintSms({
    required String body,
    required String sender,
    required int dateMs,
  }) {
    final input = '$sender|$dateMs|${body.trim()}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}
