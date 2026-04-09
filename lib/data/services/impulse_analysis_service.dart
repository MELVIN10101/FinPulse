import 'dart:math';
import '../models/transaction_model.dart';

/// Service responsible for calculating behavioral financial insights,
/// specifically the Behavioral Impulsivity Index (BII).
class ImpulseAnalysisService {
  /// Calculates the Impulse Score (0-100) based on transaction behavior.
  /// A higher score indicates lower impulsivity (better financial discipline).
  static double calculateImpulseScore({
    required List<TransactionModel> transactions,
    required double monthlyIncome,
    required double monthlyExpense,
    required double lastWeekExpense,
    required double thisWeekExpense,
  }) {
    if (transactions.isEmpty) return 100.0;

    // 1. Discretionary Spending Ratio (DSR) - Weight: 40%
    // High impulsivity categories: Shopping, Entertainment, Food (Dining out)
    final highImpulseCategories = {'Shopping', 'Entertainment', 'Food'};
    double highImpulseSpend = 0;
    for (var tx in transactions) {
      if (tx.type == 'expense' && highImpulseCategories.contains(tx.category)) {
        highImpulseSpend += tx.amount.abs();
      }
    }
    double dsr = monthlyExpense > 0 ? (highImpulseSpend / monthlyExpense) : 0;
    // Normalize DSR: 0.0 (good) to 1.0 (bad). 0.5 is average heavy discretionary spend.
    double normalizedDsr = (dsr / 0.6).clamp(0.0, 1.0);

    // 2. Temporal Risk Factor (TRF) - Weight: 20%
    // Risk windows: Late night (22:00 - 02:00) and Early morning (Morning Rituals before 10 AM)
    int riskCount = 0;
    for (var tx in transactions) {
      final dt = DateTime.tryParse(tx.timestamp);
      if (dt != null) {
        if ((dt.hour >= 22 || dt.hour < 2) || (dt.hour >= 6 && dt.hour < 10)) {
          riskCount++;
        }
      }
    }
    double trf = transactions.where((tx) => tx.type == 'expense').isEmpty 
        ? 0 
        : riskCount / transactions.where((tx) => tx.type == 'expense').length;
    double normalizedTrf = (trf / 0.4).clamp(0.0, 1.0); // 40% transactions in risk window is high

    // 3. Volatility Index (VI) - Weight: 20%
    // Standard deviation of daily spending normalized by mean daily spending
    Map<String, double> dailySpend = {};
    for (var tx in transactions) {
      if (tx.type == 'expense') {
        final date = tx.timestamp.split('T')[0];
        dailySpend[date] = (dailySpend[date] ?? 0) + tx.amount.abs();
      }
    }
    double vi = 0;
    if (dailySpend.isNotEmpty) {
      double mean = monthlyExpense / 30; // Average per day
      double variance = dailySpend.values
          .map((v) => pow(v - mean, 2))
          .reduce((a, b) => a + b) / 30;
      double stdDev = sqrt(variance);
      vi = (stdDev / (mean > 0 ? mean : 1)).clamp(0.0, 2.0) / 2.0;
    }
    double normalizedVi = vi;

    // 4. Income Displacement Ratio (IDR) - Weight: 20%
    double ratio = monthlyIncome > 0 ? (monthlyExpense / monthlyIncome) : 1.0;
    // Sigmoid-like penalty for high spending ratio
    double normalizedIdr = (1 / (1 + exp(-10 * (ratio - 0.7)))).clamp(0.0, 1.0);

    // Weighted Behavioral Score (0.0 = Very Impulsive, 1.0 = Very Disciplined)
    double rawImpulsivity = (0.4 * normalizedDsr) + 
                             (0.2 * normalizedTrf) + 
                             (0.2 * normalizedVi) + 
                             (0.2 * normalizedIdr);

    // Map to 0-100 scale where 100 is best
    return (100 * (1 - rawImpulsivity)).clamp(0, 100);
  }

  /// Calculates the "Saving Mindset" consistency score.
  static double calculateSavingConsistency({
    required double income,
    required double expense,
  }) {
    if (income <= 0) return 0;
    double savingsRate = (income - expense) / income;
    // Logarithmic scaling for savings rate to emphasize small improvements
    if (savingsRate <= 0) return 0;
    return (log(1 + savingsRate * 5) / log(6) * 100).clamp(0, 100);
  }
}
