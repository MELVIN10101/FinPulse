import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final _localAuth = LocalAuthentication();
  UserProfileModel? _profile;
  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  File? _avatarFile;

  // Colors
  static const _bg = Color(0xFF16191C);
  static const _primary = Color(0xFF2E3F52);
  static const _textWhite = Colors.white;
  static const _textMuted = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);
  static const _danger = Color(0xFFEF4444);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_loadProfile(), _loadSettings(), _checkBiometric()]);
  }

  Future<void> _loadProfile() async {
    try {
      // Prefer signed-in user details from auth service
      final authUser = AuthService.instance.currentUser;
      UserProfileModel dbProfile;
      try {
        dbProfile = await _db.getUserProfile();
      } catch (_) {
        dbProfile = UserProfileModel(
          name: authUser?.name ?? 'User',
          email: authUser?.email ?? '',
        );
      }

      // Merge: use auth name/email if they look like defaults
      final mergedName = (authUser?.name.isNotEmpty == true &&
              dbProfile.name == 'Alex Morgan')
          ? authUser!.name
          : dbProfile.name;
      final mergedEmail =
          (authUser?.email.isNotEmpty == true) ? authUser!.email : dbProfile.email;
      final mergedAvatar = (authUser?.avatarUrl.isNotEmpty == true &&
              dbProfile.avatarUrl.isEmpty)
          ? authUser!.avatarUrl
          : dbProfile.avatarUrl;

      final merged = UserProfileModel(
        name: mergedName,
        email: mergedEmail,
        age: dbProfile.age,
        handle: dbProfile.handle,
        avatarUrl: mergedAvatar,
      );

      if (!mounted) return;
      setState(() {
        _profile = merged;
        _loading = false;
      });

      // Write merged data back if changed
      if (merged.name != dbProfile.name || merged.email != dbProfile.email) {
        await _db.updateUserProfile(merged);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _profile = UserProfileModel(name: 'User', email: '');
      });
    }
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = s['notifications'] != 'false';
      _biometricEnabled = s['biometric'] == 'true';
    });
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      setState(() => _biometricAvailable = available || supported);
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricAvailable = false);
    }
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
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
              _buildHeader(),
              _buildAvatar(profile, initials),
              _buildQuickStats(),
              _buildPersonalDetails(profile),
              _buildAccountManagement(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  HEADER
  // ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: _circleBtn(Icons.arrow_back),
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
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadProfile();
              _loadSettings();
            },
            child: _circleBtn(Icons.settings_rounded),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _textWhite, size: 20),
      );

  // ──────────────────────────────────────────────
  //  AVATAR
  // ──────────────────────────────────────────────
  Widget _buildAvatar(UserProfileModel profile, String initials) {
    final authUser = AuthService.instance.currentUser;
    final networkUrl =
        authUser?.avatarUrl.isNotEmpty == true ? authUser!.avatarUrl : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primary.withOpacity(0.1), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          // Avatar with ring + tap to change
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
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
                        color: _primary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarFile != null
                        ? Image.file(_avatarFile!, fit: BoxFit.cover)
                        : (profile.avatarUrl.isNotEmpty &&
                                    profile.avatarUrl.startsWith('/')
                                ? Image.file(File(profile.avatarUrl),
                                    fit: BoxFit.cover)
                                : networkUrl != null
                                    ? Image.network(networkUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _initialsWidget(initials))
                                    : _initialsWidget(initials)),
                  ),
                ),
                // Camera badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(profile.name,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textWhite,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
              profile.handle.isNotEmpty
                  ? profile.handle
                  : profile.email.isNotEmpty
                      ? profile.email
                      : '@user',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _textMuted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accent.withOpacity(0.2)),
                ),
                child: Row(children: const [
                  Icon(Icons.verified_rounded, color: _accent, size: 13),
                  SizedBox(width: 4),
                  Text('Verified Member',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accent)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget(String initials) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
        ),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      );

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Take Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      final file = File(picked.path);
      setState(() => _avatarFile = file);
      // Save path to DB
      final updated = _profile!.copyWith(avatarUrl: picked.path);
      await _db.updateUserProfile(updated);
      setState(() => _profile = updated);
      if (mounted) _showSnack('Profile photo updated');
    } catch (e) {
      if (mounted) _showSnack('Could not pick image: $e');
    }
  }

  // ──────────────────────────────────────────────
  //  QUICK STATS
  // ──────────────────────────────────────────────
  Widget _buildQuickStats() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _db.getAllTransactions(),
        _db.getTotalIncome(),
        _db.getAllGoals(),
      ]),
      builder: (context, snap) {
        final txCount =
            snap.hasData ? (snap.data![0] as List).length.toString() : '—';
        final income = snap.hasData
            ? '\$${(snap.data![1] as double).toStringAsFixed(0)}'
            : '—';
        final goals =
            snap.hasData ? (snap.data![2] as List).length.toString() : '—';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            children: [
              _statCard(txCount, 'TRANSACTIONS'),
              const SizedBox(width: 12),
              _statCard(income, 'INCOME'),
              const SizedBox(width: 12),
              _statCard(goals, 'GOALS'),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withOpacity(0.05)),
          ),
          child: Column(children: [
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
          ]),
        ),
      );

  // ──────────────────────────────────────────────
  //  PERSONAL DETAILS
  // ──────────────────────────────────────────────
  Widget _buildPersonalDetails(UserProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('PERSONAL DETAILS'),
          const SizedBox(height: 14),
          _detailRow(Icons.mail_rounded, 'Email Address', profile.email,
              trailing: const Icon(Icons.verified_rounded,
                  color: Color(0xFF22C55E), size: 18)),
          const SizedBox(height: 8),
          _detailRow(Icons.cake_rounded, 'Age / Date of Birth',
              profile.age.isNotEmpty ? profile.age : 'Not set'),
          const SizedBox(height: 8),
          _detailRow(
              Icons.alternate_email_rounded,
              'Handle',
              profile.handle.isNotEmpty ? profile.handle : 'Not set'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
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
                    style: const TextStyle(fontSize: 11, color: _textMuted)),
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

  // ──────────────────────────────────────────────
  //  ACCOUNT MANAGEMENT
  // ──────────────────────────────────────────────
  Widget _buildAccountManagement() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ACCOUNT MANAGEMENT'),
          const SizedBox(height: 14),

          // Edit Profile
          _primaryButton(
            icon: Icons.edit_note_rounded,
            label: 'Edit Profile',
            onTap: _showEditProfile,
          ),
          const SizedBox(height: 8),

          // Security & Password → Settings (Security section)
          _actionButton(
            icon: Icons.lock_rounded,
            label: 'Security & Password',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadSettings();
            },
          ),
          const SizedBox(height: 8),

          // Push Notifications toggle (real)
          _actionButton(
            icon: Icons.notifications_active_rounded,
            label: 'Push Notifications',
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: _accent,
              inactiveTrackColor: _primary.withOpacity(0.3),
            ),
            onTap: () => _toggleNotifications(!_notificationsEnabled),
          ),
          const SizedBox(height: 8),

          // Biometric Unlock (real)
          _actionButton(
            icon: Icons.fingerprint_rounded,
            label: 'Biometric Unlock',
            subtitle: _biometricAvailable
                ? null
                : 'Not available on this device',
            trailing: Switch.adaptive(
              value: _biometricEnabled,
              onChanged:
                  _biometricAvailable ? _toggleBiometric : null,
              activeColor: _accent,
              inactiveTrackColor: _primary.withOpacity(0.3),
            ),
            onTap: _biometricAvailable
                ? () => _toggleBiometric(!_biometricEnabled)
                : null,
          ),
          const SizedBox(height: 8),

          // Reset Data — password protected
          _actionButton(
            icon: Icons.delete_sweep_rounded,
            label: 'Reset Financial Data',
            iconColor: _danger,
            onTap: _confirmResetWithPassword,
          ),
          const SizedBox(height: 8),

          // Sign Out
          GestureDetector(
            onTap: _confirmSignOut,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _danger.withOpacity(0.2)),
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

  // ──────────────────────────────────────────────
  //  NOTIFICATION TOGGLE
  // ──────────────────────────────────────────────
  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          if (mounted) {
            _showSnack('Enable notifications in device Settings');
            await openAppSettings();
          }
          return;
        }
      }
    }
    setState(() => _notificationsEnabled = enabled);
    await _db.setSetting('notifications', enabled.toString());
    if (mounted) {
      _showSnack(
          enabled ? 'Notifications enabled' : 'Notifications disabled');
    }
  }

  // ──────────────────────────────────────────────
  //  BIOMETRIC TOGGLE
  // ──────────────────────────────────────────────
  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // Verify biometric before enabling
      try {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Confirm your biometric to enable unlock',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        if (!didAuth) return;
      } on PlatformException catch (e) {
        if (mounted) _showSnack('Biometric error: ${e.message}');
        return;
      }
    }
    setState(() => _biometricEnabled = enable);
    await _db.setSetting('biometric', enable.toString());
    if (mounted) {
      _showSnack(
          enable ? 'Biometric unlock enabled' : 'Biometric unlock disabled');
    }
  }

  // ──────────────────────────────────────────────
  //  RESET DATA — password protected
  // ──────────────────────────────────────────────
  Future<void> _confirmResetWithPassword() async {
    final pwController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Financial Data',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete all transactions and goals.\n\nEnter your password to confirm.',
                style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: pwController,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Password',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _textMuted,
                          size: 18),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            TextButton(
              onPressed: () async {
                // Validate password with auth service
                final email = _profile?.email ?? '';
                final error = await AuthService.instance
                    .signInWithEmail(email, pwController.text.trim());
                if (error != null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: const Text('Incorrect password'),
                      backgroundColor: _danger,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Reset',
                  style: TextStyle(
                      color: _danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _db.resetFinancialData();
      if (mounted) _showSnack('All financial data has been reset');
    }
  }

  // ──────────────────────────────────────────────
  //  SIGN OUT
  // ──────────────────────────────────────────────
  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2028),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
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
                style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.signOut();
    }
  }

  // ──────────────────────────────────────────────
  //  EDIT PROFILE SHEET
  // ──────────────────────────────────────────────
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
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _editField('Name', nameC),
                    const SizedBox(height: 12),
                    _editField('Email', emailC,
                        keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _editField('Handle', handleC),
                    const SizedBox(height: 12),
                    _editField('Age', ageC,
                        keyboard: TextInputType.number),
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
                            avatarUrl: _profile?.avatarUrl ?? '',
                          );
                          await _db.updateUserProfile(updated);
                          if (!mounted) return;
                          Navigator.pop(context);
                          setState(() => _profile = updated);
                          _showSnack('Profile updated');
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
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
            border:
                Border.all(color: Colors.white.withOpacity(0.08)),
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

  // ──────────────────────────────────────────────
  //  REUSABLE BUTTON WIDGETS
  // ──────────────────────────────────────────────
  Widget _primaryButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? iconColor,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? _textWhite, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textWhite)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: _textMuted)),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: _textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _primary.withOpacity(0.7),
            letterSpacing: 2),
      );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}