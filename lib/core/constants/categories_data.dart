import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';

class CategoryData {
  final int? id;
  final String label;
  final IconData icon;
  final Color color;

  const CategoryData({
    this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class AppCategories {
  static List<CategoryData> all = [
    const CategoryData(id: 1, label: 'Food', icon: Icons.restaurant_rounded, color: Color(0xFFEAB308)),
    const CategoryData(id: 2, label: 'Shopping', icon: Icons.shopping_basket_rounded, color: Color(0xFFFF8A34)),
    const CategoryData(id: 3, label: 'Transportation', icon: Icons.directions_car_rounded, color: Color(0xFF8B5CF6)),
    const CategoryData(id: 4, label: 'Bills', icon: Icons.receipt_long_rounded, color: Color(0xFF3B82F6)),
    const CategoryData(id: 5, label: 'Entertainment', icon: Icons.movie_rounded, color: Color(0xFFEC4899)),
    const CategoryData(id: 6, label: 'Groceries', icon: Icons.local_grocery_store_rounded, color: Color(0xFF22C55E)),
    const CategoryData(id: 7, label: 'Health', icon: Icons.favorite_rounded, color: Color(0xFFEF4444)),
    const CategoryData(id: 8, label: 'Income', icon: Icons.attach_money_rounded, color: Color(0xFF22C55E)),
  ];

  static const List<IconData> customIconsList = [
    Icons.restaurant_rounded,
    Icons.shopping_basket_rounded,
    Icons.directions_car_rounded,
    Icons.receipt_long_rounded,
    Icons.movie_rounded,
    Icons.local_grocery_store_rounded,
    Icons.favorite_rounded,
    Icons.attach_money_rounded,
    Icons.home_rounded,
    Icons.school_rounded,
    Icons.fitness_center_rounded,
    Icons.flight_takeoff_rounded,
    Icons.card_giftcard_rounded,
    Icons.videogame_asset_rounded,
    Icons.pets_rounded,
    Icons.work_rounded,
    Icons.medical_services_rounded,
    Icons.build_rounded,
    Icons.dry_cleaning_rounded,
    Icons.wifi_rounded,
    Icons.electrical_services_rounded,
    Icons.water_drop_rounded,
    Icons.savings_rounded,
    Icons.help_outline,
    Icons.payments_rounded,
    Icons.local_mall_rounded,
    Icons.coffee_rounded,
    Icons.directions_bus_rounded,
    Icons.sports_esports_rounded,
    Icons.medical_information_rounded,
    Icons.apartment_rounded,
  ];

  static const List<Color> customColorsList = [
    Color(0xFFEAB308), // Yellow
    Color(0xFFFF8A34), // Orange
    Color(0xFF8B5CF6), // Purple
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFF22C55E), // Green
    Color(0xFFEF4444), // Red
    Color(0xFF06B6D4), // Cyan
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFF43F5E), // Rose
    Color(0xFF84CC16), // Lime
    Color(0xFF10B981), // Emerald
    Color(0xFFF97316), // Dark Orange
    Color(0xFFD946EF), // Fuchsia
    Color(0xFF64748B), // Slate/Grey
  ];

  static Future<void> loadFromDatabase() async {
    try {
      final dbCats = await DatabaseHelper.instance.getAllCategories();
      if (dbCats.isNotEmpty) {
        all = dbCats.map((map) {
          return CategoryData(
            id: map['id'] as int,
            label: map['label'] as String,
            icon: IconData(map['icon_code'] as int, fontFamily: 'MaterialIcons'),
            color: Color(map['color_value'] as int),
          );
        }).toList();
      }
      await loadRules();
    } catch (e) {
      debugPrint('Error loading categories from database: $e');
    }
  }

  static Future<void> loadRules() async {
    try {
      final jsonStr = await DatabaseHelper.instance.getSetting('category_rules');
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        categoryRules = decoded.map((key, value) {
          return MapEntry(key, List<String>.from(value as List));
        });
      }
    } catch (e) {
      debugPrint('Error loading category rules: $e');
    }
  }

  static Future<void> saveRules() async {
    try {
      final jsonStr = json.encode(categoryRules);
      await DatabaseHelper.instance.setSetting('category_rules', jsonStr);
    } catch (e) {
      debugPrint('Error saving category rules: $e');
    }
  }

  static CategoryData getByName(String name) {
    return all.firstWhere(
      (c) => c.label == name,
      orElse: () => const CategoryData(label: 'Other', icon: Icons.help_outline, color: Colors.grey),
    );
  }

  /// Returns all categories EXCEPT 'Income', useful for expense charts.
  static List<CategoryData> get expenseCategories => 
      all.where((c) => c.label != 'Income').toList();

  static Map<String, List<String>> categoryRules = {
    'Food': [
      'zomato', 'swiggy', 'starbucks', 'mcdonald', 'kfc', 'burger king', 'domino', 'pizza hut',
      'subway', 'dunkin', 'taco bell', 'blue tokai', 'third wave', 'eatclub', 'faasos', 'behrouz',
      'restaurant', 'hotel', 'cafe', 'coffee', 'dining', 'bakery', 'biryani', 'tiffin'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'reliance digital', 'croma', 'vijay sales',
      'zara', 'h&m', 'uniqlo', 'marks & spencer', 'westside', 'lifestyle', 'pantaloons', 'decathlon',
      'store', 'mall', 'mart', 'retail', 'clovia', 'zivame', 'fossil', 'titan'
    ],
    'Groceries': [
      'bigbasket', 'blinkit', 'zepto', 'instamart', 'dunzo', 'more retail', 'spencer', 'reliance fresh',
      'dmart', 'nature\'s basket', 'grocery', 'groceries', 'vegetables', 'milk', 'fruits', 'kirana'
    ],
    'Transportation': [
      'uber', 'ola', 'rapido', 'blusmart', 'indigo', 'air india', 'vistara', 'irctc', 'porter',
      'shell', 'hpcl', 'bpcl', 'iocl', 'fuel', 'petrol', 'diesel', 'toll', 'parking', 'metro', 'taxi'
    ],
    'Bills': [
      'airtel', 'jio', 'vodafone', 'bsnl', 'tata play', 'dish tv', 'adani', 'bescom', 'tata power',
      'lic', 'policybazaar', 'electricity', 'water', 'gas', 'bill', 'recharge', 'mobile',
      'broadband', 'internet', 'dth', 'utility', 'insurance', 'emi',
      'bijili', 'bijli', 'rentok', 'rent'
    ],
    'Entertainment': [
      'netflix', 'prime video', 'hotstar', 'sonyliv', 'zee5', 'bookmyshow', 'pvr', 'inox',
      'spotify', 'itunes', 'apple music', 'steam', 'epic games', 'playstation', 'xbox',
      'movie', 'cinema', 'music', 'game', 'subscription'
    ],
    'Health': [
      'apollo', 'netmeds', '1mg', 'pharmeasy', 'medplus', 'practo', 'cult.fit', 'vlcc',
      'hospital', 'clinic', 'pharmacy', 'medic', 'health', 'doctor', 'diagnostic', 'lab', 'medicine'
    ],
    'Income': [
      'salary', 'credit', 'refund', 'cashback', 'freelance', 'interest'
    ],
  };

  /// Categorizes a merchant based on name and message body.
  static String detectCategory(String merchant, [String? body]) {
    final text = '${merchant.toLowerCase()} ${(body ?? "").toLowerCase()}';

    for (final entry in categoryRules.entries) {
      if (entry.value.any((kw) => text.contains(kw))) return entry.key;
    }
    return 'Other';
  }
}
