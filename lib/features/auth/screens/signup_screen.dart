import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/user_profile_model.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // ── Controllers ─────────────────────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _ageCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading      = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  String _gender       = '';   // '' | 'Male' | 'Female' | 'Non-binary' | 'Prefer not to say'

  static const _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  // ── Colours ──────────────────────────────────────────────────────────────
  static const _bg        = Color(0xFF040B16);
  static const _card      = Color(0xFF0D1B2A);
  static const _accent    = Color(0xFF6C63FF);
  static const _border    = Color(0x1AFFFFFF);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Sign-up logic ────────────────────────────────────────────────────────

  Future<void> _signUp() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final age      = _ageCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm  = _confirmCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all required fields.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService.instance.signUpWithEmail(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);
      _showError(error);
      return;
    }

    // ── Persist age + gender to the local user_profile table ────────────
    try {
      final existing = await DatabaseHelper.instance.getUserProfile();
      final updated = existing.copyWith(
        name: name,
        email: email,
        age: age,
        gender: _gender,
      );
      await DatabaseHelper.instance.updateUserProfile(updated);
    } catch (_) {
      // Non-fatal – profile will be editable from the Profile screen later.
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    // AuthWrapper auto-navigates on success via stream
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo / heading ─────────────────────────────────────────
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Join FinPulse',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Your data stays on your device.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.45))),
                ]),
              ]),
              const SizedBox(height: 32),

              // ── Section: Basic info ────────────────────────────────────
              _sectionLabel('Basic Info'),
              const SizedBox(height: 12),

              _buildTextField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),

              _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),

              _buildTextField(
                  controller: _ageCtrl,
                  label: 'Age (optional)',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 24),

              // ── Section: Gender ────────────────────────────────────────
              _sectionLabel('Gender (optional)'),
              const SizedBox(height: 12),
              _buildGenderSelector(),
              const SizedBox(height: 24),

              // ── Section: Security ──────────────────────────────────────
              _sectionLabel('Security'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _passwordCtrl,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePass,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _confirmCtrl,
                label: 'Confirm Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 32),

              // ── Create button ──────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sign in link ───────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Already have an account?  ',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Sign In',
                      style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gender chip selector ─────────────────────────────────────────────────

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genderOptions.map((option) {
              final selected = _gender == option;
              return GestureDetector(
                onTap: () => setState(() {
                  // Tap again to deselect (toggle)
                  _gender = selected ? '' : option;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? _accent
                          : Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Checkmark icon when selected
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: selected
                          ? const Padding(
                              key: ValueKey('check'),
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14),
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                    Text(
                      option,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}
