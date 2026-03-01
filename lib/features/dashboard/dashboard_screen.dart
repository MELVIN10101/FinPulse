import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import 'widgets/score_gauge.dart';
import 'widgets/income_expense_card.dart';
import 'widgets/spending_trend_card.dart';
import 'widgets/category_card.dart';
import 'widgets/recent_transactions_section.dart';
import '../notifications/notification_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  double _income = 0;
  double _expense = 0;
  Map<String, double> _categoryTotals = {};
  Map<String, int> _categoryCounts = {};
  List<TransactionModel> _recentTx = [];
  List<double> _weeklyTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      backgroundColor: const Color(0xFF080B10),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF141E2B), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text("FinPulse", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                    child: Stack(children: const [
                      Icon(Icons.notifications_none, color: Colors.white70, size: 26),
                      Positioned(right: 2, top: 2, child: CircleAvatar(radius: 4, backgroundColor: Colors.redAccent)),
                    ]),
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

              CategoryCard(categoryTotals: _categoryTotals, categoryCounts: _categoryCounts)
                  .animate().fadeIn(delay: 500.ms).moveY(begin: 30, end: 0),
              const SizedBox(height: 16),

              RecentTransactionsSection(transactions: _recentTx)
                  .animate().fadeIn(delay: 600.ms).moveY(begin: 30, end: 0),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
