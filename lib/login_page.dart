import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LOGIN PAGE  —  "Surgical Luxury"
//  Auth: Local SQLite — no Firebase, no Google/Apple
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
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
  late Animation<Offset>   _slideAnim;

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
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero).animate(
        CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic));
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

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTH LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _submitAuth() async {
    if (!_isLogin) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your full name.'); return;
      }
      if (_nameController.text.trim().length < 2) {
        _showError('Name must be at least 2 characters.'); return;
      }
    }
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Please enter both your email and password.'); return;
    }
    if (!_isLogin) {
      if (_passwordController.text.trim().length < 6) {
        _showError('Password must be at least 6 characters.'); return;
      }
      if (_passwordController.text.trim() !=
          _confirmController.text.trim()) {
        _showError('Passwords do not match. Please re-enter.'); return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // ── Sign In ────────────────────────────────────────────────────────
        final clinician = await LocalDb.instance.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (clinician == null) {
          _showError('Incorrect email or password. Please check and try again.');
          return;
        }
        Session.instance.set(clinician);
      } else {
        // ── Sign Up ────────────────────────────────────────────────────────
        final clinician = await LocalDb.instance.signUp(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (clinician == null) {
          _showError('An account already exists for that email or there was a server error.');
          return;
        }
        Session.instance.set(clinician);
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');

    } catch (e) {
      _showError('An error occurred. Please try again.');
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

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildCard(),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Maroon curved header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 44, 32, 36),
      decoration: const BoxDecoration(
        color: _maroon,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: _gold.withOpacity(0.55), width: 1.5),
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: Colors.white, size: 38),
        ),
        const SizedBox(height: 18),
        const Text('Oral Ulcer AI',
            style: TextStyle(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w300, letterSpacing: 4.0)),
        Container(width: 26, height: 1,
            color: _gold.withOpacity(0.7),
            margin: const EdgeInsets.symmetric(vertical: 10)),
        Text('Saveetha Dental College & Hospital',
            style: TextStyle(color: Colors.white.withOpacity(0.60),
                fontSize: 11.5, letterSpacing: 1.3)),
      ]),
    );
  }

  // ── Main white card ───────────────────────────────────────────────────────
  Widget _buildCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(color: _maroon.withOpacity(0.07),
                blurRadius: 32, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title row + toggle pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isLogin ? 'Welcome back' : 'Create account',
                          style: const TextStyle(color: _text, fontSize: 21,
                              fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                      const SizedBox(height: 4),
                      Text(_isLogin
                          ? 'Sign in to your clinician account'
                          : 'Register as a clinician',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      _nameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmController.clear();
                      setState(() => _isLogin = !_isLogin);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _maroon.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _maroon.withOpacity(0.18), width: 1),
                      ),
                      child: Text(_isLogin ? 'Sign up' : 'Sign in',
                          style: const TextStyle(color: _maroon, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // Full Name (sign-up only)
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
                const SizedBox(height: 16),
              ],

              // Email
              _buildLabel('Email Address'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'clinician@saveetha.ac.in',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                onSubmit: (_) => _passFocus.requestFocus(),
              ),

              const SizedBox(height: 16),

              // Password
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
                onSubmit: (_) => _isLogin
                    ? _submitAuth()
                    : _confirmFocus.requestFocus(),
              ),

              // Confirm Password (sign-up only)
              if (!_isLogin) ...[
                const SizedBox(height: 16),
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

              const SizedBox(height: 26),
              _buildPrimaryButton(),

              // Forgot password (sign-in mode only)
              if (_isLogin) ...[  
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/forgot_password'),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: _maroon.withOpacity(0.7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: _maroon.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(color: _text, fontSize: 12.5,
          fontWeight: FontWeight.w600, letterSpacing: 0.4));

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
            boxShadow: focused
                ? [BoxShadow(color: _maroon.withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0, 3))]
                : [],
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
              hintStyle:
                  TextStyle(color: _muted.withOpacity(0.55), fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, size: 18,
                    color: focused ? _maroon : _muted.withOpacity(0.65)),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: suffixIcon)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
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
                BoxShadow(color: _maroon.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.0))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 18, height: 0.6,
            color: _gold.withOpacity(0.4)),
        const SizedBox(width: 10),
        Text('CLINICAL DECISION SUPPORT',
            style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 9,
                fontWeight: FontWeight.w600, letterSpacing: 3.0)),
        const SizedBox(width: 10),
        Container(width: 18, height: 0.6,
            color: _gold.withOpacity(0.4)),
      ]),
      const SizedBox(height: 8),
      Text(
        'v2.0  •  Saveetha Institute of Medical & Technical Sciences',
        style: TextStyle(color: _muted.withOpacity(0.45),
            fontSize: 10, letterSpacing: 0.3),
      ),
    ]);
  }
}