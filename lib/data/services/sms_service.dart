import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../local/database_helper.dart';
import '../models/transaction_model.dart';

class SMSService {
  static const platform = MethodChannel('sms_channel');

  Future<void> fetchTransactionSMS() async {
    try {
      PermissionStatus status = await Permission.sms.request();

      if (!status.isGranted) {
        print("SMS permission denied");
        return;
      }

      final List<dynamic> messages =
          await platform.invokeMethod('getSms');

      for (var msg in messages) {
        final body = msg['body'] ?? "";
        final date = msg['date'] ?? "";
        final smsId = msg['id'].toString();

        if (_isTransactionMessage(body)) {
          double amount = extractAmount(body);

          if (amount > 0) {
            String merchant = extractMerchant(body);
            String type =
                body.toLowerCase().contains("credit") ? "Credit" : "Debit";

            String category = detectCategory(merchant, body, type);

            await DatabaseHelper.instance.insertTransaction(TransactionModel(
              amount: type == 'Credit' ? amount : -amount,
              merchant: merchant,
              category: category,
              type: type == 'Credit' ? 'income' : 'expense',
              timestamp: date.toIso8601String(),
            ));
          }
        }
      }
    } catch (e) {
      print("SMS Fetch Error: $e");
    }
  }

  bool _isTransactionMessage(String body) {
    body = body.toLowerCase();
    return body.contains("debited") ||
        body.contains("credited") ||
        body.contains("upi") ||
        body.contains("rs") ||
        body.contains("inr");
  }

  double extractAmount(String body) {
    RegExp regex =
        RegExp(r'(?:Rs\.?|INR)\s?(\d+\.?\d*)', caseSensitive: false);

    final match = regex.firstMatch(body);

    if (match != null) {
      return double.tryParse(match.group(1) ?? "0") ?? 0;
    }

    return 0;
  }

  String extractMerchant(String body) {
    RegExp toRegex =
        RegExp(r'to\s([A-Za-z0-9\s]+)', caseSensitive: false);
    RegExp atRegex =
        RegExp(r'at\s([A-Za-z0-9\s]+)', caseSensitive: false);

    final toMatch = toRegex.firstMatch(body);
    if (toMatch != null) {
      return toMatch.group(1)?.trim() ?? "Unknown";
    }

    final atMatch = atRegex.firstMatch(body);
    if (atMatch != null) {
      return atMatch.group(1)?.trim() ?? "Unknown";
    }

    return "Unknown";
  }

  // ============================
  // 🔥 ADVANCED CATEGORY DETECTION
  // ============================

  String detectCategory(String merchant, String body, String type) {
    String text = (merchant + " " + body).toLowerCase();

    if (type == "Credit") {
      return "Income";
    }

    // ---------------- FOOD ----------------
    if (_containsAny(text, [
      "zomato",
      "swiggy",
      "barbeque",
      "bbq",
      "restaurant",
      "hotel",
      "food",
      "foods",
      "cafe",
      "coffee",
      "pizza",
      "burger",
      "kfc",
      "mcd",
      "dominos",
      "eat",
      "dining",
      "caterer",
      "caterers",
      "bakery",
      "biryani",
      "tiffin"
    ])) {
      return "Food";
    }

    // ---------------- SHOPPING ----------------
    if (_containsAny(text, [
      "amazon",
      "flipkart",
      "myntra",
      "ajio",
      "snapdeal",
      "meesho",
      "store",
      "mall",
      "mart",
      "shopping",
      "retail",
      "lifestyle",
      "westside",
      "reliance",
      "dmart"
    ])) {
      return "Shopping";
    }

    // ---------------- GROCERIES ----------------
    if (_containsAny(text, [
      "grocery",
      "groceries",
      "vegetables",
      "milk",
      "fruits",
      "zepto",
      "bigbasket",
      "blinkit",
      "grofers",
      "dunzo",
      "kirana"
    ])) {
      return "Groceries";
    }

    // ---------------- TRAVEL ----------------
    if (_containsAny(text, [
      "uber",
      "ola",
      "rapido",
      "flight",
      "airways",
      "indigo",
      "train",
      "irctc",
      "bus",
      "metro",
      "taxi",
      "travel"
    ])) {
      return "Travel";
    }

    // ---------------- BILLS ----------------
    if (_containsAny(text, [
      "electricity",
      "water",
      "gas",
      "bill",
      "recharge",
      "mobile",
      "broadband",
      "internet",
      "dth",
      "utility",
      "insurance",
      "emi"
    ])) {
      return "Bills";
    }

    // ---------------- ENTERTAINMENT ----------------
    if (_containsAny(text, [
      "netflix",
      "prime",
      "hotstar",
      "disney",
      "music",
      "apple",
      "itunes",
      "spotify",
      "bookmyshow",
      "movie",
      "cinema",
      "entertainment",
      "subscription",
      "game"
    ])) {
      return "Entertainment";
    }

    // ---------------- HEALTH ----------------
    if (_containsAny(text, [
      "apollo",
      "hospital",
      "clinic",
      "pharmacy",
      "medic",
      "health",
      "doctor",
      "diagnostic",
      "lab",
      "medicine"
    ])) {
      return "Health";
    }

    // ---------------- TRANSPORT ----------------
    if (_containsAny(text, [
      "fuel",
      "petrol",
      "diesel",
      "toll",
      "parking"
    ])) {
      return "Transport";
    }

    return "Others";
  }

  // Helper
  bool _containsAny(String text, List<String> keywords) {
    for (var word in keywords) {
      if (text.contains(word)) return true;
    }
    return false;
  }
}
