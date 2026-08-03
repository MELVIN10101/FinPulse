import 'package:flutter/material.dart';
import '../../core/constants/categories_data.dart';
import '../../data/local/database_helper.dart';
import '../../data/services/local_ai_classifier.dart';

class UncategorizedItem {
  final String merchant;
  final String type; // 'income' or 'expense'
  final int count;

  UncategorizedItem({
    required this.merchant,
    required this.type,
    required this.count,
  });
}

class UncategorizedAccountsScreen extends StatefulWidget {
  const UncategorizedAccountsScreen({super.key});

  @override
  State<UncategorizedAccountsScreen> createState() => _UncategorizedAccountsScreenState();
}

class _UncategorizedAccountsScreenState extends State<UncategorizedAccountsScreen> {
  final _db = DatabaseHelper.instance;
  List<UncategorizedItem> _uncategorizedMerchants = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadUncategorized();
  }

  Future<void> _loadUncategorized() async {
    setState(() => _loading = true);
    
    // Fetch all transactions to perform case-insensitive and robust in-memory checking
    final allTxs = await _db.getAllTransactions();
    final txs = allTxs.where((tx) {
      final cat = tx.category.trim().toLowerCase();
      return cat == 'other' || cat == 'uncategorized';
    }).toList();
    
    // Group transactions by merchant and type
    final Map<String, int> counts = {}; // key: "merchant|type"
    for (final tx in txs) {
      final merchant = tx.merchant.trim();
      if (merchant.isNotEmpty) {
        final key = "$merchant|${tx.type}";
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final List<UncategorizedItem> items = counts.entries.map((e) {
      final parts = e.key.split('|');
      return UncategorizedItem(
        merchant: parts[0],
        type: parts[1],
        count: e.value,
      );
    }).toList();

    // Sort by transaction count descending
    items.sort((a, b) => b.count.compareTo(a.count));

    if (mounted) {
      setState(() {
        _uncategorizedMerchants = items;
        _loading = false;
      });
    }
  }

  void _mapMerchant(String merchant, String type, int count) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Differentiate categories: Incoming -> Income, Outgoing -> Expense categories
        final categories = type == 'income'
            ? AppCategories.all.where((c) => c.label == 'Income').toList()
            : AppCategories.expenseCategories;

        final prediction = LocalAIClassifier.instance.predict(merchant);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Map: $merchant",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Affects $count ${type == 'income' ? 'incoming' : 'outgoing'} transaction(s) and future rules",
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Text(
                type == 'income' ? "SELECT TARGET INCOME CATEGORY" : "SELECT TARGET EXPENSE CATEGORY",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isAIRecommended = cat.label == prediction.category && prediction.confidence >= 0.4;

                    return GestureDetector(
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        // 1. Add keyword to rules list
                        final rules = AppCategories.categoryRules[cat.label] ?? [];
                        final newKeyword = merchant.toLowerCase().trim();
                        if (!rules.contains(newKeyword)) {
                          rules.add(newKeyword);
                          AppCategories.categoryRules[cat.label] = rules;
                          await AppCategories.saveRules();
                        }

                        // 2. Update existing transactions
                        await _db.updateTransactionsCategoryByMerchant(merchant, cat.label);

                        // 3. Retrain Local AI Classifier
                        final allTxs = await _db.getAllTransactions();
                        LocalAIClassifier.instance.train(allTxs);

                        if (mounted) {
                          setState(() {
                            _changed = true;
                          });
                        }
                        
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(cat.icon, color: cat.color, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Successfully mapped '$merchant' to ${cat.label}",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF1E293B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                        
                        navigator.pop();
                        _loadUncategorized();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAIRecommended ? cat.color.withOpacity(0.4) : Colors.white.withOpacity(0.04),
                            width: isAIRecommended ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: cat.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 18),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isAIRecommended) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Smart AI Suggestion (${(prediction.confidence * 100).toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      color: cat.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080B10),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context, _changed),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
            ),
          ),
          title: const Text(
            "Uncategorized Accounts",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : _uncategorizedMerchants.isEmpty
                ? _buildEmptyState()
                : _buildMerchantsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 50,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "All Accounts Categorized!",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Every merchant and transaction has been successfully mapped to its respective category.",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _uncategorizedMerchants.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _uncategorizedMerchants[index];
        final isIncome = item.type == 'income';

        return GestureDetector(
          onTap: () => _mapMerchant(item.merchant, item.type, item.count),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1A2B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isIncome ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isIncome ? const Color(0xFF22C55E) : const Color(0xFFFF8A34),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.merchant,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isIncome ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isIncome ? "INCOMING" : "OUTGOING",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isIncome ? const Color(0xFF22C55E) : const Color(0xFFFF8A34),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${item.count} transaction(s)",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        "Map",
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Color(0xFF3B82F6), size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
