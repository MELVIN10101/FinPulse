import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../features/auth/auth_service.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper.instance;
  UserProfileModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _db.getUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        // Provide fallback profile
        _profile = UserProfileModel(
          name: 'Alex Thompson',
          email: 'alex.t@finpulse.io',
          age: '29',
          handle: '@alex_finpulse',
        );
      });
    }
  }

  // Colors matching the Stitch design
  static const _bg = Color(0xFF16191C);
  static const _cardBg = Color(0xFF1A2028);
  static const _primary = Color(0xFF2E3F52);
  static const _textWhite = Colors.white;
  static const _textMuted = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);
  static const _danger = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
            child: CircularProgressIndicator(color: _accent)),
      );
    }

    final profile = _profile!;
    final initials = profile.name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(),

              // ── Hero / Avatar ──
              _buildAvatar(profile, initials),

              // ── Quick Stats ──
              _buildQuickStats(),

              // ── Personal Details ──
              _buildPersonalDetails(profile),

              // ── Account Management ──
              _buildAccountManagement(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: _textWhite, size: 20),
            ),
          ),
          const Expanded(
            child: Text(
              'FinPulse Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textWhite,
                  letterSpacing: -0.3),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadProfile();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_rounded,
                  color: _textWhite, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  AVATAR HERO
  // ═══════════════════════════════════════════
  Widget _buildAvatar(UserProfileModel profile, String initials) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primary.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar with ring
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
              // Edit badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(profile.name,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textWhite,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          // Handle
          Text(profile.handle.isNotEmpty ? profile.handle : '@user',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textMuted)),
          const SizedBox(height: 8),
          // Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Premium Member',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primary)),
              ),
              const SizedBox(width: 8),
              const Text('Joined Jan 2023',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  QUICK STATS
  // ═══════════════════════════════════════════
  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          _statCard('128', 'ASSETS'),
          const SizedBox(width: 12),
          _statCard('94%', 'HEALTH'),
          const SizedBox(width: 12),
          _statCard('12k', 'FOLLOWERS'),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textWhite)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  PERSONAL DETAILS
  // ═══════════════════════════════════════════
  Widget _buildPersonalDetails(UserProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERSONAL DETAILS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primary.withValues(alpha: 0.7),
                  letterSpacing: 2)),
          const SizedBox(height: 14),
          _detailRow(Icons.mail_rounded, 'Email Address', profile.email,
              trailing: const Icon(Icons.verified_rounded,
                  color: Color(0xFF22C55E), size: 18)),
          const SizedBox(height: 8),
          _detailRow(Icons.calendar_today_rounded, 'Age / Date of Birth',
              profile.age.isNotEmpty ? profile.age : 'Not set'),
          const SizedBox(height: 8),
          _detailRow(
              Icons.location_on_rounded, 'Location', 'Not set'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: _textMuted)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textWhite)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  ACCOUNT MANAGEMENT
  // ═══════════════════════════════════════════
  Widget _buildAccountManagement() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCOUNT MANAGEMENT',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primary.withValues(alpha: 0.7),
                  letterSpacing: 2)),
          const SizedBox(height: 14),

          // Edit Profile — primary style
          GestureDetector(
            onTap: _showEditProfile,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit Profile',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Security
          _actionButton(
            icon: Icons.lock_rounded,
            label: 'Security & Password',
            onTap: () => _showSnack('Password change — offline mode'),
          ),
          const SizedBox(height: 8),

          // Notifications toggle
          _actionButton(
            icon: Icons.notifications_active_rounded,
            label: 'Push Notifications',
            trailing: _toggleDot(),
            onTap: () => _showSnack('Notification settings'),
          ),
          const SizedBox(height: 8),

          // Sign Out — danger
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A2028),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign Out',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out',
                          style: TextStyle(color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService.instance.signOut();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.logout_rounded, color: _danger, size: 22),
                  SizedBox(width: 12),
                  Text('Sign Out',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _textWhite, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textWhite)),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: _textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _toggleDot() {
    return Container(
      width: 40,
      height: 22,
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEditProfile() {
    final nameC = TextEditingController(text: _profile?.name ?? '');
    final emailC = TextEditingController(text: _profile?.email ?? '');
    final handleC = TextEditingController(text: _profile?.handle ?? '');
    final ageC = TextEditingController(text: _profile?.age ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Edit Profile',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _editField('Name', nameC),
            const SizedBox(height: 12),
            _editField('Email', emailC),
            const SizedBox(height: 12),
            _editField('Handle', handleC),
            const SizedBox(height: 12),
            _editField('Age', ageC, keyboard: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final updated = UserProfileModel(
                    name: nameC.text.trim(),
                    email: emailC.text.trim(),
                    handle: handleC.text.trim(),
                    age: ageC.text.trim(),
                  );
                  await _db.updateUserProfile(updated);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadProfile();
                  _showSnack('Profile updated');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Save Changes',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller,
      {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2535),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}