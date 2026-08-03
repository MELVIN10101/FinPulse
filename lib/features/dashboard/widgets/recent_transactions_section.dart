import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/constants/categories_data.dart';
import '../../../data/local/database_helper.dart';
import '../../navigation/main_navigation_screen.dart';
import '../../../core/privacy/privacy_manager.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final VoidCallback? onTransactionChanged;

  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    this.onTransactionChanged,
  });

  void _changeCategory(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final categories = AppCategories.all;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Move ${tx.merchant}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  )
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "CHOOSE NEW CATEGORY",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = tx.category == cat.label;
                  return GestureDetector(
                    onTap: () async {
                      if (tx.id != null) {
                        await DatabaseHelper.instance.updateTransactionCategory(tx.id!, cat.label);
                        await AppCategories.loadFromDatabase();
                        if (context.mounted) Navigator.pop(context);
                        if (onTransactionChanged != null) {
                          onTransactionChanged!();
                        }
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? cat.color : cat.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            cat.icon,
                            color: isSelected ? Colors.black : cat.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
          final info = AppCategories.getByName(tx.category);
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
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(color: info.color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(info.icon, color: info.color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx.merchant, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    PrivacyManager.formatAmount(tx.amount, showSign: true, decimal: true),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isIncome ? const Color(0xFF22C55E) : Colors.redAccent),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _changeCategory(context, tx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: info.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: info.color.withOpacity(0.2)),
                      ),
                      child: Text(
                        tx.category.toUpperCase(),
                        style: TextStyle(fontSize: 11, color: info.color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        }),
    ]);
  }
}