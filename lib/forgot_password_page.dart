import 'package:flutter/material.dart';
import 'db/local_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FORGOT PASSWORD PAGE  —  Screen 20
//  Local app: resets password to default and shows success UI
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _newPassCtrl = TextEditingController();
  
  final _emailFocus   = FocusNode();
  final _otpFocus     = FocusNode();
  final _newPassFocus = FocusNode();

  bool _loading   = false;
  bool _otpSent   = false;
  bool _completed = false;

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonL = Color(0xFF9E2D4F);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

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
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _newPassFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _error('Please enter a valid registered email.'); return;
    }
    
    setState(() => _loading = true);
    final success = await LocalDb.instance.requestPasswordReset(email);
    
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        setState(() => _otpSent = true);
        _success('Verification code sent to your Gmail!');
      } else {
        _error('Failed to send code. Account may not exist or server error.');
      }
    }
  }

  Future<void> _confirmReset() async {
    final email = _emailCtrl.text.trim();
    final otp   = _otpCtrl.text.trim();
    final pass  = _newPassCtrl.text.trim();

    if (otp.length != 6) { _error('Enter the 6-digit code sent to Gmail.'); return; }
    if (pass.length < 6) { _error('New password must be at least 6 characters.'); return; }

    setState(() => _loading = true);
    final success = await LocalDb.instance.confirmPasswordReset(email, otp, pass);
    
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        setState(() => _completed = true);
      } else {
        _error('Invalid or expired code. Please try again.');
      }
    }
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: _maroon,
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
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _completed 
                    ? _buildSuccess() 
                    : (_otpSent ? _buildOtpForm() : _buildEmailForm()),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 32),
      decoration: const BoxDecoration(
        color: _maroon,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
          const Text('Reset Password',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 20),
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: _gold.withOpacity(0.5), width: 1.5),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Forgot your password?',
            style: TextStyle(color: Colors.white, fontSize: 19,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text("We'll send a verification code to your Gmail.\nUse it to set a new password safely.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.60),
                fontSize: 12, height: 1.5)),
      ]),
    );
  }

  Widget _buildEmailForm() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _maroon.withOpacity(0.07),
            blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Registered Email',
            style: TextStyle(color: _text, fontSize: 12.5,
                fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 10),

        _buildTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          hint: 'doctor@saveetha.ac.in',
          icon: Icons.mail_outline_rounded,
          onSubmit: (_) => _requestOtp(),
        ),

        const SizedBox(height: 24),

        _buildActionButton(
          label: 'Send Verification Code',
          icon: Icons.send_rounded,
          onTap: _requestOtp,
        ),
      ]),
    );
  }

  Widget _buildOtpForm() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _maroon.withOpacity(0.07),
            blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text('Code sent to ${_emailCtrl.text}',
              style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 20),
        
        const Text('Verification Code',
            style: TextStyle(color: _text, fontSize: 12.5,
                fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _otpCtrl,
          focusNode: _otpFocus,
          hint: '6-digit code',
          icon: Icons.vpn_key_outlined,
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 18),
        const Text('New Password',
            style: TextStyle(color: _text, fontSize: 12.5,
                fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _newPassCtrl,
          focusNode: _newPassFocus,
          hint: 'Min 6 characters',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          onSubmit: (_) => _confirmReset(),
        ),

        const SizedBox(height: 24),

        _buildActionButton(
          label: 'Update Password',
          icon: Icons.verified_user_outlined,
          onTap: _confirmReset,
        ),
        
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _otpSent = false),
            child: const Text('Change Email', style: TextStyle(color: _muted, fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onSubmit,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (_, __) {
        final f = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: f ? Colors.white : const Color(0xFFF7F3F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: f ? _maroon.withOpacity(0.5) : _border,
                width: f ? 1.5 : 1),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword,
            keyboardType: keyboardType,
            onSubmitted: onSubmit,
            style: const TextStyle(color: _text, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _muted.withOpacity(0.55), fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, size: 18,
                    color: f ? _maroon : _muted.withOpacity(0.65)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_maroon, _maroonL]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _maroon.withOpacity(0.30),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(label,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8F5E9)),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.08),
            blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Container(
          width: 90, height: 90,
          decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Color(0xFF2E7D32), size: 44),
        ),
        const SizedBox(height: 24),
        const Text('Password Updated!',
            style: TextStyle(color: Color(0xFF1B5E20), fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(
          'Your password for\n${_emailCtrl.text.trim()}\nhas been successfully updated.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9E8A8F), fontSize: 14,
              height: 1.6),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 50,
          child: Material(
            color: _maroon,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              borderRadius: BorderRadius.circular(14),
              child: const Center(
                child: Text('Back to Login',
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
