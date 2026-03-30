import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/transaction_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  List<_Insight> _insights = [];

  @override
  void initState() {
    super.initState();
    _generateInsights();
  }

  Future<void> _generateInsights() async {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthEnd = now;
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));

    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStart0 = DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day);

    // Parallel DB fetches
    final results = await Future.wait([
      _db.getCategoryTotals(start: thisMonthStart, end: thisMonthEnd),
      _db.getCategoryTotals(start: lastMonthStart, end: lastMonthEnd),
      _db.getCategoryTotals(start: thisWeekStart0, end: thisMonthEnd),
      _db.getTotalIncome(start: thisMonthStart, end: thisMonthEnd),
      _db.getTotalExpense(start: thisMonthStart, end: thisMonthEnd),
      _db.getAllGoals(),
      _db.getRecentTransactions(limit: 30),
    ]);

    final thisCats = results[0] as Map<String, double>;
    final lastCats = results[1] as Map<String, double>;
    final weekCats = results[2] as Map<String, double>;
    final income = results[3] as double;
    final expenses = results[4] as double;
    final goals = results[5] as List<GoalModel>;
    final recent = results[6] as List<TransactionModel>;

    final List<_Insight> insights = [];

    // ── Insight 1: Top spending category this month ───────────────────────
    if (thisCats.isNotEmpty) {
      final top = thisCats.entries.reduce((a, b) => a.value > b.value ? a : b);
      final lastAmt = lastCats[top.key] ?? 0;
      if (lastAmt > 0) {
        final pct = ((top.value - lastAmt) / lastAmt * 100).round();
        if (pct > 5) {
          insights.add(_Insight(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFF8A34),
            title: "High ${top.key} Spending",
            description:
                "Your ${top.key.toLowerCase()} expenses are up $pct% vs last month. "
                "₹${top.value.toStringAsFixed(0)} spent this month vs ₹${lastAmt.toStringAsFixed(0)}.",
          ));
        } else if (pct < -5) {
          insights.add(_Insight(
            icon: Icons.trending_down,
            color: const Color(0xFF22C55E),
            title: "${top.key} Spending Down",
            description:
                "Great job! Your ${top.key.toLowerCase()} spending dropped ${pct.abs()}% "
                "compared to last month. Keep it up!",
          ));
        }
      } else {
        insights.add(_Insight(
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFFFF8A34),
          title: "Top Category: ${top.key}",
          description:
              "₹${top.value.toStringAsFixed(0)} spent on ${top.key.toLowerCase()} this month — "
              "your highest spending category.",
        ));
      }
    }

    // ── Insight 2: Savings rate ──────────────────────────────────────────
    if (income > 0) {
      final savings = income - expenses;
      final savingsRate = (savings / income * 100).clamp(-100, 100).round();
      if (savings > 0) {
        insights.add(_Insight(
          icon: Icons.savings_rounded,
          color: const Color(0xFF22C55E),
          title: "Savings This Month",
          description:
              "You're saving $savingsRate% of your income this month — "
              "₹${savings.toStringAsFixed(0)} saved from ₹${income.toStringAsFixed(0)} earned.",
        ));
      } else {
        insights.add(_Insight(
          icon: Icons.warning_rounded,
          color: const Color(0xFFEF4444),
          title: "Overspending Alert",
          description:
              "You've spent ₹${expenses.toStringAsFixed(0)} against ₹${income.toStringAsFixed(0)} income this month. "
              "Consider cutting back on discretionary expenses.",
        ));
      }
    }

    // ── Insight 3: Weekly spending overview ──────────────────────────────
    if (weekCats.isNotEmpty) {
      final weekTotal = weekCats.values.fold(0.0, (s, v) => s + v);
      insights.add(_Insight(
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF3B82F6),
        title: "This Week's Spending",
        description:
            "You've spent ₹${weekTotal.toStringAsFixed(0)} so far this week. "
            "${weekCats.isNotEmpty ? 'Top category: ${weekCats.entries.reduce((a, b) => a.value > b.value ? a : b).key}.' : ''}",
      ));
    }

    // ── Insight 4: Goal progress ──────────────────────────────────────────
    if (goals.isNotEmpty) {
      final closestGoal = goals.reduce((a, b) {
        final aPct = a.current / a.target;
        final bPct = b.current / b.target;
        return aPct > bPct ? a : b;
      });
      final pct = (closestGoal.current / closestGoal.target * 100).round();
      insights.add(_Insight(
        icon: Icons.flag_rounded,
        color: const Color(0xFF8B5CF6),
        title: "Goal Progress: ${closestGoal.title}",
        description:
            "You're $pct% towards your '${closestGoal.title}' goal. "
            "₹${closestGoal.current.toStringAsFixed(0)} of ₹${closestGoal.target.toStringAsFixed(0)} saved.",
      ));
    }

    // ── Insight 5: Most frequent merchant ────────────────────────────────
    if (recent.isNotEmpty) {
      final merchantCounts = <String, int>{};
      for (final tx in recent) {
        if (tx.type == 'expense') {
          merchantCounts[tx.merchant] = (merchantCounts[tx.merchant] ?? 0) + 1;
        }
      }
      if (merchantCounts.isNotEmpty) {
        final top = merchantCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
        if (top.value >= 2) {
          insights.add(_Insight(
            icon: Icons.store_rounded,
            color: const Color(0xFFEAB308),
            title: "Frequent Merchant",
            description:
                "You've visited '${top.key}' ${top.value} times recently. "
                "This may be a good place to reduce spending.",
          ));
        }
      }
    }

    // ── Insight 6: Smart savings tip ────────────────────────────────────
    if (income > 0 && expenses > 0) {
      final suggestedInvestment = (income * 0.15).round();
      insights.add(_Insight(
        icon: Icons.lightbulb_outline,
        color: const Color(0xFF3B82F6),
        title: "Smart Suggestion",
        description:
            "Move ₹$suggestedInvestment/month (15% of income) to investments "
            "to build long-term wealth.",
      ));
    }

    // Fallback if no insights generated
    if (insights.isEmpty) {
      insights.add(_Insight(
        icon: Icons.info_outline_rounded,
        color: const Color(0xFF3B82F6),
        title: "No Insights Yet",
        description:
            "Add some transactions to start getting personalized financial insights.",
      ));
    }

    if (!mounted) return;
    setState(() {
      _insights = insights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Smart Insights",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              onPressed: () {
                setState(() => _loading = true);
                _generateInsights();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : RefreshIndicator(
              color: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFF0C1A2B),
              onRefresh: _generateInsights,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _insights.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        "Personalized insights based on your spending",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return _InsightCard(insight: _insights[i - 1]);
                },
              ),
            ),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1A2B), Color(0xFF08121F)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: insight.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(insight.icon, color: insight.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(insight.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 6),
              Text(insight.description,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45)),
            ]),
          ),
        ],
      ),
    );
  }
}