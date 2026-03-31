import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../core/constants/categories_data.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  late TabController _tabCtrl;

  // ── Overview data ─────────────────────────────
  double _impulseScore = 0;
  double _impulseChange = 0;
  String _savingMindset = '';
  double _savingChange = 0;
  List<double> _weeklyBars = [];
  List<_DriverItem> _drivers = [];

  // ── Spending data ─────────────────────────────
  double _totalMonthly = 0;
  Map<String, double> _catTotals = {};
  List<TransactionModel> _recentTx = [];
  String _searchQuery = '';

  // ── Psychology data (static content) ──────────
  final List<_PsychCard> _psychCards = const [
    _PsychCard(
      icon: Icons.shield_rounded,
      iconBg: Color(0xFF7C3AED),
      title: 'Loss Aversion',
      body: 'You feel the pain of losing ₹500 more intensely than the joy '
          'of finding ₹500. This cognitive bias can trick you into holding '
          'on to bad investments or overspending on "deals" just to avoid '
          'missing out.',
      tag: '#behavioral_economics',
    ),
    _PsychCard(
      icon: Icons.anchor_rounded,
      iconBg: Color(0xFF2563EB),
      title: 'The Anchor Effect',
      body: 'Your brain subconsciously relies on the first piece of price '
          'info it sees. An original price of ₹5,000 marked down to '
          '₹3,000 feels like a win — even if the item isn\'t worth ₹3,000 '
          'objectively.',
      tag: '#cognitive_bias',
    ),
    _PsychCard(
      icon: Icons.trending_up_rounded,
      iconBg: Color(0xFFEAB308),
      title: 'Lifestyle Creep',
      body: 'As your income grows, your spending expands to match. Subtle '
          'upgrades — nicer dinners, subscription adds — erode savings '
          'without you noticing.',
      tag: '#spending_pattern',
    ),
    _PsychCard(
      icon: Icons.grid_view_rounded,
      iconBg: Color(0xFFEF4444),
      title: 'Choice Overload',
      body: 'Having too many options leads to decision fatigue and impulse '
          'purchases. Simplify by setting a ≤3-option rule for '
          'discretionary buys.',
      tag: '#decision_fatigue',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final weekStart = now.subtract(const Duration(days: 7));
    final prevWeekStart = now.subtract(const Duration(days: 14));

    final income = await _db.getTotalIncome(start: monthStart, end: monthEnd);
    final expense = await _db.getTotalExpense(start: monthStart, end: monthEnd);
    final thisWeekExp = await _db.getTotalExpense(start: weekStart, end: now);
    final lastWeekExp =
        await _db.getTotalExpense(start: prevWeekStart, end: weekStart);
    final cats = await _db.getCategoryTotals(start: monthStart, end: monthEnd);
    // Ensure all expense categories are present, even with 0.0
    for (final expCat in AppCategories.expenseCategories) {
      cats.putIfAbsent(expCat.label, () => 0.0);
    }

    final recent = await _db.getRecentTransactions(limit: 25);

    // ── Impulse Score ───────────────────────────
    double ratio = income > 0 ? (expense / income) : 1.0;
    double weekChange =
        lastWeekExp > 0 ? (thisWeekExp - lastWeekExp) / lastWeekExp : 0;
    double rawScore =
        (100 - (ratio * 60 + weekChange.abs() * 40)).clamp(0, 100);
    double impChange = lastWeekExp > 0 ? (-weekChange * 100) : 0;

    // ── Saving Mindset ──────────────────────────
    double savingsRate = income > 0 ? ((income - expense) / income) : 0;
    String mindset;
    double savChange;
    if (savingsRate > 0.2) {
      mindset = 'Growth';
      savChange = 5;
    } else if (savingsRate > 0.05) {
      mindset = 'Steady';
      savChange = 2;
    } else {
      mindset = 'At Risk';
      savChange = -8;
    }

    // ── Weekly Bars (last 7 days) ───────────────
    List<double> bars = [];
    for (int i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      bars.add(await _db.getTotalExpense(start: dayStart, end: dayEnd));
    }

    // ── Key Drivers ─────────────────────────────
    List<_DriverItem> drivers = [];
    // Morning ritual spending (food before noon)
    int morningCount = 0;
    double morningTotal = 0;
    for (final tx in recent) {
      final d = DateTime.tryParse(tx.timestamp);
      if (d != null &&
          d.hour < 12 &&
          tx.type == 'expense' &&
          (tx.category == 'Food' || tx.category == 'Groceries')) {
        morningCount++;
        morningTotal += tx.amount.abs();
      }
    }
    if (morningCount > 0) {
      drivers.add(_DriverItem(
        icon: Icons.coffee_rounded,
        iconBg: const Color(0xFFD97706),
        title: 'Morning Rituals',
        subtitle:
            'Dining accounts for ${expense > 0 ? (morningTotal / expense * 100).toStringAsFixed(0) : 0}% of impulse buys.',
        impactLabel: 'High',
        impactSub: 'IMPACT',
      ));
    }
    // Late-night spending
    int lateCount = 0;
    for (final tx in recent) {
      final d = DateTime.tryParse(tx.timestamp);
      if (d != null &&
          (d.hour >= 22 || d.hour < 2) &&
          tx.type == 'expense') {
        lateCount++;
      }
    }
    if (lateCount > 0) {
      drivers.add(_DriverItem(
        icon: Icons.nightlight_round,
        iconBg: const Color(0xFF6366F1),
        title: 'Late Night Activity',
        subtitle: 'Shopping spikes between 10 PM – 1 AM.',
        impactLabel: 'Med',
        impactSub: 'IMPACT',
      ));
    }
    // Savings efficiency
    if (savingsRate > 0) {
      drivers.add(_DriverItem(
        icon: Icons.savings_rounded,
        iconBg: const Color(0xFF22C55E),
        title: 'Auto-Save Efficiency',
        subtitle:
            'Saving ${(savingsRate * 100).toStringAsFixed(0)}% of income this month.',
        impactLabel: 'Positive',
        impactSub: 'BIAS',
      ));
    }

    if (!mounted) return;
    setState(() {
      _impulseScore = rawScore;
      _impulseChange = impChange;
      _savingMindset = mindset;
      _savingChange = savChange;
      _weeklyBars = bars;
      _drivers = drivers;
      _totalMonthly = expense;
      _catTotals = cats;
      _recentTx = recent;
      _loading = false;
    });
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF16191C),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF16191C),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            // ── Sticky Header ──
            SliverToBoxAdapter(
              child: _header()
                  .animate()
                  .fadeIn(duration: 300.ms),
            ),
            // ── Tab Bar ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: const Color(0xFF2E3F52),
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  dividerColor: const Color(0xFF2E3F52).withOpacity(0.3),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Spending'),
                    Tab(text: 'Psychology'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _overviewTab(),
              _spendingTab(),
              _psychologyTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: const Color(0xFF16191C),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2E3F52).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const Expanded(
            child: Text(
              'Behavioral Insights',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  TAB 1: OVERVIEW
  // ═══════════════════════════════════════════════
  Widget _overviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        // Title
        const Text('Financial Pulse',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Real-time analysis of your fiscal habits.',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
        const SizedBox(height: 20),

        // Score Grid
        Row(
          children: [
            Expanded(child: _scoreCard(
              label: 'Impulse Score',
              value: '${_impulseScore.toInt()}',
              suffix: '/100',
              change:
                  '${_impulseChange >= 0 ? '+' : ''}${_impulseChange.toStringAsFixed(0)}% vs last wk',
              changeColor: _impulseChange >= 0
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
              changeIcon: _impulseChange >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            )),
            const SizedBox(width: 12),
            Expanded(child: _scoreCard(
              label: 'Saving Mindset',
              value: _savingMindset,
              suffix: '',
              change:
                  '${_savingChange >= 0 ? '+' : ''}${_savingChange.toStringAsFixed(0)}% consistency',
              changeColor: _savingChange >= 0
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
              changeIcon: _savingChange >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            )),
          ],
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .moveY(begin: 16, end: 0),
        const SizedBox(height: 20),

        // Spending Velocity Chart
        _velocityChart()
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms)
            .moveY(begin: 16, end: 0),
        const SizedBox(height: 24),

        // Key Drivers
        const Text('Key Drivers',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        ..._drivers
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _driverTile(e.value),
                ))
            .toList()
            .animate(interval: 120.ms)
            .fadeIn(delay: 500.ms, duration: 350.ms)
            .moveX(begin: 20, end: 0),
      ],
    );
  }

  Widget _scoreCard({
    required String label,
    required String value,
    required String suffix,
    required String change,
    required Color changeColor,
    required IconData changeIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.1),
        border: Border.all(
            color: const Color(0xFF2E3F52).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              if (suffix.isNotEmpty)
                TextSpan(
                    text: suffix,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8))),
            ]),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(changeIcon, color: changeColor, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(change,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: changeColor),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _velocityChart() {
    final maxBar = _weeklyBars.isEmpty
        ? 1.0
        : _weeklyBars.reduce(max).clamp(1, double.infinity);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.05),
        border: Border.all(
            color: const Color(0xFF2E3F52).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Spending Velocity',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Weekly trend analysis',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3F52).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Last 7 Days',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFCBD5E1))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction =
                    _weeklyBars.length > i ? _weeklyBars[i] / maxBar : 0.0;
                // Highlight the max bar
                final isMax = _weeklyBars.length > i &&
                    _weeklyBars[i] == _weeklyBars.reduce(max);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FractionallySizedBox(
                      heightFactor: fraction.clamp(0.05, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                          color: isMax
                              ? const Color(0xFF2E3F52).withOpacity(0.8)
                              : const Color(0xFF2E3F52)
                                  .withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days
                .map((d) => Text(d,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.5)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _driverTile(_DriverItem d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.1),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: d.iconBg.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icon,
                color: d.iconBg.withOpacity(0.9), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(d.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(d.impactLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(d.impactSub,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  TAB 2: SPENDING
  // ═══════════════════════════════════════════════
  Widget _spendingTab() {
    final filteredTx = _searchQuery.isEmpty
        ? _recentTx
        : _recentTx
            .where((tx) =>
                tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                tx.category.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        // Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Spending Analysis',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                SizedBox(height: 4),
                Text('Detailed breakdown of your capital flow.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('TOTAL MONTHLY',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 2)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('₹${_totalMonthly.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6))),
              ),
            ]),
          ],
        )
            .animate()
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 20),

        // Category Intensity Bars
        _categoryIntensity()
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .moveY(begin: 16, end: 0),
        const SizedBox(height: 16),

        // Filter Chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('This Month', Icons.calendar_today_rounded, true),
              const SizedBox(width: 8),
              _chip('All Tags', Icons.sell_rounded, false),
              const SizedBox(width: 8),
              _chip('Merchants', Icons.storefront_rounded, false),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF2E3F52).withOpacity(0.05),
            border: Border.all(
                color: const Color(0xFF2E3F52).withOpacity(0.3)),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              hintStyle: const TextStyle(
                  fontSize: 14, color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF64748B), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Recent Ledger Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Ledger',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${filteredTx.length} New',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22C55E),
                      letterSpacing: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Transaction List
        ...filteredTx.map((tx) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _txTile(tx),
            )),
      ],
    );
  }

  Widget _categoryIntensity() {
    if (_catTotals.isEmpty) {
      return const SizedBox();
    }
    final maxCat = _catTotals.values.isEmpty ? 1.0 : _catTotals.values.reduce(max).clamp(1.0, double.infinity);
    // Sort all expense categories by their total in _catTotals, or just show all
    final sortedCats = AppCategories.expenseCategories.toList()
      ..sort((a, b) => (_catTotals[b.label] ?? 0).compareTo(_catTotals[a.label] ?? 0));
    final entries = sortedCats.take(6).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.1),
        border: Border.all(
            color: const Color(0xFF2E3F52).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CATEGORY INTENSITY',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.5)),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withOpacity(0.4),
                        shape: BoxShape.circle)),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Row(
              children: entries.map((e) {
                final total = _catTotals[e.label] ?? 0.0;
                final fraction = total / maxCat;
                // Vary the blue opacity based on relative value
                final opacity = 0.2 + (fraction * 0.6);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: fraction.clamp(0.08, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                  color: const Color(0xFF3B82F6)
                                      .withOpacity(opacity),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.label.length > 4
                              ? e.label.substring(0, 4)
                              : e.label,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: active
            ? const Color(0xFF2E3F52).withOpacity(0.2)
            : Colors.transparent,
        border: Border.all(
          color: active
              ? const Color(0xFF2E3F52).withOpacity(0.4)
              : const Color(0xFF2E3F52).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _txTile(TransactionModel tx) {
    final isIncome = tx.type == 'income';
    final d = DateTime.tryParse(tx.timestamp);
    String dateStr = '';
    if (d != null) {
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month) {
        dateStr =
            'Today, ${d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
      } else {
        dateStr =
            '${_monthName(d.month)} ${d.day}, ${d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
      }
    }

    final catData = AppCategories.getByName(tx.category);
    final catIcon = catData.icon;
    final catColor = catData.color;

    // Generate a tag based on amount
    String tag = '#routine';
    if (tx.amount.abs() > 200) tag = '#impulse';
    if (tx.category == 'Bills') tag = '#fixed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon,
                color: catColor.withOpacity(0.8), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.merchant,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: Color(0xFF94A3B8),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(tag,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tag == '#impulse'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF94A3B8),
                            letterSpacing: -0.2)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isIncome
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444)),
              ),
              const SizedBox(height: 3),
              Text(tx.category,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  // ═══════════════════════════════════════════════
  //  TAB 3: PSYCHOLOGY
  // ═══════════════════════════════════════════════
  Widget _psychologyTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        // Header
        Text('MINDSET LAB',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 3)),
        const SizedBox(height: 8),
        const Text('Your Money Brain',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(
          'Understand psychological forces shaping your financial behavior. '
          'Cognitive blindspots silently determine how you spend.',
          style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.45),
              height: 1.5),
        ),
        const SizedBox(height: 28),

        // Psychology Cards
        ..._psychCards
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _psychTile(e.value),
                ))
            .toList()
            .animate(interval: 120.ms)
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .moveY(begin: 20, end: 0),

        const SizedBox(height: 20),

        // Knowledge CTA
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E3F52).withOpacity(0.15),
                const Color(0xFF2E3F52).withOpacity(0.05),
              ],
            ),
            border: Border.all(
                color: const Color(0xFF2E3F52).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_stories_rounded,
                    color: Color(0xFF3B82F6), size: 22),
                const SizedBox(width: 10),
                const Text('Knowledge is Power',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
              const SizedBox(height: 10),
              Text(
                'Simply reading about cognitive biases reduces their '
                'influence on your spending by up to 23%.',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.45),
                    height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _psychTile(_PsychCard c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2E3F52).withOpacity(0.08),
        border: Border.all(
            color: const Color(0xFF2E3F52).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.iconBg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(c.icon,
                    color: c.iconBg.withOpacity(0.9), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(c.body,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.6)),
          const SizedBox(height: 12),
          Text(c.tag,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                  letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  HELPER DATA CLASSES
// ═══════════════════════════════════════════════════
class _DriverItem {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String impactLabel;
  final String impactSub;
  const _DriverItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.impactLabel,
    required this.impactSub,
  });
}

class _PsychCard {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String body;
  final String tag;
  const _PsychCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.body,
    required this.tag,
  });
}

// ═══════════════════════════════════════════════════
//  SLIVER TAB BAR DELEGATE
// ═══════════════════════════════════════════════════
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
        color: const Color(0xFF16191C),
        child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => false;
}