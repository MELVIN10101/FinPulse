import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/transaction_model.dart';
import '../../navigation/main_navigation_screen.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  const RecentTransactionsSection({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Recent Transactions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        GestureDetector(
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)), (route) => false),
          child: const Text("View All", style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
        ),
      ]),
      const SizedBox(height: 20),
      if (transactions.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: const Text('No transactions yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        )
      else
        ...transactions.map((tx) {
          final isIncome = tx.type == 'income';
          final info = _categoryInfo(tx.category);
          final date = DateTime.tryParse(tx.timestamp);
          final dateStr = date != null ? DateFormat('hh:mm a · EEEE, MMM d').format(date) : '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C1A2B), Color(0xFF08121F)]),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(children: [
                Container(height: 48, width: 48, decoration: BoxDecoration(color: (info['color'] as Color).withOpacity(0.15), shape: BoxShape.circle), child: Icon(info['icon'] as IconData, color: info['color'] as Color, size: 22)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx.merchant, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text("${isIncome ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isIncome ? const Color(0xFF22C55E) : Colors.redAccent)),
                  const SizedBox(height: 6),
                  Text(tx.category.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          );
        }),
    ]);
  }

  Map<String, dynamic> _categoryInfo(String category) {
    switch (category) {
      case 'Bills': return {'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF3B82F6)};
      case 'Shopping': return {'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFFFF8A34)};
      case 'Groceries': return {'icon': Icons.local_grocery_store_rounded, 'color': const Color(0xFF22C55E)};
      case 'Food': return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFFEAB308)};
      case 'Transport': return {'icon': Icons.directions_car_rounded, 'color': const Color(0xFF8B5CF6)};
      case 'Entertainment': return {'icon': Icons.movie_rounded, 'color': const Color(0xFFEC4899)};
      case 'Health': return {'icon': Icons.favorite_rounded, 'color': const Color(0xFFEF4444)};
      case 'Income': return {'icon': Icons.attach_money_rounded, 'color': const Color(0xFF22C55E)};
      default: return {'icon': Icons.circle, 'color': Colors.grey};
    }
  }
}