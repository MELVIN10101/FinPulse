import 'package:flutter/material.dart';
import 'dart:math';
import '../../notifications/notification_screen.dart';

class DaywiseTransactionsScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;
  final int selectedTab;

  const DaywiseTransactionsScreen({
    super.key,
    this.onTabSwitch,
    this.selectedTab = 0,
  });

  @override
  State<DaywiseTransactionsScreen> createState() =>
      _DaywiseTransactionsScreenState();
}

class _DaywiseTransactionsScreenState
    extends State<DaywiseTransactionsScreen> {
  late int selectedDay;
  late int selectedMonth;
  late int selectedYear;

  // ── Search ────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Day selector scroll ───────────────────────────────────────────────
  final ScrollController _dayScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDay = now.day;
    selectedMonth = now.month;
    selectedYear = now.year;

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    // Auto-scroll day selector to today after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    // Each item is 64px wide + 8px separator = 72px
    const itemWidth = 72.0;
    final offset = (selectedDay - 1) * itemWidth;
    if (_dayScrollController.hasClients) {
      _dayScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  final List<String> _monthNames = const [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  static const _weekdayShort = ["MON","TUE","WED","THU","FRI","SAT","SUN"];

  List<int> _daysInMonth(int year, int month) {
    final next = (month < 12)
        ? DateTime(year, month + 1, 1)
        : DateTime(year + 1, 1, 1);
    return List.generate(
        next.subtract(const Duration(days: 1)).day, (i) => i + 1);
  }

  String _weekdayOf(int day) {
    final d = DateTime(selectedYear, selectedMonth, day);
    return _weekdayShort[d.weekday - 1];
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return "TH";
    switch (day % 10) {
      case 1: return "ST";
      case 2: return "ND";
      case 3: return "RD";
      default: return "TH";
    }
  }

  // ── Transaction data ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _generateTransactions(int day) {
    final r = Random(day * selectedMonth * selectedYear);
    return [
      {
        "icon": Icons.home_rounded,
        "iconColor": const Color(0xFF3B82F6),
        "title": "Monthly Rent",
        "time": "10:00 PM",
        "amount": -900.0 - r.nextInt(120),
        "category": "BILLS",
      },
      {
        "icon": Icons.directions_car_rounded,
        "iconColor": const Color(0xFF8B5CF6),
        "title": "Uber Trip",
        "time": "06:20 PM",
        "amount": -20.0 - r.nextDouble() * 30,
        "category": "TRANSPORT",
      },
      {
        "icon": Icons.restaurant_rounded,
        "iconColor": const Color(0xFFFF8A34),
        "title": "Starbucks Coffee",
        "time": "04:30 PM",
        "amount": -10.0 - r.nextDouble() * 15,
        "category": "FOOD",
      },
      {
        "icon": Icons.shopping_bag_rounded,
        "iconColor": const Color(0xFFEF4444),
        "title": "Shopping",
        "time": "02:15 PM",
        "amount": -50.0 - r.nextDouble() * 200,
        "category": "SHOPPING",
      },
      {
        "icon": Icons.local_grocery_store_rounded,
        "iconColor": const Color(0xFF22C55E),
        "title": "Fresh Mart Groceries",
        "time": "11:00 AM",
        "amount": -30.0 - r.nextDouble() * 80,
        "category": "GROCERIES",
      },
      {
        "icon": Icons.attach_money_rounded,
        "iconColor": const Color(0xFF22C55E),
        "title": "Freelance Payment",
        "time": "09:00 AM",
        "amount": 150.0 + r.nextDouble() * 250,
        "category": "INCOME",
      },
    ];
  }

  List<Map<String, dynamic>> _filteredTransactions(
      List<Map<String, dynamic>> all) {
    if (_searchQuery.isEmpty) return all;
    return all.where((tx) {
      final title = (tx["title"] as String).toLowerCase();
      final cat = (tx["category"] as String).toLowerCase();
      return title.contains(_searchQuery) || cat.contains(_searchQuery);
    }).toList();
  }

  double _calculateTotal(List<Map<String, dynamic>> list) =>
      list.fold(0.0, (s, tx) => s + (tx["amount"] as num).toDouble());

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(selectedYear, selectedMonth);
    if (!days.contains(selectedDay)) selectedDay = days.last;

    final allTx = _generateTransactions(selectedDay);
    final filtered = _filteredTransactions(allTx);
    final total = _calculateTotal(allTx); // total always from full list

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
                    _buildDropdowns(),
                    const SizedBox(height: 16),
                    _buildDaySelector(days),
                    const SizedBox(height: 24),
                    _buildTotalCard(total),
                    const SizedBox(height: 28),
                    Text(
                      _searchQuery.isEmpty
                          ? "TRANSACTIONS OF THE DAY"
                          : "SEARCH RESULTS",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ...filtered.map((tx) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _transactionCard(
                              icon: tx["icon"],
                              iconColor: tx["iconColor"],
                              title: tx["title"],
                              subtitle:
                                  "${tx["time"]} · $selectedDay ${_monthNames[selectedMonth - 1]}, $selectedYear",
                              amount: (tx["amount"] as num).toDouble(),
                              category: tx["category"],
                            ),
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
          // Balanced spacer (same width as bell button)
          const SizedBox(width: 40),
          const Expanded(
            child: Center(
              child: Text(
                "Transactions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
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
                  child: Icon(Icons.close,
                      color: Color(0xFF64748B), size: 18),
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
          children: [
            _tab("DAILY", 0),
            _tab("WEEKLY", 1),
            _tab("MONTHLY", 2),
          ],
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
            color:
                isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdowns() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1A2B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedMonth,
                dropdownColor: const Color(0xFF0C1A2B),
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF64748B)),
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                      value: i + 1, child: Text(_monthNames[i])),
                ),
                onChanged: (v) {
                  setState(() {
                    selectedMonth = v!;
                    // Clamp day to valid range for new month
                    final max = _daysInMonth(selectedYear, selectedMonth).length;
                    if (selectedDay > max) selectedDay = max;
                  });
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToSelected());
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 120,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1A2B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedYear,
              dropdownColor: const Color(0xFF0C1A2B),
              style:
                  const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFF64748B)),
              items: List.generate(5, (i) {
                final year = DateTime.now().year - 2 + i;
                return DropdownMenuItem(
                    value: year, child: Text("$year"));
              }),
              onChanged: (v) {
                setState(() => selectedYear = v!);
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToSelected());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelector(List<int> days) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selectedDay == day;
          final weekday = _weekdayOf(day);

          return GestureDetector(
            onTap: () {
              setState(() => selectedDay = day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFF0C1A2B),
                border: isSelected
                    ? Border.all(
                        color:
                            const Color(0xFF3B82F6).withOpacity(0.5),
                        width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$day",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A2B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "TOTAL SPENT · ${_weekdayOf(selectedDay)}, ${selectedDay}${_ordinal(selectedDay)} ${_monthNames[selectedMonth - 1].toUpperCase()}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "₹${total.abs().toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double amount,
    required String category,
  }) {
    final isIncome = amount > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A2B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isIncome ? '+' : '-'}₹${amount.abs().toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isIncome
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 5),
              Text(category,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
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
