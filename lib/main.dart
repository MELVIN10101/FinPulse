import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/auth/auth_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // Initialize SQLite FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    // Initialize Firebase for Android / iOS
    await Firebase.initializeApp();
  }

  // Restore persisted auth session (desktop: SharedPreferences; mobile: Firebase handles it)
  await AuthService.instance.init();

  runApp(const FinPulseApp());
}