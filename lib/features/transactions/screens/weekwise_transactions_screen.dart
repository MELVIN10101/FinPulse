import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/notification_service.dart';
import '../../notifications/notification_screen.dart';

class WeekwiseTransactionsScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;
  final int selectedTab;

  const WeekwiseTransactionsScreen({
    super.key,
    this.onTabSwitch,
    this.selectedTab = 1,
  });

  @override
  State<WeekwiseTransactionsScreen> createState() =>
      _WeekwiseTransactionsScreenState();
}

class _WeekwiseTransactionsScreenState
    extends State<WeekwiseTransactionsScreen> {
  final _db = DatabaseHelper.instance;
  late DateTime _weekStart;

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
    _weekStart = _getWeekStart(DateTime.now());
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
  DateTime _getWeekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final cur = _getWeekStart(now);
    return _weekStart.year == cur.year &&
        _weekStart.month == cur.month &&
        _weekStart.day == cur.day;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final start = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    final end = DateTime(_weekEnd.year, _weekEnd.month, _weekEnd.day, 23, 59, 59);

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

  String _fmt(DateTime d) => "${_mShort(d.month)} ${d.day}";

  String _mShort(int m) => const [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
      ][m - 1];

  String _mFull(int m) => const [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
      ][m - 1];

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadData();
  }

  void _nextWeek() {
    final next = _weekStart.add(const Duration(days: 7));
    if (!next.isAfter(DateTime.now())) {
      setState(() => _weekStart = next);
      _loadData();
    }
  }

  // ── Category meta ─────────────────────────────────────────────────────
  static const _catMeta = {
    'Food':          {'icon': Icons.restaurant_rounded,          'color': Color(0xFFEAB308)},
    'Shopping':      {'icon': Icons.shopping_bag_rounded,        'color': Color(0xFFFF8A34)},
    'Transportation':     {'icon': Icons.directions_car_rounded,      'color': Color(0xFF8B5CF6)},
    'Bills':         {'icon': Icons.receipt_long_rounded,        'color': Color(0xFF3B82F6)},
    'Entertainment': {'icon': Icons.movie_rounded,               'color': Color(0xFFEC4899)},
    'Groceries':     {'icon': Icons.local_grocery_store_rounded, 'color': Color(0xFF22C55E)},
    'Health':        {'icon': Icons.favorite_rounded,            'color': Color(0xFFEF4444)},
    'Income':        {'icon': Icons.attach_money_rounded,        'color': Color(0xFF22C55E)},
  };

  IconData _iconFor(String cat) =>
      (_catMeta[cat]?['icon'] as IconData?) ?? Icons.receipt_outlined;
  Color _colorFor(String cat) =>
      (_catMeta[cat]?['color'] as Color?) ?? const Color(0xFF64748B);

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
      body: SafeArea(
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
                    _buildWeekSelector(),
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
                            ? "TRANSACTIONS FOR THIS WEEK"
                            : "SEARCH RESULTS",
                        style: const TextStyle(
                          fontSize: 12, letterSpacing: 1.4,
                          fontWeight: FontWeight.w600, color: Color(0xFF64748B),
                        ),
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
      ),
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

  Widget _buildWeekSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _prevWeek,
          child: const Icon(Icons.chevron_left, color: Colors.white70, size: 28),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(
            "${_fmt(_weekStart)} - ${_fmt(_weekEnd)}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            _isCurrentWeek ? "CURRENT WEEK" : _mFull(_weekStart.month).toUpperCase(),
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1.2),
          ),
        ]),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _nextWeek,
          child: Container(
            height: 30, width: 30,
            decoration: const BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
            child: Icon(Icons.chevron_right,
                color: _isCurrentWeek
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
            Text("WEEKLY SPENDING",
                style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: Color(0xFF94A3B8))),
            SizedBox(height: 8),
          ]),
          const Spacer(),
          _miniBarChart(),
        ]),
        Text("₹${_totalExpenses.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 22),
        if (expenseEntries.isEmpty)
          const Text("No expenses this week",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14))
        else
          ...expenseEntries.map((e) => Column(children: [
                _categoryRow(e.key, e.value, false),
                const Divider(color: Color(0xFF1E293B), height: 20),
              ])),
        if (_totalIncome > 0) _categoryRow('Income', _totalIncome, true),
      ]),
    );
  }

  Widget _miniBarChart() {
    // Use actual daily spend data based on week – just show the last 7 bars relative to the week
    final heights = [20.0, 30.0, 18.0, 42.0, 28.0, 22.0, 35.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) => Container(
            width: 7, height: h,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: h == 42 ? const Color(0xFF3B82F6) : const Color(0xFF1E3A5F),
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
        "${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(2)}",
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
      child: Row(
        children: [
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
              "${isIncome ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(2)}",
              style: TextStyle(
                  color: isIncome ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(tx.category.toUpperCase(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ],
      ),
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
              ? "No transactions for this week"
              : "No transactions found for\n\"$_searchQuery\"",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
      ]),
    );
  }
}
