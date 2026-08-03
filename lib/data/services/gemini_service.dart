import 'package:google_generative_ai/google_generative_ai.dart';
import 'behavioral_profile_service.dart';
import 'local_heuristic_service.dart';
import '../models/transaction_model.dart';
import '../local/database_helper.dart';

/// Service that leverages Gemini to interpret financial behavior.
class GeminiService {
  // NOTE: In a real app, the API key should be securely stored or fetched from a backend.

  static Future<String> getBehavioralInsight({
    required List<TransactionModel> transactions,
    required double monthlyIncome,
  }) async {
    final apiKey = await DatabaseHelper.instance.getSetting('gemini_api_key') ?? '';
    if (apiKey.isEmpty || apiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
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
        apiKey: apiKey,
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

  static Future<String> chat({
    required List<Map<String, String>> history,
    required List<TransactionModel> transactions,
    required double monthlyIncome,
  }) async {
    final summary = BehavioralProfileService.generateBehavioralSummary(
      transactions: transactions,
      monthlyIncome: monthlyIncome,
    );

    final apiKey = await DatabaseHelper.instance.getSetting('gemini_api_key') ?? '';
    if (apiKey.isEmpty || apiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
      return _generateLocalChatResponse(history, summary);
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final promptBuffer = StringBuffer();
      promptBuffer.writeln(
        "You are FinPulse AI, an empathetic, friendly, and practical financial coach. "
        "Here is the user's financial profile:\n$summary\n\n"
        "Here is the conversation history so far. Respond to the user's latest message. "
        "Keep your response concise (max 3 sentences), encouraging, and highly practical.\n"
      );

      for (final msg in history) {
        final role = msg['role'] == 'user' ? 'User' : 'Coach';
        promptBuffer.writeln("$role: ${msg['text']}");
      }
      promptBuffer.writeln("Coach:");

      final response = await model.generateContent([Content.text(promptBuffer.toString())]);
      return response.text ?? "I couldn't process that. How can I help you today?";
    } catch (e) {
      return "AI Coach Error: $e";
    }
  }

  static String _generateLocalChatResponse(List<Map<String, String>> history, String summary) {
    if (history.isEmpty) return "Hello! I am your local FinPulse Coach. Ask me anything about your budget or habits.";
    final lastUserMsg = history.lastWhere((m) => m['role'] == 'user', orElse: () => {'text': ''})['text']!.toLowerCase();

    if (lastUserMsg.contains('hello') || lastUserMsg.contains('hi')) {
      return "Hi there! I'm your local AI coach. I can help analyze your budget, check your spending flags, or review your discretionary spend. What's on your mind?";
    }
    if (lastUserMsg.contains('impulse') || lastUserMsg.contains('shopping') || lastUserMsg.contains('spend') || lastUserMsg.contains('discretionary')) {
      return "To curb impulse spending, try the 48-hour rule: leave discretionary items in your cart for two days before purchasing. You can also transfer money directly into one of your savings goals to keep it safe!";
    }
    if (lastUserMsg.contains('rent') || lastUserMsg.contains('bill')) {
      return "Your fixed bills and rent are critical. Keeping them automated helps, but make sure discretionary spending doesn't crowd out these essential monthly expenses.";
    }
    if (lastUserMsg.contains('night') || lastUserMsg.contains('midnight')) {
      return "Late-night purchases are often driven by fatigue. Try placing a screen time limit on shopping and food delivery apps after 10 PM to avoid midnight urges.";
    }
    if (lastUserMsg.contains('save') || lastUserMsg.contains('saving') || lastUserMsg.contains('goal')) {
      return "Saving consistently is all about automation. Set a goal target on the Goals page, and try to contribute a small amount first thing when your income arrives.";
    }
    if (lastUserMsg.contains('summary') || lastUserMsg.contains('profile') || lastUserMsg.contains('report') || lastUserMsg.contains('mindset')) {
      return "Based on your 30-day profile:\n$summary\nTry checking the Category Intensity charts on the Spending tab to visualize this data.";
    }
    
    return "I hear you! Even though I'm running in local fallback mode, I encourage you to check your budget under the Insights tab or define a savings goal to keep your progress on track.";
  }
}
