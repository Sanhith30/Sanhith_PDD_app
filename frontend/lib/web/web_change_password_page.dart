import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebChangePasswordPage extends StatefulWidget {
  const WebChangePasswordPage({super.key});

  @override
  State<WebChangePasswordPage> createState() => _WebChangePasswordPageState();
}

class _WebChangePasswordPageState extends State<WebChangePasswordPage> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  static const Color _maroon = Color(0xFF7B1E3A);
  static const Color _bg     = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _text   = Color(0xFF1E0A10);
  static const Color _muted  = Color(0xFF9E8A8F);
  static const Color _gold   = Color(0xFFC9A84C);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _red     = Color(0xFFC62828);

  void _suggestPassphrase() {
    final prefixes = ['Molar', 'Enamel', 'Crown', 'Pulp', 'Canine', 'Gingiva', 'Dentist', 'Cusp', 'Incisor', 'Maxilla', 'Mandible', 'Orthodontic'];
    final connectors = ['Shield', 'Guard', 'Apex', 'Ridge', 'Arch', 'Root', 'Bite', 'Smile', 'SDC', 'Clinic', 'Oral', 'Ulcer'];
    final math.Random random = math.Random();
    
    final pfx = prefixes[random.nextInt(prefixes.length)];
    final conn = connectors[random.nextInt(connectors.length)];
    final numVal = random.nextInt(900) + 100; // 100 to 999
    final syms = ['!', '?', '#', '\$', '@', '*'];
    final sym = syms[random.nextInt(6)];
    
    final suggestion = '$pfx-$conn-$numVal$sym';
    setState(() {
      _newPassController.text = suggestion;
      _confirmPassController.text = suggestion;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suggested secure password generated!'), backgroundColor: Colors.green)
    );
  }

  Future<bool> _isPasswordReused(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'history_${email.toLowerCase()}';
      final history = prefs.getStringList(key) ?? [];
      final hashed = sha256.convert(utf8.encode(password)).toString();
      return history.contains(hashed);
    } catch (_) {
      return false;
    }
  }

  Future<void> _savePasswordToHistory(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'history_${email.toLowerCase()}';
      final history = prefs.getStringList(key) ?? [];
      final hashed = sha256.convert(utf8.encode(password)).toString();
      
      history.insert(0, hashed);
      if (history.length > 3) {
        history.removeRange(3, history.length);
      }
      await prefs.setStringList(key, history);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final oldP = _oldPassController.text;
    final newP = _newPassController.text;
    final confP = _confirmPassController.text;

    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
      _error('Please fill all fields');
      return;
    }

    if (newP != confP) {
      _error('New passwords do not match');
      return;
    }

    if (newP.length < 6) {
      _error('Password must be at least 6 characters');
      return;
    }

    if (newP.contains(' ')) {
      _error('Password cannot contain spaces');
      return;
    }

    if (!newP.contains(RegExp(r'[A-Za-z]')) || !newP.contains(RegExp(r'[0-9]')) || !newP.contains(RegExp(r'[^A-Za-z0-9]'))) {
      _error('Password must contain letters, numbers, and a special character');
      return;
    }

    final reused = await _isPasswordReused(Session.instance.email ?? '', newP);
    if (reused) {
      _error('Security Alert: Cannot reuse any of your last 3 passwords.');
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await LocalDb.instance.changePassword(
        Session.instance.email ?? '',
        oldP,
        newP,
      );

      if (success) {
        await _savePasswordToHistory(Session.instance.email ?? '', newP);
        _oldPassController.clear();
        _newPassController.clear();
        _confirmPassController.clear();
        _success('Password changed successfully');
      } else {
        _error('Incorrect current password');
      }
    } catch (e) {
      _error(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Change Password', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: _text),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: _maroon.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update Security Password', style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Set a new clinician credentials password.', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 32),

              _buildLabel('Current Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _oldPassController,
                hint: 'Enter current password',
                obscure: _obscureOld,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureOld = !_obscureOld),
                  child: Icon(_obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _muted),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('New Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _newPassController,
                hint: 'Enter new password',
                obscure: _obscureNew,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                  child: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _muted),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Confirm New Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _confirmPassController,
                hint: 'Confirm new password',
                obscure: _obscureNew,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                  child: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _muted),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _suggestPassphrase,
                  icon: const Icon(Icons.psychology_alt_outlined, size: 16, color: _maroon),
                  label: const Text('Suggest Secure Password', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _maroon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('UPDATE PASSWORD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold));

  Widget _buildTextField({required TextEditingController controller, required String hint, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _muted.withOpacity(0.55)),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix) : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
