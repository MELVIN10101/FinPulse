import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/constants/categories_data.dart';
import '../../notifications/notification_screen.dart';
import '../../../core/privacy/privacy_manager.dart';

class MonthwiseTransactionsScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;
  final int selectedTab;

  const MonthwiseTransactionsScreen({
    super.key,
    this.onTabSwitch,
    this.selectedTab = 2,
  });

  @override
  State<MonthwiseTransactionsScreen> createState() =>
      _MonthwiseTransactionsScreenState();
}

class _MonthwiseTransactionsScreenState
    extends State<MonthwiseTransactionsScreen> {
  final _db = DatabaseHelper.instance;
  late int _selectedMonth;
  late int _selectedYear;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<TransactionModel> _dbTransactions = [];
  Map<String, double> _categoryTotals = {};
  Map<String, int> _categoryCounts = {};
  double _totalIncome = 0;
  bool _loading = true;
  late final StreamSubscription<TransactionModel> _txSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadData();
    _txSub = NotificationService.instance.onNewTransaction.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _txSub.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Date helpers ──────────────────────────────────────────────────────
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth == now.month && _selectedYear == now.year;
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    if (!_isCurrentMonth) {
      setState(() {
        if (_selectedMonth == 12) {
          _selectedMonth = 1;
          _selectedYear++;
        } else {
          _selectedMonth++;
        }
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final start = DateTime(_selectedYear, _selectedMonth, 1);
    final end = DateTime(
      _selectedMonth < 12 ? _selectedYear : _selectedYear + 1,
      _selectedMonth < 12 ? _selectedMonth + 1 : 1,
      1,
    ).subtract(const Duration(seconds: 1));

    final txs = await _db.getTransactionsForDateRange(start, end);
    final cats = await _db.getCategoryTotals(start: start, end: end);
    final counts = await _db.getCategoryCounts(start: start, end: end);
    final income = await _db.getTotalIncome(start: start, end: end);

    if (!mounted) return;
    setState(() {
      _dbTransactions = txs;
      _categoryTotals = cats;
      _categoryCounts = counts;
      _totalIncome = income;
      _loading = false;
    });
  }

  String _mFull(int m) => const [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
      ][m - 1];

  String _mShort(int m) => const [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
      ][m - 1];

  // ── Category meta ─────────────────────────────────────────────────────
  IconData _iconFor(String cat) => AppCategories.getByName(cat).icon;
  Color _colorFor(String cat) => AppCategories.getByName(cat).color;

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
                        await _db.updateTransactionCategory(tx.id!, cat.label);
                        await AppCategories.loadFromDatabase();
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
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

  // ── Filtering ─────────────────────────────────────────────────────────
  List<TransactionModel> get _filtered {
    if (_searchQuery.isEmpty) return _dbTransactions;
    return _dbTransactions.where((tx) {
      return tx.merchant.toLowerCase().contains(_searchQuery) ||
          tx.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  double get _totalExpenses =>
      _categoryTotals.values.fold(0.0, (s, v) => s + v);

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return "TODAY, ${_mShort(date.month).toUpperCase()} ${date.day}";
    if (d == today.subtract(const Duration(days: 1))) {
      return "YESTERDAY, ${_mShort(date.month).toUpperCase()} ${date.day}";
    }
    const w = ["MON","TUE","WED","THU","FRI","SAT","SUN"];
    return "${w[date.weekday - 1]}, ${_mShort(date.month).toUpperCase()} ${date.day}";
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in filtered) {
      final date = DateTime.tryParse(tx.timestamp) ?? DateTime.now();
      final label = _dayLabel(date);
      grouped.putIfAbsent(label, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: ListenableBuilder(
        listenable: PrivacyManager.instance,
        builder: (context, _) => SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthSelector(),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                      )
                    else ...[
                      if (_searchQuery.isEmpty) ...[
                        _buildSpendingCard(),
                        const SizedBox(height: 28),
                      ],
                      Text(
                        _searchQuery.isEmpty
                            ? "TRANSACTIONS FOR THIS MONTH"
                            : "SEARCH RESULTS",
                        style: const TextStyle(
                            fontSize: 12, letterSpacing: 1.4,
                            fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _buildEmptyState()
                      else
                        ...grouped.entries.map((entry) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(
                                        fontSize: 12, letterSpacing: 1.2,
                                        color: Color(0xFF64748B))),
                                const SizedBox(height: 12),
                                ...entry.value.map((tx) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _transactionCard(tx),
                                    )),
                                const SizedBox(height: 8),
                              ],
                            )),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Center(
              child: Text("Transactions",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ),
              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFF0C1A2B), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "Search transactions",
                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                child: const Padding(padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.close, color: Color(0xFF64748B), size: 18)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFF0C1A2B), borderRadius: BorderRadius.circular(30)),
        child: Row(children: [_tab("DAILY", 0), _tab("WEEKLY", 1), _tab("MONTHLY", 2)]),
      ),
    );
  }

  Widget _tab(String label, int index) {
    final isSelected = widget.selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabSwitch?.call(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                letterSpacing: 0.4,
              )),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(onTap: _prevMonth,
            child: const Icon(Icons.chevron_left, color: Colors.white70, size: 28)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text("${_mFull(_selectedMonth)} $_selectedYear",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            _isCurrentMonth ? "CURRENT MONTH" : "$_selectedYear",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1.2),
          ),
        ]),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _nextMonth,
          child: Container(
            height: 30, width: 30,
            decoration: const BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
            child: Icon(Icons.chevron_right,
                color: _isCurrentMonth
                    ? const Color(0xFF3B82F6).withOpacity(0.3)
                    : Colors.white70,
                size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingCard() {
    final expenseEntries = _categoryTotals.entries.toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFF0C1A2B), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("MONTHLY SPENDING",
                style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: Color(0xFF94A3B8))),
            SizedBox(height: 8),
          ]),
          const Spacer(),
          _miniBarChart(),
        ]),
        Text(
          PrivacyManager.formatAmount(_totalExpenses, showSign: false, decimal: true),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 22),
        // Display all expense categories
        ...AppCategories.expenseCategories.map((cat) {
          final total = _categoryTotals[cat.label] ?? 0.0;
          return Column(children: [
            _categoryRow(cat.label, total, false),
            const Divider(color: Color(0xFF1E293B), height: 20),
          ]);
        }),
        if (_totalIncome > 0) _categoryRow('Income', _totalIncome, true),
      ]),
    );
  }

  Widget _miniBarChart() {
    final heights = [25.0, 38.0, 20.0, 48.0, 32.0, 28.0, 40.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) => Container(
            width: 7, height: h,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: h == 48 ? const Color(0xFF3B82F6) : const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(4),
            ),
          )).toList(),
    );
  }

  Widget _categoryRow(String label, double amount, bool isIncome) {
    final color = _colorFor(label);
    final icon = _iconFor(label);
    final count = _categoryCounts[label] ?? 0;
    return Row(children: [
      Container(
        height: 42, width: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        if (count > 0) Text("$count items",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ])),
      Text(
        PrivacyManager.formatAmount(isIncome ? amount : -amount, showSign: true, decimal: true),
        style: TextStyle(
            color: isIncome ? const Color(0xFF22C55E) : Colors.white,
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ]);
  }

  Widget _transactionCard(TransactionModel tx) {
    final isIncome = tx.amount > 0;
    final iconColor = _colorFor(tx.category);
    final icon = _iconFor(tx.category);
    final timestamp = DateTime.tryParse(tx.timestamp);
    final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp) : '';
    final dateStr = timestamp != null
        ? "${timestamp.day} ${_mFull(timestamp.month)}, ${timestamp.year}"
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFF0C1A2B), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(height: 52, width: 52,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.merchant,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text("$timeStr · $dateStr",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            PrivacyManager.formatAmount(tx.amount, showSign: true, decimal: true),
            style: TextStyle(
                color: isIncome ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _changeCategory(context, tx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withOpacity(0.2)),
              ),
              child: Text(
                tx.category.toUpperCase(),
                style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(children: [
        Icon(_searchQuery.isEmpty ? Icons.receipt_outlined : Icons.search_off_rounded,
            color: const Color(0xFF3B82F6), size: 48),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isEmpty
              ? "No transactions for this month"
              : "No transactions found for\n\"$_searchQuery\"",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
      ]),
    );
  }
}
