import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/firestore_user_service.dart';
import 'widgets/score_gauge.dart';
import 'widgets/income_expense_card.dart';
import 'widgets/spending_trend_card.dart';
import 'widgets/category_card.dart';
import 'widgets/recent_transactions_section.dart';
import '../notifications/notification_screen.dart';
import 'uncategorized_accounts_screen.dart';
import 'manage_categories_screen.dart';
import '../../core/privacy/privacy_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _db = DatabaseHelper.instance;
  double _income = 0;
  double _expense = 0;
  Map<String, double> _categoryTotals = {};
  Map<String, int> _categoryCounts = {};
  List<TransactionModel> _recentTx = [];
  List<double> _weeklyTrend = [];
  bool _loading = true;

  late final StreamSubscription<TransactionModel> _txSub;

  @override
  void initState() {
    super.initState();
    _load();
    _checkSmsPermission();
    _txSub = NotificationService.instance.onNewTransaction.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _txSub.cancel();
    super.dispose();
  }

  Future<void> _checkSmsPermission() async {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (!isAndroid) return;

    final status = await Permission.sms.status;
    if (status.isDenied) {
      if (!mounted) return;
      final showDisclosure = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 24),
              SizedBox(width: 12),
              Text(
                'Data Safety & Privacy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'To automatically track your expenses, FinPulse needs permission to read transaction SMS alerts sent by your bank.',
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                '• Local Processing: SMS messages are parsed 100% locally on your device and are never uploaded to any servers.\n'
                '• Financial Filter: Only messages containing debit/credit keywords are processed. Personal messages are strictly ignored.\n'
                '• No Ads or Selling: Your transactional data is private and will never be shared with third parties.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Type Manually', style: TextStyle(color: Color(0xFF64748B))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agree & Enable',
                  style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (showDisclosure == true) {
        await NotificationService.instance.init();
        await _load();
      }
    } else {
      await NotificationService.instance.init();
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final income = await _db.getTotalIncome(start: monthStart, end: monthEnd);
    final expense = await _db.getTotalExpense(start: monthStart, end: monthEnd);
    final cats = await _db.getCategoryTotals(start: monthStart, end: monthEnd);
    final counts = await _db.getCategoryCounts(start: monthStart, end: monthEnd);
    final recent = await _db.getRecentTransactions(limit: 3);
    final trend = await _db.getWeeklySpendingTrend();
    // Fetch all monthly transactions needed for impulse score computation.
    final monthlyTx = await _db.getTransactionsForDateRange(monthStart, monthEnd);

    if (!mounted) return;
    setState(() {
      _income = income;
      _expense = expense;
      _categoryTotals = cats;
      _categoryCounts = counts;
      _recentTx = recent;
      _weeklyTrend = trend;
      _loading = false;
    });

    // Sync user profile + scores to Firestore (mobile only, fire-and-forget).
    // trend is [week-3, week-2, lastWeek, thisWeek]
    FirestoreUserService.instance.syncUserScores(
      monthlyIncome: income,
      monthlyExpense: expense,
      lastWeekExpense: trend.length >= 3 ? trend[trend.length - 2] : 0,
      thisWeekExpense: trend.isNotEmpty ? trend.last : 0,
      transactions: monthlyTx,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080B10),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF080B10),
      drawer: _buildLeftMenu(),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: PrivacyManager.instance,
          builder: (context, _) {
            final isPrivate = PrivacyManager.instance.isPrivacyMode;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF141E2B), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text("FinPulse", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                            onPressed: () => PrivacyManager.instance.togglePrivacyMode(),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                            child: Stack(children: const [
                              Icon(Icons.notifications_none, color: Colors.white70, size: 26),
                              Positioned(right: 2, top: 2, child: CircleAvatar(radius: 4, backgroundColor: Colors.redAccent)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 40),

                  ScoreGauge(income: _income, expense: _expense)
                      .animate().fadeIn(delay: 200.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 32),

                  IncomeExpenseCard(income: _income, expense: _expense)
                      .animate().fadeIn(delay: 300.ms).moveY(begin: 30, end: 0),
                  const SizedBox(height: 16),

                  SpendingTrendCard(weeklyData: _weeklyTrend, totalExpense: _expense)
                      .animate().fadeIn(delay: 400.ms).moveY(begin: 30, end: 0),
                  const SizedBox(height: 16),

                  CategoryCard(
                    categoryTotals: _categoryTotals,
                    categoryCounts: _categoryCounts,
                    onCategoriesChanged: _load,
                  ).animate().fadeIn(delay: 500.ms).moveY(begin: 30, end: 0),
                  const SizedBox(height: 16),

                  RecentTransactionsSection(
                    transactions: _recentTx,
                    onTransactionChanged: _load,
                  ).animate().fadeIn(delay: 600.ms).moveY(begin: 30, end: 0),
                  const SizedBox(height: 120),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftMenu() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(Icons.wallet_rounded, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "FinPulse",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            _buildDrawerItem(
              icon: Icons.apps_rounded,
              label: "Dashboard",
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.rule_folder_rounded,
              label: "Uncategorized Accounts",
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UncategorizedAccountsScreen()),
                ).then((_) => _load());
              },
            ),
            _buildDrawerItem(
              icon: Icons.category_rounded,
              label: "Manage Categories",
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
                ).then((_) => _load());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
