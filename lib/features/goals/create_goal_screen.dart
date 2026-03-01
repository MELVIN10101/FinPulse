import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'goals_screen.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _deadline;
  File? _pickedImage;

  final Map<String, String?> _errors = {
    'name': null,
    'target': null,
    'deadline': null,
  };

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _sheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take a Photo',
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (img != null) {
                  setState(() => _pickedImage = File(img.path));
                }
              },
            ),
            _sheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (img != null) {
                  setState(() => _pickedImage = File(img.path));
                }
              },
            ),
            if (_pickedImage != null)
              _sheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _pickedImage = null);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF0D1117),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0D1117),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
        _errors['deadline'] = null;
      });
    }
  }

  String _formatDeadline(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _errors['name'] = 'Goal name is required';
        valid = false;
      } else {
        _errors['name'] = null;
      }
      final target = double.tryParse(_targetController.text.trim());
      if (target == null || target <= 0) {
        _errors['target'] = 'Enter a valid target amount';
        valid = false;
      } else {
        _errors['target'] = null;
      }
      if (_deadline == null) {
        _errors['deadline'] = 'Select a deadline';
        valid = false;
      } else {
        _errors['deadline'] = null;
      }
    });
    return valid;
  }

  void _createGoal() {
    if (!_validate()) return;

    final goal = GoalItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _nameController.text.trim(),
      subtitle: '',
      current: 0,
      target: double.parse(_targetController.text.trim()),
      deadline: _formatDeadline(_deadline!),
      imagePath: _pickedImage?.path ?? '',
    );

    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF040B16),
        body: SafeArea(
          child: Column(
            children: [
              /// ── APP BAR ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Create New Goal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// ── IMAGE PICKER ─────────────────────────────
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _pickedImage != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_pickedImage!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit_rounded,
                                                color: Colors.white,
                                                size: 12),
                                            SizedBox(width: 4),
                                            Text('Change',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          color: Colors.white,
                                          size: 24),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Add Cover Photo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Optional',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// ── GOAL NAME ────────────────────────────────
                      _label('GOAL NAME'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: _nameController,
                        hint: 'e.g. Dream Wedding',
                        error: _errors['name'],
                        onChanged: (_) =>
                            setState(() => _errors['name'] = null),
                      ),

                      const SizedBox(height: 20),

                      /// ── TARGET + DEADLINE ROW ─────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('TARGET AMOUNT'),
                                const SizedBox(height: 8),
                                _inputField(
                                  controller: _targetController,
                                  hint: '5,000',
                                  prefixText: '₹ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  error: _errors['target'],
                                  onChanged: (_) =>
                                      setState(() => _errors['target'] = null),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('DEADLINE'),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _pickDeadline,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 15),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A2535),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _errors['deadline'] != null
                                            ? const Color(0xFFEF4444)
                                            : Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 16,
                                          color: _deadline != null
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _deadline != null
                                                ? _formatDeadline(_deadline!)
                                                : 'mm/dd/yyy',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _deadline != null
                                                  ? Colors.white
                                                  : const Color(0xFF334155),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_errors['deadline'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(_errors['deadline']!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFEF4444))),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      /// ── CREATE BUTTON ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _createGoal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Create Goal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    String? error,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2535),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFEF4444)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF334155)),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 15),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFEF4444))),
        ],
      ],
    );
  }
}
