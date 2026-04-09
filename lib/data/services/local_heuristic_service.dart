import '../models/transaction_model.dart';
import 'behavioral_profile_service.dart';

/// A lightweight, purely local "Pseudo-AI" that uses heuristic logic
/// to interpret financial behavior without any API keys or multi-GB models.
class LocalHeuristicService {
  static String getInterpretation({
    required List<TransactionModel> transactions,
    required double monthlyIncome,
  }) {
    if (transactions.isEmpty) return "Start tracking transactions to reveal your financial persona.";

    // Logic based on BehavioralProfile aggregation
    double totalExpense = transactions.where((tx) => tx.type == 'expense')
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());
    
    double ratio = monthlyIncome > 0 ? (totalExpense / monthlyIncome) : 1.0;
    
    Map<String, double> catTotals = {};
    int lateNightCount = 0;
    for (var tx in transactions) {
      if (tx.type == 'expense') {
        catTotals[tx.category] = (catTotals[tx.category] ?? 0) + tx.amount.abs();
        final dt = DateTime.tryParse(tx.timestamp);
        if (dt != null && (dt.hour >= 22 || dt.hour < 2)) lateNightCount++;
      }
    }

    final shopping = catTotals['Shopping'] ?? 0;
    final food = catTotals['Food'] ?? 0;
    final entertainment = catTotals['Entertainment'] ?? 0;
    final discretionary = shopping + food + entertainment;
    double discretionaryRatio = totalExpense > 0 ? (discretionary / totalExpense) : 0;

    List<String> insights = [];

    // 1. Spending Speed
    if (ratio < 0.3 && totalExpense > 0) {
      insights.add("• **Careful Protector**: You are very cautious with your money. You keep a large buffer for safety, which is great, though you could try moving a tiny bit into a small goal to see it grow.");
    } else if (ratio > 0.8) {
      insights.add("• **The 'Now' Spender**: You tend to spend your money as soon as it arrives. It's easy to forget about 'Future You' when today's wants feel so urgent.");
    }

    // 2. Small Leaks
    if (discretionaryRatio > 0.5) {
      insights.add("• **Small Leak Warning**: More than half your spending goes to 'wants' (Shopping/Food/Fun). Those small treats feel small at the time, but they're adding up to a big chunk of your month.");
    }

    // 3. Late Night Lapses
    if (lateNightCount > 3) {
      insights.add("• **Midnight Urges**: You've made several purchases late at night. Our brains are tired then and making bad choices is much easier. Try keeping your phone in another room after 10 PM!");
    }

    // 4. One Big Thing
    if (catTotals.values.any((v) => v > (monthlyIncome * 0.4))) {
      insights.add("• **The Heavy Hitter**: One single area is eating almost half your income. It might feel 'normal' now, but it's worth checking if there's a way to trim it down.");
    }

    if (insights.isEmpty) {
      insights.add("• **Steady Navigator**: You have a great balance between enjoying today and saving for tomorrow. Keep this rhythm going!");
    }

    return insights.join("\n\n");
  }

  static String getSarcasticCreditMessage(double amount) {
    final messages = [
      "Oh look, someone actually paid you. Don't spend it all on overpriced coffee in the next 5 minutes.",
      "Your bank balance just went up. Try not to let it trigger your 'Add to Cart' reflex. It's a trap!",
      "Money detected! It's currently safe in your account. Let's keep it that way for at least... a day?",
      "A rare sighting of income! Quick, hide it in a savings goal before your brain realizes it's there.",
      "Look at that, ₹${amount.toStringAsFixed(0)} just landed. It's asking for a nice, quiet life in your savings. Don't kill it.",
      "You've been credited! Your 'Present Bias' is already salivating. Stay strong, champion.",
    ];
    return messages[DateTime.now().millisecond % messages.length];
  }
}
