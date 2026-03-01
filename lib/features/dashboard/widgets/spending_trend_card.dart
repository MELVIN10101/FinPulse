import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpendingTrendCard extends StatefulWidget {
  final List<double> weeklyData;
  final double totalExpense;
  const SpendingTrendCard({super.key, required this.weeklyData, required this.totalExpense});
  @override
  State<SpendingTrendCard> createState() => _SpendingTrendCardState();
}

class _SpendingTrendCardState extends State<SpendingTrendCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  List<FlSpot> _spots(double progress) {
    final data = widget.weeklyData;
    if (data.isEmpty) return [const FlSpot(0, 0)];
    return List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i] * progress));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.weeklyData;
    final maxVal = data.isNotEmpty ? data.reduce((a, b) => a > b ? a : b) : 1000;
    final total = widget.totalExpense;

    // Trend: compare last 2 weeks
    double pct = 0;
    if (data.length >= 2 && data[data.length - 2] > 0) {
      pct = ((data.last - data[data.length - 2]) / data[data.length - 2] * 100);
    }
    final isUp = pct >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1117),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Spending Trend", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8))),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text("₹${_fmt(total)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(width: 8),
              const Text("Total", style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
            ]),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: isUp ? const Color(0xFFEF4444) : const Color(0xFF22C55E), size: 16),
              const SizedBox(width: 3),
              Text("${pct.abs().toStringAsFixed(0)}%", style: TextStyle(color: isUp ? const Color(0xFFEF4444) : const Color(0xFF22C55E), fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            const Text("Last 30 Days", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 22),
        SizedBox(
          height: 160,
          child: AnimatedBuilder(animation: _animation, builder: (context, _) {
            return LineChart(LineChartData(
              minX: 0, maxX: (data.length - 1).toDouble().clamp(1, 100),
              minY: 0, maxY: maxVal * 1.2,
              clipData: const FlClipData.all(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i >= 0 && i < data.length) {
                      return Padding(padding: const EdgeInsets.only(top: 10), child: Text("WK${i + 1}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))));
                    }
                    return const SizedBox();
                  },
                )),
              ),
              lineBarsData: [LineChartBarData(
                spots: _spots(_animation.value), isCurved: true, curveSmoothness: 0.45,
                color: const Color(0xFF3D5A80), barWidth: 2.5,
                dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                  if (index == data.length - 1) return FlDotCirclePainter(radius: 5, color: Colors.white, strokeWidth: 0);
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
                }),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF1E3A5F).withOpacity(0.35), const Color(0xFF0D1117).withOpacity(0.0)])),
              )],
            ));
          }),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) { final t = (v / 1000).floor(); final r = (v % 1000).toInt(); return "$t,${r.toString().padLeft(3, '0')}"; }
    return v.toStringAsFixed(0);
  }
}
