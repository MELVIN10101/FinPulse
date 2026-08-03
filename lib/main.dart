import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/auth/auth_service.dart';
import 'data/services/notification_service.dart';
import 'data/local/database_helper.dart';
import 'data/services/local_ai_classifier.dart';
import 'core/constants/categories_data.dart';
import 'core/theme/theme_manager.dart';
import 'core/privacy/privacy_manager.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // Initialize SQLite FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    // Initialize Firebase for Android / iOS
    await Firebase.initializeApp();
  }

  // Restore persisted auth session
  await AuthService.instance.init();

  // Initialize Theme Manager
  await ThemeManager.instance.init();

  // Initialize Privacy Manager
  await PrivacyManager.instance.init();

  // Load dynamic categories from database
  await AppCategories.loadFromDatabase();

  // Train local AI classifier on startup
  final txs = await DatabaseHelper.instance.getAllTransactions();
  LocalAIClassifier.instance.train(txs);

  runApp(const FinPulseApp());
}