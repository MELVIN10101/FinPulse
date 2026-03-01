class TransactionModel {
  final int? id;
  final double amount;
  final String merchant;
  final String category;
  final String type;
  final String timestamp;
  final String note;

  TransactionModel({
    this.id,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
    required this.timestamp,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'type': type,
      'timestamp': timestamp,
      'note': note,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
      timestamp: map['timestamp'] as String,
      note: (map['note'] as String?) ?? '',
    );
  }
}
