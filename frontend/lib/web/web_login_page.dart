import 'package:flutter/material.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage>
    with SingleTickerProviderStateMixin {

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  final _nameFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading   = false;
  bool _isLogin     = true;
  bool _obscurePass = true;
  bool _obscureConf = true;

  late AnimationController _revealController;
  late Animation<double>   _fadeAnim;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFFFAF7F4);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _maroon   = Color(0xFF7B1E3A);
  static const Color _maroonLt = Color(0xFF9E2D4F);
  static const Color _gold     = Color(0xFFC9A84C);
  static const Color _muted    = Color(0xFF9E8A8F);
  static const Color _border   = Color(0xFFE8DDD8);
  static const Color _text     = Color(0xFF1E0A10);

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _revealController, curve: Curves.easeOut));
    _revealController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (!_isLogin) {
      if (name.isEmpty) {
        _showError('Please enter your full name.'); return;
      }
      if (name.length < 2) {
        _showError('Name must be at least 2 characters.'); return;
      }
    }
    if (email.isEmpty) {
      _showError('Please enter your email.'); return;
    }
    if (!RegExp(r'^[\w\.\-]+@gmail\.com$').hasMatch(email.toLowerCase())) {
      _showError('Only @gmail.com email addresses are allowed.'); return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.'); return;
    }
    if (!_isLogin) {
      if (password.length < 6) {
        _showError('Password must be at least 6 characters.'); return;
      }
      if (password.contains(' ')) {
        _showError('Password cannot contain spaces.'); return;
      }
      if (!password.contains(RegExp(r'[A-Za-z]')) || !password.contains(RegExp(r'[0-9]')) || !password.contains(RegExp(r'[^A-Za-z0-9]'))) {
        _showError('Password must contain letters, numbers, and a special character.'); return;
      }
      if (password != confirm) {
        _showError('Passwords do not match. Please re-enter.'); return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        final clinician = await LocalDb.instance.signIn(email, password);
        Session.instance.set(clinician!);
      } else {
        final clinician = await LocalDb.instance.signUp(name, email, password);
        if (clinician == null) {
          _showError('An account already exists for that email or there was a server error.');
          return;
        }
        Session.instance.set(clinician);
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');

    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: _maroon,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Row(
          children: [
            // Left Panel - branding
            Expanded(
              flex: 12,
              child: Container(
                color: _maroon,
                child: Stack(
                  children: [
                    // Decorative grids
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
                              child: const Icon(Icons.local_hospital_rounded,
                                  color: Colors.white, size: 60),
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
                            const SizedBox(height: 10),
                            Text(
                              'CLINICAL DECISION SUPPORT PORTAL',
                              style: TextStyle(
                                color: _gold.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4.0,
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
            // Right Panel - login form
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isLogin ? 'Welcome Back' : 'Create Account',
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isLogin ? 'Sign in to clinical dashboard' : 'Register as a clinician',
                                    style: const TextStyle(color: _muted, fontSize: 13),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  _nameController.clear();
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _confirmController.clear();
                                  setState(() => _isLogin = !_isLogin);
                                },
                                child: Text(
                                  _isLogin ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(color: _maroon, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          if (!_isLogin) ...[
                            _buildLabel('Full Name'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              hint: 'Dr. John Smith',
                              icon: Icons.person_outline_rounded,
                              textCapitalization: TextCapitalization.words,
                              onSubmit: (_) => _emailFocus.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            hint: 'clinician@gmail.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            onSubmit: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),
                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passFocus,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePass,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePass = !_obscurePass),
                              child: Icon(_obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                                  color: _muted, size: 18),
                            ),
                            onSubmit: (_) => _isLogin ? _submitAuth() : _confirmFocus.requestFocus(),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 20),
                            _buildLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConf,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() => _obscureConf = !_obscureConf),
                                child: Icon(_obscureConf
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                    color: _muted, size: 18),
                              ),
                              onSubmit: (_) => _submitAuth(),
                            ),
                          ],
                          const SizedBox(height: 32),
                          _buildPrimaryButton(),
                          if (_isLogin) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/forgot_password'),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: _maroon.withOpacity(0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffixIcon,
    Function(String)? onSubmit,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: focused ? Colors.white : const Color(0xFFF7F3F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: focused ? _maroon.withOpacity(0.5) : _border,
                width: focused ? 1.5 : 1.0),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
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
          onTap: _isLoading ? null : _submitAuth,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_maroon, _maroonLt],
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
