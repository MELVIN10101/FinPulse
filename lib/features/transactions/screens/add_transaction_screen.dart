import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _db = DatabaseHelper.instance;
  final _amountC = TextEditingController();
  final _merchantC = TextEditingController();
  final _noteC = TextEditingController();
  DateTime _date = DateTime.now();
  String _type = 'expense'; // expense | income
  String _category = 'Food';
  bool _saving = false;

  static const _categories = [
    {'label': 'Food', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFEAB308)},
    {'label': 'Shopping', 'icon': Icons.shopping_cart_rounded, 'color': Color(0xFFFF8A34)},
    {'label': 'Transport', 'icon': Icons.directions_car_rounded, 'color': Color(0xFF8B5CF6)},
    {'label': 'Bills', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFF3B82F6)},
    {'label': 'Entertainment', 'icon': Icons.movie_rounded, 'color': Color(0xFFEC4899)},
    {'label': 'Groceries', 'icon': Icons.local_grocery_store_rounded, 'color': Color(0xFF22C55E)},
    {'label': 'Health', 'icon': Icons.favorite_rounded, 'color': Color(0xFFEF4444)},
    {'label': 'Income', 'icon': Icons.attach_money_rounded, 'color': Color(0xFF22C55E)},
  ];

  @override
  void dispose() {
    _amountC.dispose();
    _merchantC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6), onPrimary: Colors.white,
          surface: Color(0xFF0D1117), onSurface: Colors.white,
        ), dialogBackgroundColor: const Color(0xFF0D1117)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amountText = _amountC.text.trim();
    final merchant = _merchantC.text.trim();
    if (amountText.isEmpty || merchant.isEmpty) {
      _snack('Please fill amount and merchant');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }

    setState(() => _saving = true);

    final isIncome = _type == 'income' || _category == 'Income';
    final tx = TransactionModel(
      amount: isIncome ? amount : -amount,
      merchant: merchant,
      category: _category,
      type: isIncome ? 'income' : 'expense',
      timestamp: _date.toIso8601String(),
      note: _noteC.text.trim(),
    );

    await _db.insertTransaction(tx);
    if (!mounted) return;
    Navigator.pop(context, true); // true = saved
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            // Amount display
            Center(child: Column(children: [
              const Text('AMOUNT', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('₹ ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300, color: Color(0xFF64748B))),
                IntrinsicWidth(child: TextField(
                  controller: _amountC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none, hintText: '0.00',
                    hintStyle: TextStyle(color: Color(0xFF1E293B), fontSize: 48, fontWeight: FontWeight.w700),
                  ),
                )),
              ]),
            ])),
            const SizedBox(height: 24),
            // Type toggle
            Center(child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF0C1A2B), borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _typeChip('Expense', 'expense'),
                _typeChip('Income', 'income'),
              ]),
            )),
            const SizedBox(height: 28),
            // Merchant
            _fieldLabel('MERCHANT'),
            const SizedBox(height: 8),
            _inputField(_merchantC, 'e.g. Starbucks Coffee'),
            const SizedBox(height: 20),
            // Date
            _fieldLabel('DATE'),
            const SizedBox(height: 8),
            GestureDetector(onTap: _pickDate, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFF1A2535), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Text(DateFormat('MMMM d, yyyy').format(_date), style: const TextStyle(color: Colors.white, fontSize: 15)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
              ]),
            )),
            const SizedBox(height: 20),
            // Category
            _fieldLabel('CATEGORY'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 10, children: _categories.map((c) {
              final label = c['label'] as String;
              final isSelected = _category == label;
              final color = c['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() {
                  _category = label;
                  if (label == 'Income') _type = 'income';
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.2) : const Color(0xFF0C1A2B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(c['icon'] as IconData, color: isSelected ? color : const Color(0xFF64748B), size: 16),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 20),
            // Note
            _fieldLabel('NOTE (OPTIONAL)'),
            const SizedBox(height: 8),
            _inputField(_noteC, 'Add a note...', maxLines: 3),
            const SizedBox(height: 32),
            // Save button
            SizedBox(width: double.infinity, child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )),
            const SizedBox(height: 40),
          ]),
        )),
      ])),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context), child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFF0D1117), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      )),
      const Expanded(child: Center(child: Text('Add Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)))),
      const SizedBox(width: 36),
    ]),
  );

  Widget _typeChip(String label, String value) {
    final sel = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? (value == 'expense' ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF22C55E).withOpacity(0.2)) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : const Color(0xFF64748B),
        )),
      ),
    );
  }

  Widget _fieldLabel(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 1.0));

  Widget _inputField(TextEditingController c, String hint, {int maxLines = 1}) => Container(
    decoration: BoxDecoration(color: const Color(0xFF1A2535), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: TextField(
      controller: c, maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), hintText: hint, hintStyle: const TextStyle(color: Color(0xFF334155))),
    ),
  );
}
