import 'package:flutter/material.dart';
import '../navigation/main_navigation_screen.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';
import '../../data/services/firestore_user_service.dart';

import '../profile/widgets/app_lock_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Sync on every app open/sign-in
          FirestoreUserService.instance.syncNow();
          return const AppLockWrapper(
            child: MainNavigationScreen(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}