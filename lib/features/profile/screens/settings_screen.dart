import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  bool _darkMode = true;
  bool _notifications = true;
  bool _biometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    if (!mounted) return;
    setState(() {
      _darkMode = s['dark_mode'] != 'false';
      _notifications = s['notifications'] != 'false';
      _biometric = s['biometric'] == 'true';
      _loading = false;
    });
  }

  Future<void> _save(String k, bool v) => _db.setSetting(k, v.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B16),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : Column(children: [
                _header(),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 24),
                    _label('APPEARANCE'), const SizedBox(height: 12),
                    _card([_toggle(Icons.dark_mode_rounded, 'Dark Mode', 'Use dark theme', _darkMode, (v) { setState(() => _darkMode = v); _save('dark_mode', v); })]),
                    const SizedBox(height: 24),
                    _label('NOTIFICATIONS'), const SizedBox(height: 12),
                    _card([_toggle(Icons.notifications_outlined, 'Push Notifications', 'Get spending alerts', _notifications, (v) { setState(() => _notifications = v); _save('notifications', v); })]),
                    const SizedBox(height: 24),
                    _label('SECURITY'), const SizedBox(height: 12),
                    _card([_toggle(Icons.fingerprint_rounded, 'Biometric Unlock', 'Use fingerprint or face', _biometric, (v) { setState(() => _biometric = v); _save('biometric', v); })]),
                    const SizedBox(height: 24),
                    _label('DATA'), const SizedBox(height: 12),
                    _card([_action(Icons.delete_sweep_rounded, 'Reset Financial Data', 'Delete all transactions and goals', const Color(0xFFEF4444), _confirmReset)]),
                    const SizedBox(height: 24),
                    _label('ABOUT'), const SizedBox(height: 12),
                    _card([
                      _action(Icons.privacy_tip_outlined, 'Privacy Policy', null, null, () => _snack('All data stays on device')),
                      _div(),
                      _action(Icons.info_outline_rounded, 'App Version', null, null, null, trailing: const Text('1.0.0', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
                    ]),
                    const SizedBox(height: 40),
                  ]),
                )),
              ]),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context), child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFF0D1117), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
      )),
      const Expanded(child: Center(child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)))),
      const SizedBox(width: 36),
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));

  Widget _card(List<Widget> c) => Container(
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: c),
  );

  Widget _toggle(IconData icon, String title, String sub, bool val, ValueChanged<bool> cb) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF94A3B8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ])),
      Switch.adaptive(value: val, onChanged: cb, activeColor: const Color(0xFF3B82F6), inactiveTrackColor: const Color(0xFF1E293B)),
    ]),
  );

  Widget _action(IconData icon, String title, String? sub, Color? iconC, VoidCallback? onTap, {Widget? trailing}) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), color: Colors.transparent, child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: (iconC ?? const Color(0xFF94A3B8)).withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconC ?? const Color(0xFF94A3B8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        if (sub != null) ...[const SizedBox(height: 3), Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))],
      ])),
      trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
    ])),
  );

  Widget _div() => Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 72);

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: const Color(0xFF1E293B), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  void _confirmReset() => showDialog(context: context, builder: (_) => AlertDialog(
    backgroundColor: const Color(0xFF0D1117),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Reset Financial Data?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    content: const Text('This will permanently delete all transactions and goals. Profile and settings will be kept.\n\nThis cannot be undone.', style: TextStyle(color: Color(0xFF94A3B8), height: 1.5)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
      TextButton(onPressed: () async { await _db.resetFinancialData(); if (!mounted) return; Navigator.pop(context); _snack('All financial data has been reset'); }, child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))),
    ],
  ));
}
