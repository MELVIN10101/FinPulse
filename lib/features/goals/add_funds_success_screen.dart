import 'package:flutter/material.dart';
import 'goals_screen.dart';

class AddFundsSuccessScreen extends StatefulWidget {
  final GoalItem goal;
  final double amountAdded;

  const AddFundsSuccessScreen({
    super.key,
    required this.goal,
    required this.amountAdded,
  });

  @override
  State<AddFundsSuccessScreen> createState() =>
      _AddFundsSuccessScreenState();
}

class _AddFundsSuccessScreenState extends State<AddFundsSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _contentController;
  late AnimationController _progressController;

  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _contentSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _checkScale = CurvedAnimation(
        parent: _checkController, curve: Curves.elasticOut);
    _checkOpacity = CurvedAnimation(
        parent: _checkController, curve: Curves.easeIn);
    _contentSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
          parent: _contentController, curve: Curves.easeOutCubic),
    );
    _contentOpacity = CurvedAnimation(
        parent: _contentController, curve: Curves.easeOut);
    _progressAnim = CurvedAnimation(
        parent: _progressController, curve: Curves.easeOutCubic);

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 100),
        () => _checkController.forward());
    Future.delayed(const Duration(milliseconds: 400),
        () => _contentController.forward());
    Future.delayed(const Duration(milliseconds: 600),
        () => _progressController.forward());
  }

  @override
  void dispose() {
    _checkController.dispose();
    _contentController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.goal.progress;

    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              /// ── CHECK ICON ──────────────────────────────────────
              AnimatedBuilder(
                animation: _checkController,
                builder: (_, __) => Opacity(
                  opacity: _checkOpacity.value,
                  child: Transform.scale(
                    scale: _checkScale.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// ── TITLE ────────────────────────────────────────────
              AnimatedBuilder(
                animation: _contentController,
                builder: (_, __) => Opacity(
                  opacity: _contentOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _contentSlide.value),
                    child: Column(
                      children: [
                        const Text(
                          'Contribution Success!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "You're getting closer to your dream.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              /// ── GOAL DETAIL CARD ─────────────────────────────────
              AnimatedBuilder(
                animation: _contentController,
                builder: (_, __) => Opacity(
                  opacity: _contentOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _contentSlide.value * 1.2),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Goal header
                          Row(
                            children: [
                              // Goal image thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Image.asset(
                                    widget.goal.imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                      color: const Color(0xFF1E293B),
                                      child: Icon(
                                        Icons.star_rounded,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.goal.title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+₹${widget.amountAdded.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          /// Progress section
                          const Text(
                            'CURRENT PROGRESS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                '₹${_fmt(widget.goal.current)} of ₹${_fmt(widget.goal.target)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          /// Animated progress bar
                          AnimatedBuilder(
                            animation: _progressAnim,
                            builder: (_, __) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress * _progressAnim.value,
                                minHeight: 8,
                                backgroundColor: const Color(0xFF1E293B),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              /// ── AWESOME BUTTON ───────────────────────────────────
              AnimatedBuilder(
                animation: _contentController,
                builder: (_, __) => Opacity(
                  opacity: _contentOpacity.value,
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Awesome!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final thousands = (v / 1000).floor();
      final remainder = (v % 1000).toInt();
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return v.toStringAsFixed(0);
  }
}
