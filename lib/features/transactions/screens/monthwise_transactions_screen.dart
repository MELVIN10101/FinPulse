import 'package:flutter/material.dart';
import '../../notifications/notification_screen.dart';

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
  late int _selectedMonth;
  late int _selectedYear;

  // ── Search ───────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Date helpers ─────────────────────────────────────────────────────
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
    }
  }

  String _mFull(int m) => const [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
      ][m - 1];

  String _mShort(int m) => const [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
      ][m - 1];

  int get _daysInMonth {
    final firstNext = (_selectedMonth < 12)
        ? DateTime(_selectedYear, _selectedMonth + 1, 1)
        : DateTime(_selectedYear + 1, 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }

  // ── All transactions ─────────────────────────────────────────────────
  List<Map<String, dynamic>> get _allTransactions => [
        {
          "icon": Icons.restaurant_rounded,
          "iconColor": const Color(0xFFEAB308),
          "title": "Starbucks Coffee",
          "date": DateTime(_selectedYear, _selectedMonth,
              DateTime.now().day.clamp(1, _daysInMonth)),
          "time": "08:45 AM",
          "amount": -12.50,
          "category": "FOOD",
        },
        {
          "icon": Icons.shopping_bag_rounded,
          "iconColor": const Color(0xFFFF8A34),
          "title": "Electronics Hub",
          "date": DateTime(_selectedYear, _selectedMonth,
              (DateTime.now().day - 1).clamp(1, _daysInMonth)),
          "time": "11:30 AM",
          "amount": -1199.00,
          "category": "SHOPPING",
        },
        {
          "icon": Icons.directions_car_rounded,
          "iconColor": const Color(0xFF8B5CF6),
          "title": "Uber Trip",
          "date": DateTime(_selectedYear, _selectedMonth,
              (DateTime.now().day - 1).clamp(1, _daysInMonth)),
          "time": "06:20 PM",
          "amount": -24.50,
          "category": "TRANSPORT",
        },
        {
          "icon": Icons.receipt_long_rounded,
          "iconColor": const Color(0xFF3B82F6),
          "title": "Monthly Rent",
          "date": DateTime(_selectedYear, _selectedMonth, 1),
          "time": "10:00 AM",
          "amount": -1500.00,
          "category": "BILLS",
        },
        {
          "icon": Icons.local_grocery_store_rounded,
          "iconColor": const Color(0xFF22C55E),
          "title": "Fresh Mart Groceries",
          "date": DateTime(_selectedYear, _selectedMonth,
              (DateTime.now().day - 5).clamp(1, _daysInMonth)),
          "time": "03:15 PM",
          "amount": -210.80,
          "category": "GROCERIES",
        },
        {
          "icon": Icons.favorite_rounded,
          "iconColor": const Color(0xFFEF4444),
          "title": "Apollo Pharmacy",
          "date": DateTime(_selectedYear, _selectedMonth,
              (DateTime.now().day - 6).clamp(1, _daysInMonth)),
          "time": "12:00 PM",
          "amount": -120.00,
          "category": "HEALTH",
        },
        {
          "icon": Icons.movie_rounded,
          "iconColor": const Color(0xFFEC4899),
          "title": "Netflix Subscription",
          "date": DateTime(_selectedYear, _selectedMonth, 1),
          "time": "07:00 AM",
          "amount": -15.99,
          "category": "ENTERTAINMENT",
        },
        {
          "icon": Icons.attach_money_rounded,
          "iconColor": const Color(0xFF22C55E),
          "title": "Salary Credit",
          "date": DateTime(_selectedYear, _selectedMonth, 1),
          "time": "09:00 AM",
          "amount": 4800.00,
          "category": "INCOME",
        },
      ];

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_searchQuery.isEmpty) return _allTransactions;
    return _allTransactions.where((tx) {
      final title = (tx["title"] as String).toLowerCase();
      final category = (tx["category"] as String).toLowerCase();
      return title.contains(_searchQuery) || category.contains(_searchQuery);
    }).toList();
  }

  // ── Categories ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _categories {
    final seed = _selectedMonth * _selectedYear;
    final r = (seed % 100) / 100.0;
    return [
      {"icon": Icons.receipt_long_rounded,       "color": const Color(0xFF3B82F6), "label": "Bills",         "count": 4 + (seed % 4),  "amount": 3400.0 + r * 600},
      {"icon": Icons.shopping_cart_rounded,       "color": const Color(0xFFFF8A34), "label": "Shopping",      "count": 18 + (seed % 10),"amount": 2480.0 + r * 800},
      {"icon": Icons.favorite_rounded,            "color": const Color(0xFFEF4444), "label": "Health",        "count": 3 + (seed % 5),  "amount": 720.0 + r * 300},
      {"icon": Icons.local_grocery_store_rounded, "color": const Color(0xFF22C55E), "label": "Groceries",     "count": 12 + (seed % 8), "amount": 1360.0 + r * 400},
      {"icon": Icons.restaurant_rounded,          "color": const Color(0xFFEAB308), "label": "Food",          "count": 34 + (seed % 15),"amount": 1160.0 + r * 500},
      {"icon": Icons.directions_car_rounded,      "color": const Color(0xFF8B5CF6), "label": "Transport",     "count": 20 + (seed % 10),"amount": 560.0 + r * 200},
      {"icon": Icons.movie_rounded,               "color": const Color(0xFFEC4899), "label": "Entertainment", "count": 8 + (seed % 6),  "amount": 840.0 + r * 300},
      {"icon": Icons.attach_money_rounded,        "color": const Color(0xFF22C55E), "label": "Income",        "count": 2 + (seed % 2),  "amount": 9800.0 + r * 2000, "isIncome": true},
    ];
  }

  double get _totalSpending => _categories
      .where((c) => c["isIncome"] != true)
      .fold(0.0, (s, c) => s + (c["amount"] as double));

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return "TODAY, ${_mShort(date.month).toUpperCase()} ${date.day}";
    if (d == today.subtract(const Duration(days: 1)))
      return "YESTERDAY, ${_mShort(date.month).toUpperCase()} ${date.day}";
    const w = ["MON","TUE","WED","THU","FRI","SAT","SUN"];
    return "${w[date.weekday - 1]}, ${_mShort(date.month).toUpperCase()} ${date.day}";
  }

  String _formatSubtitle(String time, DateTime date) =>
      "$time · ${date.day} ${_mFull(date.month)}, ${date.year}";

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final tx in filtered) {
      final label = _dayLabel(tx["date"] as DateTime);
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
                    _buildMonthSelector(),
                    const SizedBox(height: 20),

                    if (_searchQuery.isEmpty) ...[
                      _buildSpendingCard(),
                      const SizedBox(height: 28),
                    ],

                    Text(
                      _searchQuery.isEmpty
                          ? "TRANSACTIONS FOR THIS MONTH"
                          : "SEARCH RESULTS",
                      style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B)),
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
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF64748B))),
                              const SizedBox(height: 12),
                              ...entry.value.map((tx) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _transactionCard(tx),
                                  )),
                              const SizedBox(height: 8),
                            ],
                          )),

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
              child: Text(
                "Transactions",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationScreen()),
              ),
              icon: const Icon(Icons.notifications_none,
                  color: Colors.white, size: 26),
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
        decoration: BoxDecoration(
          color: const Color(0xFF0C1A2B),
          borderRadius: BorderRadius.circular(14),
        ),
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
                  hintStyle:
                      TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child:
                      Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                ),
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
        decoration: BoxDecoration(
          color: const Color(0xFF0C1A2B),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [_tab("DAILY", 0), _tab("WEEKLY", 1), _tab("MONTHLY", 2)],
        ),
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _prevMonth,
          child: const Icon(Icons.chevron_left,
              color: Colors.white70, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "${_mFull(_selectedMonth)} $_selectedYear",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              _isCurrentMonth ? "CURRENT MONTH" : "$_selectedYear",
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _nextMonth,
          child: Container(
            height: 30,
            width: 30,
            decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F), shape: BoxShape.circle),
            child: Icon(
              Icons.chevron_right,
              color: _isCurrentMonth
                  ? const Color(0xFF3B82F6).withOpacity(0.3)
                  : Colors.white70,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingCard() {
    final cats = _categories;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: const Color(0xFF0C1A2B),
          borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MONTHLY SPENDING",
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          color: Color(0xFF94A3B8))),
                  SizedBox(height: 8),
                ]),
            const Spacer(),
            _miniBarChart(),
          ]),
          Text("₹${_totalSpending.toStringAsFixed(2)}",
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 22),
          ...cats.where((c) => c["isIncome"] != true).map((c) => Column(
                children: [
                  _categoryRow(c),
                  const Divider(color: Color(0xFF1E293B), height: 20),
                ],
              )),
          ...cats.where((c) => c["isIncome"] == true).map(_categoryRow),
        ],
      ),
    );
  }

  Widget _miniBarChart() {
    final heights = [25.0, 38.0, 20.0, 48.0, 32.0, 28.0, 40.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights
          .map((h) => Container(
                width: 7,
                height: h,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: h == 48
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(4),
                ),
              ))
          .toList(),
    );
  }

  Widget _categoryRow(Map<String, dynamic> c) {
    final isIncome = c["isIncome"] == true;
    final color = c["color"] as Color;
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
              color: color.withOpacity(0.18), shape: BoxShape.circle),
          child: Icon(c["icon"] as IconData, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c["label"] as String,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text("${c["count"]} items",
                style:
                    const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ),
        Text(
          "${isIncome ? '+' : '-'}₹${(c["amount"] as double).toStringAsFixed(2)}",
          style: TextStyle(
              color: isIncome ? const Color(0xFF22C55E) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final isIncome = (tx["amount"] as double) > 0;
    final iconColor = tx["iconColor"] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          color: const Color(0xFF0C1A2B),
          borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(tx["icon"] as IconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx["title"] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_formatSubtitle(tx["time"] as String, tx["date"] as DateTime),
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              "${isIncome ? '+' : '-'}₹${(tx["amount"] as double).abs().toStringAsFixed(2)}",
              style: TextStyle(
                  color: isIncome
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(tx["category"] as String,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              color: Color(0xFF3B82F6), size: 48),
          const SizedBox(height: 16),
          Text(
            "No transactions found for\n\"$_searchQuery\"",
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Color(0xFF64748B), fontSize: 15),
          ),
        ],
      ),
    );
  }
}
