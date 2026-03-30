import 'package:crypto/crypto.dart';
import 'dart:convert';

class SmsRawModel {
  final int? id;
  final String smsHash;    // dedup key: SHA-256(sender+amount+hourFloor)
  final String sender;     // bank short-code or phone number
  final String body;       // original SMS body
  final String smsType;    // 'transaction'|'balance_alert'|'emi_payment'|'salary_credit'|'investment'|'other_financial'
  final double amount;
  final String merchant;
  final String category;
  final String txType;     // 'income' | 'expense'
  final String timestamp;  // ISO-8601
  final bool processed;    // whether it was inserted into transactions table

  const SmsRawModel({
    this.id,
    required this.smsHash,
    required this.sender,
    required this.body,
    required this.smsType,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.txType,
    required this.timestamp,
    this.processed = false,
  });

  /// Generate a dedup hash from sender + floored-to-hour timestamp + amount
  static String generateHash(String sender, double amount, DateTime timestamp) {
    final hourFloor = DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour);
    final key = '$sender|${amount.toStringAsFixed(2)}|${hourFloor.toIso8601String()}';
    return sha256.convert(utf8.encode(key)).toString();
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sms_hash':  smsHash,
    'sender':    sender,
    'body':      body,
    'sms_type':  smsType,
    'amount':    amount,
    'merchant':  merchant,
    'category':  category,
    'tx_type':   txType,
    'timestamp': timestamp,
    'processed': processed ? 1 : 0,
  };

  factory SmsRawModel.fromMap(Map<String, dynamic> map) => SmsRawModel(
    id:        map['id'] as int?,
    smsHash:   map['sms_hash'] as String,
    sender:    map['sender'] as String,
    body:      map['body'] as String,
    smsType:   map['sms_type'] as String,
    amount:    (map['amount'] as num).toDouble(),
    merchant:  map['merchant'] as String,
    category:  map['category'] as String,
    txType:    map['tx_type'] as String,
    timestamp: map['timestamp'] as String,
    processed: (map['processed'] as int) == 1,
  );
}
