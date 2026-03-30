import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../local/database_helper.dart';
import '../models/transaction_model.dart';
import 'sms_service.dart';

/// Manages real-time SMS listening and background-cache draining.
///
/// - Subscribes to the Android EventChannel for foreground SMS events.
/// - On startup, drains any SMS that arrived while the app was closed.
/// - Shows a local notification for every auto-imported transaction.
/// - Exposes a broadcast [Stream] so UI widgets can react to new transactions.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static const EventChannel _eventChannel = EventChannel('sms_live_channel');

  final _smsService = SMSService();
  final _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription? _subscription;

  // Broadcast stream so UI screens can refresh when a new transaction arrives
  final _txController = StreamController<TransactionModel>.broadcast();
  Stream<TransactionModel> get onNewTransaction => _txController.stream;

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid) return;

    await _initLocalNotifications();
    await _requestSmsPermission();
    await _drainBackgroundCache();
    _startLiveListener();
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
  }

  Future<void> _requestSmsPermission() async {
    await _smsService.requestSmsPermission();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background cache drain (pending SMS from when app was closed)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _drainBackgroundCache() async {
    print('NotificationService: Draining background SMS cache...');
    try {
      final added = await _smsService.drainPendingSms();
      for (final tx in added) {
        print('NotificationService: Imported background tx: ${tx.merchant} ₹${tx.amount.abs()}');
        _txController.add(tx);
        await _showTransactionNotification(tx);
      }
      print('NotificationService: Drained ${added.length} pending transactions');
    } catch (e) {
      print('NotificationService: drainBackgroundCache error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Live foreground SMS listener (EventChannel)
  // ─────────────────────────────────────────────────────────────────────────

  void _startLiveListener() {
    if (_subscription != null) return;

    print('NotificationService: Starting live SMS listener...');

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        print('NotificationService: Live SMS received: $event');
        if (event is Map) _handleLiveSms(event);
      },
      onError: (error) {
        print('NotificationService: EventChannel error: $error');
        _subscription?.cancel();
        _subscription = null;
        // Retry after 5 seconds if the stream fails
        Future.delayed(const Duration(seconds: 5), _startLiveListener);
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleLiveSms(Map<dynamic, dynamic> data) async {
    final body = (data['body'] as String?) ?? '';
    final sender = (data['sender'] as String?) ?? '';
    final dateMs = data['date'] is int
        ? data['date'] as int
        : DateTime.now().millisecondsSinceEpoch;

    print('NotificationService: Parsing live SMS from $sender');

    final tx = _smsService.parseSms(body: body, sender: sender, dateMs: dateMs);
    if (tx == null) return;

    // Create a deterministic smsId from content (live events have no native id)
    final smsId = 'live_${sender}_$dateMs';
    final rowId = await DatabaseHelper.instance.insertTransactionDeduped(
      smsId: smsId,
      tx: tx,
    );

    if (rowId != -1) {
      print('NotificationService: New live transaction saved: ${tx.merchant} ₹${tx.amount.abs()}');
      _txController.add(tx);
      await _showTransactionNotification(tx);
    } else {
      print('NotificationService: Duplicate transaction skipped');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local notification
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showTransactionNotification(TransactionModel tx) async {
    try {
      final isCredit = tx.type == 'income';
      final sign = isCredit ? '+' : '-';
      final color = isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      final title = isCredit ? '💰 Income Detected' : '💳 Expense Detected';
      final body = '$sign₹${tx.amount.abs().toStringAsFixed(0)} · ${tx.merchant} · ${tx.category}';

      final androidDetails = AndroidNotificationDetails(
        'transaction_channel',
        'Transaction Alerts',
        channelDescription: 'Auto-imported transaction notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        color: color,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      print('NotificationService: Failed to show notification: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Also imports historical SMS from inbox (call once after first permission grant).
  Future<int> importHistoricalSms() async {
    return _smsService.fetchTransactionSMS();
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _txController.close();
  }
}
