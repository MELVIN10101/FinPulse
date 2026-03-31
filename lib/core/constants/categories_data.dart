import 'package:flutter/material.dart';

class CategoryData {
  final String label;
  final IconData icon;
  final Color color;

  const CategoryData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class AppCategories {
  static const List<CategoryData> all = [
    CategoryData(label: 'Food', icon: Icons.restaurant_rounded, color: Color(0xFFEAB308)),
    CategoryData(label: 'Shopping', icon: Icons.shopping_basket_rounded, color: Color(0xFFFF8A34)),
    CategoryData(label: 'Transport', icon: Icons.directions_car_rounded, color: Color(0xFF8B5CF6)),
    CategoryData(label: 'Bills', icon: Icons.receipt_long_rounded, color: Color(0xFF3B82F6)),
    CategoryData(label: 'Entertainment', icon: Icons.movie_rounded, color: Color(0xFFEC4899)),
    CategoryData(label: 'Groceries', icon: Icons.local_grocery_store_rounded, color: Color(0xFF22C55E)),
    CategoryData(label: 'Health', icon: Icons.favorite_rounded, color: Color(0xFFEF4444)),
    CategoryData(label: 'Income', icon: Icons.attach_money_rounded, color: Color(0xFF22C55E)),
  ];

  static CategoryData getByName(String name) {
    return all.firstWhere(
      (c) => c.label == name,
      orElse: () => const CategoryData(label: 'Other', icon: Icons.help_outline, color: Colors.grey),
    );
  }

  /// Returns all categories EXCEPT 'Income', useful for expense charts.
  static List<CategoryData> get expenseCategories => 
      all.where((c) => c.label != 'Income').toList();

  /// Categorizes a merchant based on name and message body.
  static String detectCategory(String merchant, [String? body]) {
    final text = '${merchant.toLowerCase()} ${(body ?? "").toLowerCase()}';

    final rules = <String, List<String>>{
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
      'Transport': [
        'uber', 'ola', 'rapido', 'blusmart', 'indigo', 'air india', 'vistara', 'irctc', 'porter',
        'shell', 'hpcl', 'bpcl', 'iocl', 'fuel', 'petrol', 'diesel', 'toll', 'parking', 'metro', 'taxi'
      ],
      'Bills': [
        'airtel', 'jio', 'vodafone', 'bsnl', 'tata play', 'dish tv', 'adani', 'bescom', 'tata power',
        'lic', 'policybazaar', 'electricity', 'water', 'gas', 'bill', 'recharge', 'mobile',
        'broadband', 'internet', 'dth', 'utility', 'insurance', 'emi'
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
    };

    for (final entry in rules.entries) {
      if (entry.value.any((kw) => text.contains(kw))) return entry.key;
    }
    return 'Other';
  }
}
