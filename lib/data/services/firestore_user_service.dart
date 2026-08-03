import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/database_helper.dart';
import '../models/transaction_model.dart';
import '../../features/auth/auth_service.dart';
import 'impulse_analysis_service.dart';

/// Syncs the current user's profile and computed financial scores to Firestore.
///
/// Document path: `users/{uid}`
///
/// This service is a no-op on desktop (Linux / Windows / macOS) because
/// Firebase is not initialised on those platforms.
class FirestoreUserService {
  static final FirestoreUserService instance = FirestoreUserService._internal();
  FirestoreUserService._internal();

  /// Returns true only on Android / iOS where Firebase is live.
  bool get _isSupported =>
      !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS;

  /// Fetches current data from local DB and triggers a full sync.
  Future<void> syncNow() async {
    if (!_isSupported) return;

    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final income = await db.getTotalIncome(start: monthStart, end: monthEnd);
      final expense = await db.getTotalExpense(start: monthStart, end: monthEnd);
      final trend = await db.getWeeklySpendingTrend();
      final monthlyTx = await db.getTransactionsForDateRange(monthStart, monthEnd);

      await syncUserScores(
        monthlyIncome: income,
        monthlyExpense: expense,
        lastWeekExpense: trend.length >= 3 ? trend[trend.length - 2] : 0,
        thisWeekExpense: trend.isNotEmpty ? trend.last : 0,
        transactions: monthlyTx,
      );
      print('[FirestoreUserService] syncNow success');
    } catch (e) {
      print('[FirestoreUserService] syncNow failed: $e');
    }
  }

  /// Computes all scores from raw data and upserts the user document.
  ///
  /// Call this after every dashboard data load (fire-and-forget – caller
  /// should not await).
  Future<void> syncUserScores({
    required double monthlyIncome,
    required double monthlyExpense,
    required double lastWeekExpense,
    required double thisWeekExpense,
    required List<TransactionModel> transactions,
  }) async {
    if (!_isSupported) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return; // Not signed in

    // ── Local profile (age + gender) ───────────────────────────────────────
    final profile = await DatabaseHelper.instance.getUserProfile();

    // ── Score calculations ─────────────────────────────────────────────────
    final financialHealthScore = _computeHealthScore(
      income: monthlyIncome,
      expense: monthlyExpense,
    );

    final impulseScore = ImpulseAnalysisService.calculateImpulseScore(
      transactions: transactions,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      lastWeekExpense: lastWeekExpense,
      thisWeekExpense: thisWeekExpense,
    );

    final savingConsistencyScore =
        ImpulseAnalysisService.calculateSavingConsistency(
      income: monthlyIncome,
      expense: monthlyExpense,
    );

    // ── Firestore upsert ───────────────────────────────────────────────────
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id) // uid is the document ID → guaranteed unique
          .set(
        {
          'uid': user.id,
          'name': user.name,
          'email': user.email,
          'age': profile.age,
          'gender': profile.gender,
          'financialHealthScore': financialHealthScore,
          'impulseScore': double.parse(impulseScore.toStringAsFixed(2)),
          'savingConsistencyScore':
              double.parse(savingConsistencyScore.toStringAsFixed(2)),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // non-destructive: preserves other fields
      );
    } catch (e) {
      // Silently swallow – this is supplementary cloud sync, not critical.
      // ignore: avoid_print
      print('[FirestoreUserService] syncUserScores failed: $e');
    }
  }

  /// Same formula used by [ScoreGauge] (0–100, higher = healthier).
  int _computeHealthScore({
    required double income,
    required double expense,
  }) {
    if (income <= 0) return 30;
    final savingsRate = ((income - expense) / income).clamp(0.0, 1.0);
    return (50 + savingsRate * 50).clamp(0, 100).toInt();
  }

  /// Deletes user document on account deletion.
  Future<void> deleteUserData(String uid) async {
    if (!_isSupported) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      print('[FirestoreUserService] deleteUserData success');
    } catch (e) {
      print('[FirestoreUserService] deleteUserData failed: $e');
    }
  }
}
