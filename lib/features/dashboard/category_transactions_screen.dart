import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/categories_data.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../core/privacy/privacy_manager.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final CategoryData category;
  const CategoryTransactionsScreen({super.key, required this.category});

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  final _db = DatabaseHelper.instance;
  List<TransactionModel> _transactions = [];
  bool _loading = true;
  bool _isDragging = false;
  int? _expandedTxId;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final txs = await _db.getTransactionsByCategory(widget.category.label);
    if (mounted) {
      setState(() {
        _transactions = txs;
        _loading = false;
      });
    }
  }

  Future<void> _moveTransaction(TransactionModel tx, String targetCategoryLabel) async {
    if (tx.id == null) return;

    // Slide out/shrink animation list state update first for visual reward
    setState(() {
      _transactions.removeWhere((t) => t.id == tx.id);
      _changed = true;
      if (_expandedTxId == tx.id) {
        _expandedTxId = null;
      }
    });

    // Perform database update
    await _db.updateTransactionCategory(tx.id!, targetCategoryLabel);

    // Show a premium glassmorphic feedback snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                AppCategories.getByName(targetCategoryLabel).icon,
                color: AppCategories.getByName(targetCategoryLabel).color,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Moved Tx #${tx.id} to $targetCategoryLabel",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Undo operation
                  await _db.updateTransactionCategory(tx.id!, widget.category.label);
                  _loadTransactions();
                },
                child: const Text(
                  "UNDO",
                  style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  double get _totalSpend {
    double total = 0;
    for (final tx in _transactions) {
      total += tx.amount.abs();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final otherCategories = AppCategories.expenseCategories
        .where((c) => c.label != widget.category.label)
        .toList();

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
          title: Text(
            widget.category.label,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: PrivacyManager.instance,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                _buildCategoryHeader(),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                      : _transactions.isEmpty
                          ? _buildEmptyState()
                          : _buildTransactionList(otherCategories),
                ),
              ],
            ),
              // Innovative bottom category deck triggered on drag
              if (_isDragging) _buildBottomDragDeck(otherCategories),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    final rules = AppCategories.categoryRules[widget.category.label] ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.category.color.withOpacity(0.12),
            const Color(0xFF0C1A2B),
          ],
        ),
        border: Border.all(color: widget.category.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: widget.category.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.category.color.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(widget.category.icon, color: widget.category.color, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_transactions.length} Transactions",
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Total spend in ${widget.category.label}",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                PrivacyManager.formatAmount(-_totalSpend, showSign: true, decimal: true),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "CONSIDERED ACCOUNTS & MERCHANTS",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                onTap: _editCategoryRules,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(Icons.edit_rounded, color: widget.category.color, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rules.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules.map((rule) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.category.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.category.color.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    rule,
                    style: TextStyle(
                      color: widget.category.color.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Text(
              "Manual selection (no auto-match rules)",
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  void _editCategoryRules() {
    final rules = List<String>.from(AppCategories.categoryRules[widget.category.label] ?? []);
    final keywordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: SingleChildScrollView(
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
                                  "Edit Rules: ${widget.category.label}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Keywords for auto-categorization",
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                      const SizedBox(height: 20),
                      const Text(
                        "ADD KEYWORD",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: TextField(
                                controller: keywordController,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  hintText: "e.g. zomato, netflix, uber",
                                  hintStyle: TextStyle(color: Color(0xFF475569)),
                                ),
                                onSubmitted: (_) {
                                  final val = keywordController.text.trim().toLowerCase();
                                  if (val.isNotEmpty && !rules.contains(val)) {
                                    setModalState(() {
                                      rules.add(val);
                                      keywordController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              final val = keywordController.text.trim().toLowerCase();
                              if (val.isNotEmpty && !rules.contains(val)) {
                                setModalState(() {
                                  rules.add(val);
                                  keywordController.clear();
                                });
                              }
                            },
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: widget.category.color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: widget.category.color.withOpacity(0.3)),
                              ),
                              child: Icon(Icons.add_rounded, color: widget.category.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "CURRENT KEYWORDS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (rules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "No keywords defined. Transactions will not be auto-categorized here.",
                            style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: rules.map((rule) {
                            return Container(
                              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    rule,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        rules.remove(rule);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () async {
                            AppCategories.categoryRules[widget.category.label] = rules;
                            final navigator = Navigator.of(context);
                            await AppCategories.saveRules();
                            if (mounted) {
                              setState(() {
                                _changed = true;
                              });
                            }
                            navigator.pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1A2B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Transactions Found",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            "Move transactions here or add new ones.",
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<CategoryData> otherCategories) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final isExpanded = _expandedTxId == tx.id;

        // Custom draggable transaction card
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LongPressDraggable<TransactionModel>(
            data: tx,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.8,
                child: _buildTransactionCard(tx, false, otherCategories),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildTransactionCard(tx, false, otherCategories),
            ),
            onDragStarted: () {
              setState(() => _isDragging = true);
            },
            onDragEnd: (details) {
              setState(() => _isDragging = false);
            },
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _expandedTxId = isExpanded ? null : tx.id;
                });
              },
              child: _buildTransactionCard(tx, isExpanded, otherCategories),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(
    TransactionModel tx,
    bool isExpanded,
    List<CategoryData> otherCategories,
  ) {
    final date = DateTime.tryParse(tx.timestamp) ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy • hh:mm a').format(date);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? widget.category.color.withOpacity(0.3) : Colors.white.withOpacity(0.04),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: widget.category.color.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.category.icon, color: widget.category.color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PrivacyManager.formatAmount(-tx.amount.abs(), showSign: true, decimal: true),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Prominent Transaction ID Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      "ID: #${tx.id}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            if (tx.note.isNotEmpty) ...[
              const Text(
                "NOTE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tx.note,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "QUICK MOVE CATEGORY",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            // Fluid quick-select chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: otherCategories.map((c) {
                return GestureDetector(
                  onTap: () => _moveTransaction(tx, c.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.color.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon, size: 13, color: c.color),
                        const SizedBox(width: 6),
                        Text(
                          c.label,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // Floating bottom category targets deck for drag and drop
  Widget _buildBottomDragDeck(List<CategoryData> otherCategories) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xEC0F172B), // Glassmorphic translucent dark slate
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.swipe_up_rounded, color: Color(0xFF3B82F6), size: 16),
                SizedBox(width: 8),
                Text(
                  "Drag & Drop here to re-categorize",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: otherCategories.map((c) {
                  return DragTarget<TransactionModel>(
                    onWillAccept: (data) => data != null,
                    onAccept: (tx) => _moveTransaction(tx, c.label),
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isHovered ? c.color.withOpacity(0.25) : const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered ? c.color : Colors.white.withOpacity(0.05),
                            width: isHovered ? 2.5 : 1.0,
                          ),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: c.color.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        transform: Matrix4.identity()..scale(isHovered ? 1.2 : 1.0),
                        child: Icon(c.icon, color: isHovered ? Colors.white : c.color, size: 24),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
