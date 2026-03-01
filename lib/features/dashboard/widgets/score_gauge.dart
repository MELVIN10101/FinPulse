import 'dart:math';
import 'package:flutter/material.dart';

class ScoreGauge extends StatefulWidget {
  final double income;
  final double expense;
  const ScoreGauge({super.key, required this.income, required this.expense});
  @override
  State<ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<ScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double get _score {
    if (widget.income <= 0) return 30;
    final savingsRate = ((widget.income - widget.expense) / widget.income).clamp(0.0, 1.0);
    // Score: 50 base + 50 * savingsRate (clamped 0-100)
    return (50 + savingsRate * 50).clamp(0, 100);
  }

  String get _label {
    final s = _score;
    if (s >= 80) return 'EXCELLENT';
    if (s >= 60) return 'GOOD';
    if (s >= 40) return 'FAIR';
    return 'NEEDS WORK';
  }

  Color get _labelColor {
    final s = _score;
    if (s >= 80) return const Color(0xFF22C55E);
    if (s >= 60) return const Color(0xFF3B82F6);
    if (s >= 40) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _animation = Tween<double>(begin: 0, end: _score / 100).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(children: [
        const SizedBox(height: 24),
        const Text("FINANCIAL HEALTH SCORE", textAlign: TextAlign.center,
          style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 30),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => SizedBox(
            width: 190, height: 190,
            child: CustomPaint(
              painter: _GaugePainter(progress: _animation.value),
              child: Center(child: Transform.translate(
                offset: const Offset(0, 2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_score.toInt().toString(),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1, color: Color(0xFFFFFFFF)),
                    textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false)),
                  const SizedBox(height: 2),
                  Text(_label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, height: 1, color: _labelColor),
                    textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false)),
                ]),
              )),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          _score >= 70
              ? "Your score is looking great this month!"
              : "Try to save more to improve your score.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final bgPaint = Paint()..color = const Color(0xFF334155)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    final fgPaint = Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}