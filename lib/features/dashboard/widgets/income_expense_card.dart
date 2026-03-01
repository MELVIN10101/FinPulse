import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class IncomeExpenseCard extends StatefulWidget {
  final double income;
  final double expense;
  const IncomeExpenseCard({super.key, required this.income, required this.expense});
  @override
  State<IncomeExpenseCard> createState() => _IncomeExpenseCardState();
}

class _IncomeExpenseCardState extends State<IncomeExpenseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final income = widget.income;
    final expense = widget.expense;
    final pctChange = expense > 0
        ? ((income - expense) / expense * 100).clamp(-99, 999)
        : 0.0;
    final isPositive = pctChange >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1117),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Income vs Expense", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444), size: 17),
              const SizedBox(width: 2),
              Text("${pctChange.abs().toStringAsFixed(0)}%",
                  style: TextStyle(color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 17)),
            ]),
            const SizedBox(height: 2),
            const Text("This Month", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text("₹${_fmt(income)}", style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFF22C55E), letterSpacing: -0.5)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("/", style: TextStyle(fontSize: 24, color: Color(0xFF475569)))),
          Text("₹${_fmt(expense)}", style: const TextStyle(fontSize: 28, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 130,
          child: AnimatedBuilder(animation: _animation, builder: (context, _) {
            return BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (income > expense ? income : expense) / 80,
              minY: 0,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) {
                  final labels = ['Income', 'Expense'];
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i], style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500)));
                })),
              ),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income / 100 * _animation.value, width: 24, borderRadius: BorderRadius.circular(6), color: const Color(0xFF22C55E))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense / 100 * _animation.value, width: 24, borderRadius: BorderRadius.circular(6), color: const Color(0xFFEF4444))]),
              ],
            ));
          }),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final thousands = (v / 1000).floor();
      final remainder = (v % 1000).toInt();
      return "$thousands,${remainder.toString().padLeft(3, '0')}";
    }
    return v.toStringAsFixed(0);
  }
}
