import '../models/transaction_model.dart';
import '../../core/constants/categories_data.dart';

/// Service that aggregates transaction history into a behavioral summary
/// formatted for consumption by an LLM (on-device or cloud).
class BehavioralProfileService {
  /// Generates a textual summary of spending behavior for the last N days.
  static String generateBehavioralSummary({
    required List<TransactionModel> transactions,
    required double monthlyIncome,
  }) {
    if (transactions.isEmpty) return "No transaction data available.";

    // 1. Basic Stats
    double totalExpense = transactions.where((tx) => tx.type == 'expense')
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());
    
    // 2. Category Breakdown
    Map<String, double> catTotals = {};
    for (var tx in transactions) {
      if (tx.type == 'expense') {
        catTotals[tx.category] = (catTotals[tx.category] ?? 0) + tx.amount.abs();
      }
    }

    // 3. Temporal Patterns
    int lateNightCount = 0; // 10 PM - 2 AM
    int morningRitualCount = 0; // 6 AM - 10 AM (Food/Groceries)
    for (var tx in transactions) {
      final dt = DateTime.tryParse(tx.timestamp);
      if (dt != null && tx.type == 'expense') {
        if (dt.hour >= 22 || dt.hour < 2) lateNightCount++;
        if (dt.hour >= 6 && dt.hour < 10 && 
           (tx.category == 'Food' || tx.category == 'Groceries')) {
          morningRitualCount++;
        }
      }
    }

    // 4. Frequency & Micro-spending
    int smallTxCount = transactions.where((tx) => tx.type == 'expense' && tx.amount.abs() < 500).length;

    // Build the summary
    final buffer = StringBuffer();
    buffer.writeln("Financial Profile (Last 30 Days):");
    buffer.writeln("- Total Income: ₹${monthlyIncome.toStringAsFixed(0)}");
    buffer.writeln("- Total Expenses: ₹${totalExpense.toStringAsFixed(0)}");
    buffer.writeln("- Expense/Income Ratio: ${(monthlyIncome > 0 ? (totalExpense / monthlyIncome) : 1.0).toStringAsFixed(2)}");
    
    buffer.writeln("\nCategory Breakdown:");
    catTotals.forEach((cat, amt) {
      double pct = (totalExpense > 0) ? (amt / totalExpense * 100) : 0;
      buffer.writeln("- $cat: ₹${amt.toStringAsFixed(0)} (${pct.toStringAsFixed(1)}%)");
    });

    buffer.writeln("\nBehavioral Flags:");
    buffer.writeln("- Late night purchases: $lateNightCount");
    buffer.writeln("- Morning rituals (Impulse food/grocery): $morningRitualCount");
    buffer.writeln("- Frequent small transactions (<₹500): $smallTxCount");
    
    // Add context about high-impulse categories
    final highImpulseSpend = (catTotals['Shopping'] ?? 0) + (catTotals['Entertainment'] ?? 0) + (catTotals['Food'] ?? 0);
    double highImpulsePct = (totalExpense > 0) ? (highImpulseSpend / totalExpense * 100) : 0;
    buffer.writeln("- Discretionary Spend (Shopping/Food/Ent): ${highImpulsePct.toStringAsFixed(1)}%");

    return buffer.toString();
  }
}
