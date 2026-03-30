import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/auth/auth_service.dart';
import 'data/services/notification_service.dart';
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

    // Initialize SMS capture + local notifications (Android only)
    if (Platform.isAndroid) {
      await NotificationService.instance.init();
    }
  }

  // Restore persisted auth session
  await AuthService.instance.init();

  runApp(const FinPulseApp());
}