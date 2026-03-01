import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../transactions/screens/history_shell_screen.dart';
import '../insights/insights_screen.dart';
import '../goals/goals_screen.dart';
import '../profile/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Use a fixed list of widgets, NOT a getter
  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryShellScreen(),
    const InsightsScreen(),
    const GoalsScreen(),
    const ProfileScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),


      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF08121F),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),

          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF64748B),

          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_rounded),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_rounded),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: "Insights",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_rounded),
              label: "Goals",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
