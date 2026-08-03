import 'package:flutter/material.dart';
import '../../../core/constants/categories_data.dart';
import '../manage_categories_screen.dart';
import '../category_transactions_screen.dart';
import '../../../core/privacy/privacy_manager.dart';

class CategoryCard extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final Map<String, int> categoryCounts;
  final VoidCallback? onCategoriesChanged;

  const CategoryCard({
    super.key,
    required this.categoryTotals,
    required this.categoryCounts,
    this.onCategoriesChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
              ).then((changed) {
                if (changed == true && onCategoriesChanged != null) {
                  onCategoriesChanged!();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
            ),
          ),
        ]),
        const SizedBox(height: 26),
        ...AppCategories.expenseCategories.asMap().entries.map((entry) {
          final cat = entry.value;
          final isLast = entry.key == AppCategories.expenseCategories.length - 1;
          final total = categoryTotals[cat.label] ?? 0.0;
          final count = categoryCounts[cat.label] ?? 0;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryTransactionsScreen(category: cat),
                ),
              ).then((changed) {
                if (changed == true && onCategoriesChanged != null) {
                  onCategoriesChanged!();
                }
              });
            },
            child: Column(children: [
              Row(children: [
                _icon(cat.icon, cat.color),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("$count Transactions", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    _getRulesFor(cat.label),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ])),
                Text(
                  PrivacyManager.formatAmount(-total, showSign: true, decimal: true),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ]),
              if (!isLast) ...[const SizedBox(height: 10), Divider(color: Colors.white.withOpacity(0.05), height: 1), const SizedBox(height: 10)],
            ]),
          );
        }),
      ]),
    );
  }


  String _getRulesFor(String label) {
    final rulesList = AppCategories.categoryRules[label];
    if (rulesList == null || rulesList.isEmpty) return "Manual selection";
    return "Matches: ${rulesList.take(3).join(', ')}...";
  }

  Widget _icon(IconData icon, Color color) => Container(
    height: 48, width: 48,
    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 22),
  );
}