import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/user_profile_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finpulse.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        note TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT DEFAULT '',
        current REAL NOT NULL DEFAULT 0,
        target REAL NOT NULL,
        deadline TEXT NOT NULL,
        imagePath TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        name TEXT NOT NULL DEFAULT 'John Doe',
        email TEXT NOT NULL DEFAULT 'john@example.com',
        age TEXT DEFAULT '28',
        handle TEXT DEFAULT '@johndoe',
        avatarUrl TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed demo data
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // Seed default profile
    await db.insert('user_profile', {
      'id': 1,
      'name': 'Alex Morgan',
      'email': 'alex.morgan@email.com',
      'age': '28',
      'handle': '@alexmorgan',
      'avatarUrl': '',
    });

    // Seed default settings
    final defaultSettings = {
      'dark_mode': 'true',
      'notifications': 'true',
      'biometric': 'false',
    };
    for (final entry in defaultSettings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }

    // Seed transactions spanning the last 30 days
    final now = DateTime.now();
    final transactions = <Map<String, dynamic>>[
      {'amount': -1500.0, 'merchant': 'Monthly Rent', 'category': 'Bills', 'type': 'expense', 'daysAgo': 0},
      {'amount': -12.50, 'merchant': 'Starbucks Coffee', 'category': 'Food', 'type': 'expense', 'daysAgo': 0},
      {'amount': -24.50, 'merchant': 'Uber Trip', 'category': 'Transport', 'type': 'expense', 'daysAgo': 1},
      {'amount': -1199.00, 'merchant': 'Electronics Hub', 'category': 'Shopping', 'type': 'expense', 'daysAgo': 1},
      {'amount': 4800.00, 'merchant': 'Salary Credit', 'category': 'Income', 'type': 'income', 'daysAgo': 1},
      {'amount': -87.40, 'merchant': 'Fresh Mart Groceries', 'category': 'Groceries', 'type': 'expense', 'daysAgo': 2},
      {'amount': -950.00, 'merchant': 'Electric Bill', 'category': 'Bills', 'type': 'expense', 'daysAgo': 2},
      {'amount': -54.00, 'merchant': 'Apollo Pharmacy', 'category': 'Health', 'type': 'expense', 'daysAgo': 3},
      {'amount': 2800.00, 'merchant': 'Freelance Payment', 'category': 'Income', 'type': 'income', 'daysAgo': 3},
      {'amount': -15.99, 'merchant': 'Netflix Subscription', 'category': 'Entertainment', 'type': 'expense', 'daysAgo': 4},
      {'amount': -45.00, 'merchant': 'Pizza Hut', 'category': 'Food', 'type': 'expense', 'daysAgo': 4},
      {'amount': -32.50, 'merchant': 'Gas Station', 'category': 'Transport', 'type': 'expense', 'daysAgo': 5},
      {'amount': -120.00, 'merchant': 'Nike Store', 'category': 'Shopping', 'type': 'expense', 'daysAgo': 5},
      {'amount': -68.30, 'merchant': 'Whole Foods', 'category': 'Groceries', 'type': 'expense', 'daysAgo': 6},
      {'amount': -22.00, 'merchant': 'Cinema Tickets', 'category': 'Entertainment', 'type': 'expense', 'daysAgo': 7},
      {'amount': -8.50, 'merchant': 'McDonalds', 'category': 'Food', 'type': 'expense', 'daysAgo': 7},
      {'amount': -175.00, 'merchant': 'Dentist Visit', 'category': 'Health', 'type': 'expense', 'daysAgo': 8},
      {'amount': -35.00, 'merchant': 'Uber Eats', 'category': 'Food', 'type': 'expense', 'daysAgo': 9},
      {'amount': -250.00, 'merchant': 'Amazon Purchase', 'category': 'Shopping', 'type': 'expense', 'daysAgo': 10},
      {'amount': -42.00, 'merchant': 'Lyft Ride', 'category': 'Transport', 'type': 'expense', 'daysAgo': 11},
      {'amount': -95.00, 'merchant': 'Trader Joe\'s', 'category': 'Groceries', 'type': 'expense', 'daysAgo': 12},
      {'amount': 1200.00, 'merchant': 'Side Project Income', 'category': 'Income', 'type': 'income', 'daysAgo': 14},
      {'amount': -380.00, 'merchant': 'Insurance Premium', 'category': 'Bills', 'type': 'expense', 'daysAgo': 15},
      {'amount': -65.00, 'merchant': 'Restaurant Dinner', 'category': 'Food', 'type': 'expense', 'daysAgo': 16},
      {'amount': -29.99, 'merchant': 'Spotify Premium', 'category': 'Entertainment', 'type': 'expense', 'daysAgo': 18},
      {'amount': -18.00, 'merchant': 'Bus Pass', 'category': 'Transport', 'type': 'expense', 'daysAgo': 20},
      {'amount': -450.00, 'merchant': 'Zara Clothing', 'category': 'Shopping', 'type': 'expense', 'daysAgo': 22},
      {'amount': -110.00, 'merchant': 'Costco', 'category': 'Groceries', 'type': 'expense', 'daysAgo': 24},
      {'amount': 4800.00, 'merchant': 'Salary Credit', 'category': 'Income', 'type': 'income', 'daysAgo': 28},
      {'amount': -78.00, 'merchant': 'Sushi Bar', 'category': 'Food', 'type': 'expense', 'daysAgo': 29},
    ];

    for (final tx in transactions) {
      final date = now.subtract(Duration(days: tx['daysAgo'] as int));
      await db.insert('transactions', {
        'amount': tx['amount'],
        'merchant': tx['merchant'],
        'category': tx['category'],
        'type': tx['type'],
        'timestamp': date.toIso8601String(),
        'note': '',
      });
    }

    // Seed goals
    await db.insert('goals', {
      'id': 'goal_1',
      'title': 'Dream Vacation',
      'subtitle': 'Bali Trip 2026',
      'current': 2400.0,
      'target': 5000.0,
      'deadline': 'Dec 2026',
      'imagePath': '',
    });
    await db.insert('goals', {
      'id': 'goal_2',
      'title': 'Emergency Fund',
      'subtitle': '6 months expenses',
      'current': 8500.0,
      'target': 15000.0,
      'deadline': 'Jun 2027',
      'imagePath': '',
    });
    await db.insert('goals', {
      'id': 'goal_3',
      'title': 'New MacBook',
      'subtitle': 'MacBook Pro M4',
      'current': 1200.0,
      'target': 2500.0,
      'deadline': 'Mar 2026',
      'imagePath': '',
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await database;
    return await db.insert('transactions', tx.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'timestamp DESC');
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsForDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final result = await db.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsForDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<Map<String, double>> getCategoryTotals({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (start != null && end != null) {
      where = 'timestamp BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }
    final result = await db.rawQuery('''
      SELECT category, SUM(ABS(amount)) as total
      FROM transactions
      WHERE type = 'expense' ${where != null ? 'AND $where' : ''}
      GROUP BY category
      ORDER BY total DESC
    ''', whereArgs);

    final map = <String, double>{};
    for (final row in result) {
      map[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<Map<String, int>> getCategoryCounts({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (start != null && end != null) {
      where = 'timestamp BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }
    final result = await db.rawQuery('''
      SELECT category, COUNT(*) as count
      FROM transactions
      WHERE type = 'expense' ${where != null ? 'AND $where' : ''}
      GROUP BY category
    ''', whereArgs);

    final map = <String, int>{};
    for (final row in result) {
      map[row['category'] as String] = (row['count'] as num).toInt();
    }
    return map;
  }

  Future<double> getTotalIncome({DateTime? start, DateTime? end}) async {
    final db = await database;
    String query = "SELECT SUM(amount) as total FROM transactions WHERE type = 'income'";
    List<dynamic>? args;
    if (start != null && end != null) {
      query += ' AND timestamp BETWEEN ? AND ?';
      args = [start.toIso8601String(), end.toIso8601String()];
    }
    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalExpense({DateTime? start, DateTime? end}) async {
    final db = await database;
    String query = "SELECT SUM(ABS(amount)) as total FROM transactions WHERE type = 'expense'";
    List<dynamic>? args;
    if (start != null && end != null) {
      query += ' AND timestamp BETWEEN ? AND ?';
      args = [start.toIso8601String(), end.toIso8601String()];
    }
    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<double>> getWeeklySpendingTrend() async {
    final db = await database;
    final now = DateTime.now();
    final List<double> weeklyData = [];

    for (int week = 3; week >= 0; week--) {
      final weekEnd = now.subtract(Duration(days: week * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      final result = await db.rawQuery('''
        SELECT SUM(ABS(amount)) as total
        FROM transactions
        WHERE type = 'expense'
        AND timestamp BETWEEN ? AND ?
      ''', [weekStart.toIso8601String(), weekEnd.toIso8601String()]);
      weeklyData.add((result.first['total'] as num?)?.toDouble() ?? 0.0);
    }
    return weeklyData;
  }

  Future<Map<String, List<double>>> getMonthlyIncomeExpense() async {
    final db = await database;
    final now = DateTime.now();
    final months = <String>[];
    final incomes = <double>[];
    final expenses = <double>[];

    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final mLabel = _monthLabel(month.month);
      months.add(mLabel);

      final incResult = await db.rawQuery('''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'income' AND timestamp BETWEEN ? AND ?
      ''', [month.toIso8601String(), nextMonth.toIso8601String()]);
      incomes.add((incResult.first['total'] as num?)?.toDouble() ?? 0.0);

      final expResult = await db.rawQuery('''
        SELECT SUM(ABS(amount)) as total FROM transactions
        WHERE type = 'expense' AND timestamp BETWEEN ? AND ?
      ''', [month.toIso8601String(), nextMonth.toIso8601String()]);
      expenses.add((expResult.first['total'] as num?)?.toDouble() ?? 0.0);
    }

    return {'months': [], 'incomes': incomes, 'expenses': expenses};
  }

  String _monthLabel(int m) => const [
    'JAN','FEB','MAR','APR','MAY','JUN',
    'JUL','AUG','SEP','OCT','NOV','DEC'
  ][m - 1];

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GOALS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> insertGoal(GoalModel goal) async {
    final db = await database;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GoalModel>> getAllGoals() async {
    final db = await database;
    final result = await db.query('goals');
    return result.map((map) => GoalModel.fromMap(map)).toList();
  }

  Future<void> updateGoal(GoalModel goal) async {
    final db = await database;
    await db.update('goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  Future<UserProfileModel> getUserProfile() async {
    final db = await database;
    final result = await db.query('user_profile', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return UserProfileModel.fromMap(result.first);
    }
    return UserProfileModel(
      name: 'Alex Morgan',
      email: 'alex.morgan@email.com',
      age: '28',
      handle: '@alexmorgan',
    );
  }

  Future<void> updateUserProfile(UserProfileModel profile) async {
    final db = await database;
    await db.update('user_profile', profile.toMap(),
        where: 'id = ?', whereArgs: [1]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final result = await db.query('settings');
    final map = <String, String>{};
    for (final row in result) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  /// Reset all financial data (transactions + goals), keep profile and settings
  Future<void> resetFinancialData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('goals');
  }
}
