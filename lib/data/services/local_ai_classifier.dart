import 'dart:math';
import '../models/transaction_model.dart';
import '../../core/constants/categories_data.dart';

class LocalAIClassifier {
  static final LocalAIClassifier instance = LocalAIClassifier._();
  LocalAIClassifier._();

  // Category -> Token -> Frequency
  final Map<String, Map<String, int>> _tokenFreqs = {};
  // Category -> Total Token Count
  final Map<String, int> _categoryTokenCounts = {};
  // Category -> Document (Transaction) Count
  final Map<String, int> _categoryDocCounts = {};
  int _totalDocs = 0;

  // The set of all unique tokens across all categories
  final Set<String> _vocabulary = {};

  /// Trains the classifier on a list of historical transactions.
  void train(List<TransactionModel> transactions) {
    _tokenFreqs.clear();
    _categoryTokenCounts.clear();
    _categoryDocCounts.clear();
    _vocabulary.clear();
    _totalDocs = 0;

    // 1. Train on pre-seeded category rules first to establish prior knowledge
    AppCategories.categoryRules.forEach((category, keywords) {
      for (final kw in keywords) {
        final tokens = _tokenize(kw);
        for (final token in tokens) {
          _addToken(category, token, weight: 10); // Give seeded keywords strong prior weight
        }
        _categoryDocCounts[category] = (_categoryDocCounts[category] ?? 0) + 1;
        _totalDocs++;
      }
    });

    // 2. Train on historical transactions
    for (final tx in transactions) {
      final category = tx.category;
      if (category == 'Other' || category.trim().toLowerCase() == 'uncategorized') continue;

      final text = tx.merchant;
      final tokens = _tokenize(text);
      for (final token in tokens) {
        _addToken(category, token, weight: 2);
      }
      _categoryDocCounts[category] = (_categoryDocCounts[category] ?? 0) + 1;
      _totalDocs++;
    }
  }

  void _addToken(String category, String token, {int weight = 1}) {
    _tokenFreqs.putIfAbsent(category, () => {});
    final freqs = _tokenFreqs[category]!;
    freqs[token] = (freqs[token] ?? 0) + weight;
    _categoryTokenCounts[category] = (_categoryTokenCounts[category] ?? 0) + weight;
    _vocabulary.add(token);
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t.length > 1)
        .toList();
  }

  /// Predicts the category for a given merchant/description.
  /// Returns the category label and a confidence score.
  Prediction predict(String text) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty || _totalDocs == 0) {
      return Prediction(category: 'Other', confidence: 0.0);
    }

    String bestCategory = 'Other';
    double bestLogProb = -double.maxFinite;

    final allCategories = AppCategories.all.map((c) => c.label).toList();
    final Map<String, double> scores = {};

    for (final category in allCategories) {
      if (category == 'Other') continue;

      final docCount = _categoryDocCounts[category] ?? 0;
      if (docCount == 0) continue;

      // Prior: P(Category) = docCount / totalDocs
      final prior = docCount / _totalDocs;
      double logProb = log(prior);

      final freqs = _tokenFreqs[category] ?? {};
      final totalTokens = _categoryTokenCounts[category] ?? 0;

      for (final token in tokens) {
        // Laplace smoothing: P(token | category) = (count + 1) / (totalTokens + vocabSize)
        final count = freqs[token] ?? 0;
        final pToken = (count + 1) / (totalTokens + _vocabulary.length);
        logProb += log(pToken);
      }

      scores[category] = logProb;
      if (logProb > bestLogProb) {
        bestLogProb = logProb;
        bestCategory = category;
      }
    }

    // Convert log probabilities to relative confidence score (0.0 to 1.0)
    double confidence = 0.0;
    if (scores.isNotEmpty) {
      double maxLog = scores.values.reduce(max);
      double sumExp = 0.0;
      final Map<String, double> probs = {};
      scores.forEach((cat, val) {
        final ex = exp(val - maxLog); // stable exponentiation
        probs[cat] = ex;
        sumExp += ex;
      });

      if (sumExp > 0) {
        confidence = (probs[bestCategory] ?? 0) / sumExp;
      }
    }

    // Fallback if confidence is extremely low
    if (confidence < 0.05) {
      bestCategory = 'Other';
    }

    return Prediction(category: bestCategory, confidence: confidence);
  }
}

class Prediction {
  final String category;
  final double confidence;

  Prediction({required this.category, required this.confidence});
}
