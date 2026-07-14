import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';

class WebForgotPasswordPage extends StatefulWidget {
  const WebForgotPasswordPage({super.key});

  @override
  State<WebForgotPasswordPage> createState() => _WebForgotPasswordPageState();
}

class _WebForgotPasswordPageState extends State<WebForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl   = TextEditingController();
  final _newPassCtrl = TextEditingController();
  
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  final _emailFocus   = FocusNode();
  final _newPassFocus = FocusNode();

  bool _loading   = false;
  bool _otpSent   = false;
  bool _completed = false;
  bool _obscurePass = true;
  
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minutes expiry timer

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonL = Color(0xFF9E2D4F);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  late AnimationController _animCtrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this)
      ..forward();
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _emailFocus.dispose();
    _newPassFocus.dispose();
    _animCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 300;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _countdownTimer?.cancel();
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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
      _newPassCtrl.text = suggestion;
    });
    _success('Suggested secure password generated!');
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

  String get _otpCode => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w\.\-]+@gmail\.com$').hasMatch(email.toLowerCase())) {
      _error('Only @gmail.com email addresses are allowed.'); return;
    }
    
    setState(() => _loading = true);
    final result = await LocalDb.instance.requestPasswordReset(email);
    
    if (mounted) {
      setState(() => _loading = false);
      if (result['success'] == true) {
        setState(() => _otpSent = true);
        _startCountdown();
        _success('Verification code sent to your Gmail!');
      } else {
        _error(result['message'] as String? ?? 'Failed to send code.');
      }
    }
  }

  Future<void> _confirmReset() async {
    final email = _emailCtrl.text.trim();
    final otp   = _otpCode;
    final pass  = _newPassCtrl.text.trim();

    if (otp.length != 6) { _error('Enter the 6-digit code sent to Gmail.'); return; }
    if (_secondsRemaining <= 0) { _error('Code has expired. Please request a new one.'); return; }
    if (pass.length < 6) { _error('New password must be at least 6 characters.'); return; }
    if (pass.contains(' ')) { _error('Password cannot contain spaces.'); return; }
    if (!pass.contains(RegExp(r'[A-Za-z]')) || !pass.contains(RegExp(r'[0-9]')) || !pass.contains(RegExp(r'[^A-Za-z0-9]'))) {
      _error('Password must contain letters, numbers, and a special character.'); return;
    }

    final reused = await _isPasswordReused(email, pass);
    if (reused) {
      _error('Security Alert: Cannot reuse any of your last 3 passwords.');
      return;
    }

    setState(() => _loading = true);
    final success = await LocalDb.instance.confirmPasswordReset(email, otp, pass);
    
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        _countdownTimer?.cancel();
        await _savePasswordToHistory(email, pass);
        setState(() => _completed = true);
      } else {
        _error('Invalid code or expired request. Please try again.');
      }
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
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
                              'Reset Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w200,
                                letterSpacing: 6.0,
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 1.5,
                              color: _gold.withOpacity(0.8),
                              margin: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            const Text(
                              'Verification via Secure OTP Routing',
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
                      constraints: const BoxConstraints(maxWidth: 480),
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
                      child: _completed ? _buildCompletedUI() : (_otpSent ? _buildOtpUI() : _buildEmailUI()),
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

  Widget _buildEmailUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Forgot Password', style: TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Please enter your clinician Gmail to receive an OTP.', style: TextStyle(color: _muted, fontSize: 13.5)),
        const SizedBox(height: 32),
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          hint: 'clinician@gmail.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          onSubmit: (_) => _requestOtp(),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(label: 'Send Verification Code', action: _requestOtp),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Back to Login', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter Verification Code', style: TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('We sent a 6-digit code to ${_emailCtrl.text}.', style: const TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.timer_outlined, color: _gold, size: 14),
            const SizedBox(width: 6),
            Text('Expires in ${_formatTime(_secondsRemaining)}', style: const TextStyle(color: _gold, fontSize: 12.5, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 32),
        _buildLabel('6-Digit Code'),
        const SizedBox(height: 8),
        _buildOtpFields(),
        const SizedBox(height: 24),
        _buildLabel('New Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _newPassCtrl,
          focusNode: _newPassFocus,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePass = !_obscurePass),
            child: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _muted, size: 18),
          ),
          onSubmit: (_) => _confirmReset(),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _suggestPassphrase,
            icon: const Icon(Icons.psychology_alt_outlined, size: 16, color: _maroon),
            label: const Text('Suggest Secure Password', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(label: 'Reset Password', action: _confirmReset),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _otpSent = false;
                _countdownTimer?.cancel();
              });
            },
            child: const Text('Request New Code', style: TextStyle(color: _muted, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        const Text('Password Reset Successful', style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Your password has been successfully updated.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13.5)),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Continue to Login',
          action: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ],
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 52,
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _text),
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              fillColor: const Color(0xFFF7F3F0),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _maroon)),
            ),
            onChanged: (val) {
              if (val.isNotEmpty && index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              }
              if (val.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
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

  Widget _buildPrimaryButton({required String label, required VoidCallback action}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : action,
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
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label,
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
