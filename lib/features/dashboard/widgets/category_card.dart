import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final Map<String, int> categoryCounts;
  const CategoryCard({super.key, required this.categoryTotals, required this.categoryCounts});

  @override
  Widget build(BuildContext context) {
    final data = categoryTotals.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C1A2B), Color(0xFF08121F)]),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.25), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 25))],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        Row(children: [
          const Expanded(child: Text("Expense Split", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: Colors.white), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 26),
        if (data.isEmpty)
          const Center(child: Text('No expenses yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)))
        else
          ...data.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == data.length - 1;
            final count = categoryCounts[item.key] ?? 0;

            return Column(children: [
              Row(children: [
                _iconFor(item.key),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("$count Transactions", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ])),
                Text("-₹${item.value.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
              if (!isLast) ...[const SizedBox(height: 10), Divider(color: Colors.white.withOpacity(0.05), height: 1), const SizedBox(height: 10)],
            ]);
          }),
      ]),
    );
  }

  Widget _iconFor(String title) {
    switch (title) {
      case "Bills": return _icon(Icons.receipt_long_rounded, const Color(0xFF3B82F6));
      case "Shopping": return _icon(Icons.shopping_cart_rounded, const Color(0xFFFF8A34));
      case "Groceries": return _icon(Icons.local_grocery_store_rounded, const Color(0xFF22C55E));
      case "Food": return _icon(Icons.restaurant_rounded, const Color(0xFFEAB308));
      case "Transport": return _icon(Icons.directions_car_rounded, const Color(0xFF8B5CF6));
      case "Entertainment": return _icon(Icons.movie_rounded, const Color(0xFFEC4899));
      case "Health": return _icon(Icons.favorite_rounded, const Color(0xFFEF4444));
      case "Income": return _icon(Icons.attach_money_rounded, const Color(0xFF22C55E));
      default: return _icon(Icons.circle, Colors.grey);
    }
  }

  Widget _icon(IconData icon, Color color) => Container(
    height: 48, width: 48,
    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 22),
  );
}