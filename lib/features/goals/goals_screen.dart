import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/goal_model.dart';
import '../notifications/notification_screen.dart';
import 'add_funds_success_screen.dart';
import 'create_goal_screen.dart';

// ─────────────────────────────────────────────
//  Shared Goal Model
// ─────────────────────────────────────────────
class GoalItem {
  final String id;
  String title;
  String subtitle;
  double current;
  double target;
  String deadline;
  String imagePath;

  GoalItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    required this.deadline,
    required this.imagePath,
  });

  double get progress => (current / target).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────
//  Goals Screen
// ─────────────────────────────────────────────
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with TickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  late List<AnimationController> _progressControllers;
  late List<Animation<double>> _progressAnimations;

  final List<GoalItem> _goals = [];

  double get _overallCurrent =>
      _goals.fold(0, (sum, g) => sum + g.current);
  double get _overallTarget =>
      _goals.isEmpty ? 1 : _goals.fold(0, (sum, g) => sum + g.target);
  double get _overallProgress =>
      (_overallCurrent / _overallTarget).clamp(0.0, 1.0);

  void _initAnimations() {
    _progressControllers = List.generate(
      _goals.length + 1,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 900 + i * 150),
      ),
    );
    _progressAnimations = List.generate(
      _progressControllers.length,
      (i) => CurvedAnimation(
        parent: _progressControllers[i],
        curve: Curves.easeOutCubic,
      ),
    );
    for (final c in _progressControllers) {
      c.forward();
    }
  }

  Future<void> _loadGoalsFromDB() async {
    final dbGoals = await _db.getAllGoals();
    if (!mounted) return;
    setState(() {
      _goals.clear();
      for (final g in dbGoals) {
        _goals.add(GoalItem(
          id: g.id,
          title: g.title,
          subtitle: g.subtitle,
          current: g.current,
          target: g.target,
          deadline: g.deadline,
          imagePath: g.imagePath,
        ));
      }
    });
    _reAnimate();
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGoalsFromDB();
  }

  void _reAnimate() {
    for (final c in _progressControllers) {
      c.dispose();
    }
    _initAnimations();
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _progressControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openAddFunds(GoalItem goal, int index) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFundsSheet(goal: goal),
    );

    if (result != null && result > 0) {
      setState(() {
        goal.current += result;
      });

      // Persist to database
      await _db.updateGoal(GoalModel(
        id: goal.id,
        title: goal.title,
        subtitle: goal.subtitle,
        current: goal.current,
        target: goal.target,
        deadline: goal.deadline,
        imagePath: goal.imagePath,
      ));

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddFundsSuccessScreen(
            goal: goal,
            amountAdded: result,
          ),
        ),
      );

      _reAnimate();
    }
  }

  Future<void> _openCreateGoal() async {
    final newGoal = await Navigator.of(context).push<GoalItem>(
      MaterialPageRoute(builder: (_) => const CreateGoalScreen()),
    );
    if (newGoal != null) {
      // Persist to database
      await _db.insertGoal(GoalModel(
        id: newGoal.id,
        title: newGoal.title,
        subtitle: newGoal.subtitle,
        current: newGoal.current,
        target: newGoal.target,
        deadline: newGoal.deadline,
        imagePath: newGoal.imagePath,
      ));
      setState(() {
        _goals.add(newGoal);
      });
      _reAnimate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF040B16),
        body: SafeArea(
          child: Column(
            children: [
              /// ── APP BAR ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 36),
                    const Text(
                      'Savings Goals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationScreen(),
                        ),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _buildOverallProgressCard(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Goals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Row(
                            children: const [
                              Icon(Icons.filter_list_rounded,
                                  color: Color(0xFF94A3B8), size: 16),
                              SizedBox(width: 4),
                              Text('Filter',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(_goals.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildGoalCard(_goals[i], i),
                      );
                    }),
                    _buildCreateNewGoal(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    return AnimatedBuilder(
      animation: _progressAnimations[0],
      builder: (context, _) {
        final progress = _overallProgress * _progressAnimations[0].value;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OVERALL PROGRESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${_fmt(_overallCurrent)} Total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(_overallProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of ₹${_fmt(_overallTarget)} goal',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalCard(GoalItem goal, int index) {
    final animIndex = (index + 1).clamp(0, _progressAnimations.length - 1);
    return AnimatedBuilder(
      animation: _progressAnimations[animIndex],
      builder: (context, _) {
        final progress =
            goal.progress * _progressAnimations[animIndex].value;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 170,
                    width: double.infinity,
                    color: const Color(0xFF1A2535),
                    child: Image.asset(
                      goal.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPlaceholderImage(goal),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0D1117).withOpacity(0.6),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        goal.deadline,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Icon(Icons.more_vert_rounded,
                            color: Color(0xFF64748B), size: 20),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      goal.subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${_fmt(goal.current)} of ₹${_fmt(goal.target)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          '${(goal.progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goal.progress >= 0.75
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _openAddFunds(goal, index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Add Funds',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage(GoalItem goal) {
    final icons = {
      'New Home Fund': Icons.home_rounded,
      'Europe Trip': Icons.flight_rounded,
      'Tesla Model 3': Icons.directions_car_rounded,
    };
    final colors = {
      'New Home Fund': const Color(0xFF1E3A5F),
      'Europe Trip': const Color(0xFF0F3460),
      'Tesla Model 3': const Color(0xFF1A1A2E),
    };
    return Container(
      color: colors[goal.title] ?? const Color(0xFF1A2535),
      child: Center(
        child: Icon(
          icons[goal.title] ?? Icons.star_rounded,
          color: Colors.white.withOpacity(0.15),
          size: 64,
        ),
      ),
    );
  }

  Widget _buildCreateNewGoal() {
    return GestureDetector(
      onTap: _openCreateGoal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create New Goal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
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

// ─────────────────────────────────────────────
//  Add Funds Bottom Sheet
// ─────────────────────────────────────────────
class _AddFundsSheet extends StatefulWidget {
  final GoalItem goal;
  const _AddFundsSheet({required this.goal});

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _amountController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    final remaining = widget.goal.target - widget.goal.current;
    if (value > remaining) {
      setState(() =>
          _error = 'Amount exceeds remaining goal (₹${remaining.toStringAsFixed(2)})');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Funds',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.goal.title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          // Remaining info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      '₹${_fmt(widget.goal.current)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Remaining',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      '₹${_fmt(widget.goal.target - widget.goal.current)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2535),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _error != null
                    ? const Color(0xFFEF4444)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('₹',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Color(0xFF334155)),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFEF4444))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Add Funds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final thousands = (v / 1000).floor();
      final remainder = (v % 1000).toInt();
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return v.toStringAsFixed(2);
  }
}
