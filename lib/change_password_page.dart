import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  static const Color _maroon = Color(0xFF7B1E3A);
  static const Color _bg     = Color(0xFFFAF7F4);
  static const Color _text   = Color(0xFF1E0A10);
  static const Color _muted  = Color(0xFF9E8A8F);

  Future<void> _submit() async {
    final oldP = _oldPassController.text.trim();
    final newP = _newPassController.text.trim();
    final confP = _confirmPassController.text.trim();

    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (newP != confP) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')));
      return;
    }

    if (newP.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await LocalDb.instance.changePassword(
        Session.instance.email ?? '',
        oldP,
        newP,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password updated successfully')));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Current password is incorrect')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Change Password', 
            style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Security Update', 
              style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Please enter your current password to authorize a change.',
              style: TextStyle(color: _muted, fontSize: 14)),
          const SizedBox(height: 32),

          _buildField('Current Password', _oldPassController, _obscureOld, () {
            setState(() => _obscureOld = !_obscureOld);
          }),
          const SizedBox(height: 20),
          _buildField('New Password', _newPassController, _obscureNew, () {
            setState(() => _obscureNew = !_obscureNew);
          }),
          const SizedBox(height: 20),
          _buildField('Confirm New Password', _confirmPassController, _obscureNew, null),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool obscure, VoidCallback? onToggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: InputBorder.none,
            hintText: '••••••••',
            hintStyle: TextStyle(color: _muted.withOpacity(0.5)),
            suffixIcon: onToggle != null 
              ? IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _muted, size: 20), onPressed: onToggle)
              : null,
          ),
        ),
      ),
    ]);
  }
}
