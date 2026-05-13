import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SIGN UP PAGE  —  Screen 3
//  Separate from Login. Inline validation errors (Screen 19).
//  "Surgical Luxury" design system
// ─────────────────────────────────────────────────────────────────────────────

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
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

  // Inline validation errors — Screen 19
  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonL = Color(0xFF9E2D4F);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);
  static const Color _redBg   = Color(0xFFFFEBEE);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 850), vsync: this)..forward();
    _fade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
    } else if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$').hasMatch(e)) {
      ee = 'Enter a valid email address';
    }

    if (p.isEmpty)         pe = 'Password is required';
    else if (p.length < 6) pe = 'Password must be at least 6 characters';

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
          _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text.trim());
      if (clinician == null) {
        setState(() => _emailError =
            'An account already exists for this email or there was a server error.');
        return;
      }
      Session.instance.set(clinician);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (_) {
      setState(() => _emailError = 'An unexpected error occurred. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(children: [
                _header(),
                _card(),
                const SizedBox(height: 24),
                _signInLink(),
                const SizedBox(height: 28),
                _footer(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(32, 44, 32, 32),
    decoration: const BoxDecoration(
      color: _maroon,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
    ),
    child: Column(children: [
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.10),
          border: Border.all(color: _gold.withOpacity(0.55), width: 1.5),
        ),
        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 16),
      const Text('Create Account',
          style: TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w300, letterSpacing: 3.5)),
      Container(width: 26, height: 1, color: _gold.withOpacity(0.7),
          margin: const EdgeInsets.symmetric(vertical: 10)),
      Text('Saveetha Dental College & Hospital',
          style: TextStyle(color: Colors.white.withOpacity(0.60),
              fontSize: 11.5, letterSpacing: 1.3)),
    ]),
  );

  Widget _card() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _maroon.withOpacity(0.07),
            blurRadius: 32, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Clinician Registration',
            style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Fill in your details to get started',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 24),
        _lbl('Full Name'),
        const SizedBox(height: 8),
        _fld(ctrl: _nameCtrl, focus: _nameFocus, hint: 'Dr. John Smith',
            icon: Icons.person_outline_rounded, error: _nameError,
            textCap: TextCapitalization.words,
            onSubmit: (_) => _emailFocus.requestFocus()),
        const SizedBox(height: 16),
        _lbl('Email Address'),
        const SizedBox(height: 8),
        _fld(ctrl: _emailCtrl, focus: _emailFocus,
            hint: 'clinician@saveetha.ac.in',
            icon: Icons.mail_outline_rounded, error: _emailError,
            keyboard: TextInputType.emailAddress,
            onSubmit: (_) => _passFocus.requestFocus()),
        const SizedBox(height: 16),
        _lbl('Password'),
        const SizedBox(height: 8),
        _fld(ctrl: _passCtrl, focus: _passFocus, hint: '••••••••',
            icon: Icons.lock_outline_rounded, error: _passError,
            obscure: _obscurePass,
            suffix: _eye(_obscurePass,
                () => setState(() => _obscurePass = !_obscurePass)),
            onSubmit: (_) => _confirmFocus.requestFocus()),
        const SizedBox(height: 16),
        _lbl('Confirm Password'),
        const SizedBox(height: 8),
        _fld(ctrl: _confirmCtrl, focus: _confirmFocus, hint: '••••••••',
            icon: Icons.lock_reset_rounded, error: _confirmError,
            obscure: _obscureConf,
            suffix: _eye(_obscureConf,
                () => setState(() => _obscureConf = !_obscureConf)),
            onSubmit: (_) => _submit()),
        const SizedBox(height: 28),
        _submitBtn(),
      ]),
    ),
  );

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(color: _text, fontSize: 12.5,
          fontWeight: FontWeight.w600, letterSpacing: 0.4));

  Widget _fld({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String hint,
    required IconData icon,
    String? error,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization textCap = TextCapitalization.none,
    Function(String)? onSubmit,
  }) {
    final hasErr = error != null && error.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedBuilder(
        animation: focus,
        builder: (_, __) {
          final focused = focus.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: hasErr ? _redBg
                  : focused ? Colors.white : const Color(0xFFF7F3F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasErr ? _red.withOpacity(0.6)
                    : focused ? _maroon.withOpacity(0.5) : _border,
                width: (hasErr || focused) ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              controller: ctrl, focusNode: focus,
              keyboardType: keyboard, textCapitalization: textCap,
              obscureText: obscure, onSubmitted: onSubmit,
              onChanged: (_) => setState(() {
                if (ctrl == _nameCtrl)    _nameError    = null;
                if (ctrl == _emailCtrl)   _emailError   = null;
                if (ctrl == _passCtrl)    _passError    = null;
                if (ctrl == _confirmCtrl) _confirmError = null;
              }),
              style: TextStyle(color: hasErr ? _red : _text, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: _muted.withOpacity(0.55)),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(icon, size: 18,
                      color: hasErr ? _red.withOpacity(0.7)
                          : focused ? _maroon : _muted.withOpacity(0.65)),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                suffixIcon: suffix != null
                    ? Padding(padding: const EdgeInsets.only(right: 14),
                        child: suffix)
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
            ),
          );
        },
      ),
      if (hasErr) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.error_outline_rounded, size: 13, color: _red),
          const SizedBox(width: 5),
          Expanded(child: Text(error,
              style: const TextStyle(color: _red, fontSize: 11.5,
                  fontWeight: FontWeight.w500))),
        ]),
      ],
    ]);
  }

  Widget _eye(bool obscure, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Icon(obscure ? Icons.visibility_off_outlined
        : Icons.visibility_outlined, color: _muted, size: 18),
  );

  Widget _submitBtn() => SizedBox(
    width: double.infinity, height: 52,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _submit,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_maroon, _maroonL],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _maroon.withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Create Account',
                          style: TextStyle(color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ]),
          ),
        ),
      ),
    ),
  );

  Widget _signInLink() => Row(mainAxisAlignment: MainAxisAlignment.center,
      children: [
    Text('Already have an account? ',
        style: TextStyle(color: _muted, fontSize: 13)),
    GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
      child: const Text('Sign In',
          style: TextStyle(color: _maroon, fontSize: 13,
              fontWeight: FontWeight.w700)),
    ),
  ]);

  Widget _footer() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 18, height: 0.6, color: _gold.withOpacity(0.4)),
      const SizedBox(width: 10),
      Text('CLINICAL DECISION SUPPORT',
          style: TextStyle(color: _muted.withOpacity(0.5), fontSize: 9,
              fontWeight: FontWeight.w600, letterSpacing: 3.0)),
      const SizedBox(width: 10),
      Container(width: 18, height: 0.6, color: _gold.withOpacity(0.4)),
    ]),
    const SizedBox(height: 8),
    Text('v2.0  •  Saveetha Institute of Medical & Technical Sciences',
        style: TextStyle(color: _muted.withOpacity(0.4),
            fontSize: 10, letterSpacing: 0.3)),
  ]);
}
