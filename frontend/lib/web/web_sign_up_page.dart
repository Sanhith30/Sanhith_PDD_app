import 'package:flutter/material.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebSignUpPage extends StatefulWidget {
  const WebSignUpPage({super.key});

  @override
  State<WebSignUpPage> createState() => _WebSignUpPageState();
}

class _WebSignUpPageState extends State<WebSignUpPage>
    with SingleTickerProviderStateMixin {

  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading   = false;
  bool _obscurePass = true;
  bool _obscureConf = true;

  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  late AnimationController _ctrl;
  late Animation<double>   _fade;

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonL = Color(0xFF9E2D4F);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 850), vsync: this)..forward();
    _fade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    _nameFocus.dispose(); _emailFocus.dispose();
    _passFocus.dispose(); _confirmFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final n = _nameCtrl.text.trim();
    final e = _emailCtrl.text.trim();
    final p = _passCtrl.text;
    final c = _confirmCtrl.text;

    String? ne, ee, pe, ce;

    if (n.isEmpty)          ne = 'Full name is required';
    else if (n.length < 2)  ne = 'Name must be at least 2 characters';

    if (e.isEmpty) {
      ee = 'Email is required';
    } else if (!RegExp(r'^[\w\.\-]+@gmail\.com$').hasMatch(e.toLowerCase())) {
      ee = 'Only @gmail.com email addresses are allowed';
    }

    if (p.isEmpty)         pe = 'Password is required';
    else if (p.length < 6) pe = 'Password must be at least 6 characters';
    else if (p.contains(' ')) pe = 'Password cannot contain spaces';
    else if (!p.contains(RegExp(r'[A-Za-z]')) || !p.contains(RegExp(r'[0-9]')) || !p.contains(RegExp(r'[^A-Za-z0-9]'))) {
      pe = 'Password must contain letters, numbers, and a special character';
    }

    if (c.isEmpty)  ce = 'Please confirm your password';
    else if (p != c) ce = 'Passwords do not match';

    setState(() {
      _nameError = ne; _emailError = ee;
      _passError = pe; _confirmError = ce;
    });
    return ne == null && ee == null && pe == null && ce == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    try {
      final clinician = await LocalDb.instance.signUp(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      if (clinician == null) {
        setState(() {
          _emailError = 'An account already exists for that email or there was a server error.';
          _isLoading = false;
        });
        return;
      }

      Session.instance.set(clinician);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (err) {
      setState(() {
        _emailError = err.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: Row(
          children: [
            // Left Panel (Branding)
            Expanded(
              flex: 12,
              child: Container(
                color: _maroon,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: GridPaper(
                          color: _gold,
                          interval: 60,
                          subdivisions: 1,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                border: Border.all(color: _gold.withOpacity(0.6), width: 2),
                              ),
                              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 60),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Oral Ulcer AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w200,
                                letterSpacing: 8.0,
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 1.5,
                              color: _gold.withOpacity(0.8),
                              margin: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            const Text(
                              'Saveetha Dental College & Hospital',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2.0,
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
            // Right Panel (Form)
            Expanded(
              flex: 11,
              child: Container(
                color: _bg,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _maroon.withOpacity(0.05),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Register as a Saveetha clinician',
                                    style: TextStyle(color: _muted, fontSize: 13),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(color: _maroon, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildLabel('Full Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameCtrl,
                            focusNode: _nameFocus,
                            hint: 'Dr. John Smith',
                            icon: Icons.person_outline_rounded,
                            error: _nameError,
                            onSubmit: (_) => _emailFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),

                          _buildLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            hint: 'clinician@gmail.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            error: _emailError,
                            onSubmit: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),

                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passCtrl,
                            focusNode: _passFocus,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePass,
                            error: _passError,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePass = !_obscurePass),
                              child: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _muted, size: 18),
                            ),
                            onSubmit: (_) => _confirmFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),

                          _buildLabel('Confirm Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _confirmCtrl,
                            focusNode: _confirmFocus,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConf,
                            error: _confirmError,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscureConf = !_obscureConf),
                              child: Icon(_obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _muted, size: 18),
                            ),
                            onSubmit: (_) => _submit(),
                          ),
                          const SizedBox(height: 32),
                          _buildPrimaryButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(color: _text, fontSize: 13,
          fontWeight: FontWeight.bold, letterSpacing: 0.2));

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? error,
    Widget? suffixIcon,
    Function(String)? onSubmit,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: focused ? Colors.white : const Color(0xFFF7F3F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: error != null
                        ? _red
                        : (focused ? _maroon.withOpacity(0.5) : _border),
                    width: focused ? 1.5 : 1.0),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                obscureText: obscure,
                onSubmitted: onSubmit,
                style: const TextStyle(color: _text, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: _muted.withOpacity(0.55), fontSize: 14),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(icon, size: 18, color: focused ? _maroon : _muted.withOpacity(0.65)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffixIcon) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(error, style: const TextStyle(color: _red, fontSize: 11.5, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_maroon, _maroonL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: _maroon.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Create Account',
                            style: TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
