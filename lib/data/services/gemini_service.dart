import 'package:google_generative_ai/google_generative_ai.dart';
import 'behavioral_profile_service.dart';
import 'local_heuristic_service.dart';
import '../models/transaction_model.dart';

/// Service that leverages Gemini to interpret financial behavior.
class GeminiService {
  // NOTE: In a real app, the API key should be securely stored or fetched from a backend.
  // For this demonstration, we'll use a placeholder or expect it to be provided.
  static const String _apiKey = 'REPLACE_WITH_YOUR_GEMINI_API_KEY';

  static Future<String> getBehavioralInsight({
    required List<TransactionModel> transactions,
    required double monthlyIncome,
  }) async {
    if (_apiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
      return LocalHeuristicService.getInterpretation(
        transactions: transactions,
        monthlyIncome: monthlyIncome,
      );
    }

    try {
      final summary = BehavioralProfileService.generateBehavioralSummary(
        transactions: transactions,
        monthlyIncome: monthlyIncome,
      );

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = [
        Content.text(
          "You are a friendly financial coach. Based on the following 30-day transaction summary, "
          "identify the top 2 spending habits this user should be aware of. "
          "Use simple, layman terms (avoid technical jargon like 'Present Bias' or 'Loss Aversion'). "
          "Instead, use relatable descriptions like 'The Now-Spender' or 'Small Leak Alert'. "
          "Provide a clear, kind, 2-sentence explanation for each and a 1-sentence easy tip to improve. "
          "Format as a simple list.\n\n"
          "$summary"
        )
      ];

      final response = await model.generateContent(prompt);
      return response.text ?? "Could not generate insights at this time.";
    } catch (e) {
      return "AI Insight Error: $e";
    }
  }
}
