import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'db/local_db.dart';
import 'db/session.dart';

// Profile Page — Screens 49 / 50

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _maroonL = Color(0xFF9E2D4F);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  // Password change state
  final _oldPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _changingPw    = false;
  bool _pwSuccess     = false;
  bool _showPwForm    = false;
  bool _obscureOld    = true;
  bool _obscureNew    = true;
  bool _obscureConf   = true;

  int _totalCases = 0;
  int _highRisk   = 0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _oldPassCtrl.dispose(); _newPassCtrl.dispose(); _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final raw = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // Deduplicate: Keep only the latest assessment for each patient
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in raw) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    
    final uniqueCases = uniqueMap.values.toList();
    final high = uniqueCases.where((c) =>
        (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH')).length;
    
    if (mounted) {
      setState(() { 
        _totalCases = uniqueCases.length; 
        _highRisk = high; 
      });
    }
  }

  Future<void> _changePassword() async {
    final old  = _oldPassCtrl.text.trim();
    final next = _newPassCtrl.text.trim();
    final conf = _confPassCtrl.text.trim();

    if (old.isEmpty || next.isEmpty || conf.isEmpty) {
      _snack('Please fill all fields.'); return;
    }
    if (next.length < 6) { _snack('New password must be at least 6 characters.'); return; }
    if (next != conf)    { _snack('Passwords do not match.'); return; }

    setState(() => _changingPw = true);
    final ok = await LocalDb.instance.changePassword(
        Session.instance.email!, old, next);
    if (mounted) {
      setState(() { _changingPw = false; });
      if (ok) {
        setState(() { _pwSuccess = true; _showPwForm = false; });
        _oldPassCtrl.clear(); _newPassCtrl.clear(); _confPassCtrl.clear();
      } else {
        _snack('Current password is incorrect.');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: _maroon,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      final ok = await LocalDb.instance.updateProfilePhoto(pickedFile.path);
      if (ok && mounted) {
        setState(() {});
        _snack('Profile picture updated!');
      } else {
        _snack('Failed to save profile picture.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, 
            expandedHeight: 220,
            backgroundColor: _maroon,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_maroonD, _maroon],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _surface,
                        border: Border.all(color: _gold, width: 2.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                            blurRadius: 20, offset: const Offset(0, 8))],
                        image: Session.instance.photoPath != null &&
                                Session.instance.photoPath!.isNotEmpty &&
                                !kIsWeb &&
                                File(Session.instance.photoPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(Session.instance.photoPath!)),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: Session.instance.photoPath == null ||
                              Session.instance.photoPath!.isEmpty ||
                              kIsWeb ||
                              !File(Session.instance.photoPath!).existsSync()
                          ? Center(
                              child: Text(Session.instance.initial,
                                  style: const TextStyle(
                                      color: _maroon,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800)))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text("DR. ${Session.instance.displayName.toUpperCase()}",
                      style: const TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withOpacity(0.5)),
                    ),
                    child: const Text("SENIOR CLINICIAN",
                        style: TextStyle(color: _gold, fontSize: 9,
                            fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ),
                ])),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _infoCard(),
              const SizedBox(height: 20),
              _statsCard(),
              const SizedBox(height: 20),
              _pwSection(),
              const SizedBox(height: 20),
              if (_pwSuccess) _pwSuccessBanner(),
              const SizedBox(height: 24),
              _signOutButton(context),
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("PROFESSIONAL INFO",
          style: TextStyle(color: _muted, fontSize: 9,
              fontWeight: FontWeight.w800, letterSpacing: 2.0)),
      const SizedBox(height: 16),
      _infoRow(Icons.email_outlined, "Email Address", Session.instance.email ?? "N/A"),
      const Divider(height: 24),
      _infoRow(Icons.work_outline_rounded, "Department", "Oral Medicine & Radiology"),
      const Divider(height: 24),
      _infoRow(Icons.location_on_outlined, "Institution", "Saveetha Dental College"),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: _maroon, size: 20),
    const SizedBox(width: 14),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  ]);

  Widget _statsCard() => _card(
    child: Row(children: [
      _stat(_totalCases.toString(), 'Cases'),
      _divider(),
      _stat(_highRisk.toString(), 'High Risk'),
      _divider(),
      _stat((_totalCases - _highRisk).toString(), 'Other'),
    ]),
  );

  Widget _stat(String v, String l) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(color: _maroon, fontSize: 24,
        fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(l, style: const TextStyle(color: _muted, fontSize: 11,
        fontWeight: FontWeight.w500)),
  ]));

  Widget _divider() => Container(
      width: 1, height: 40, color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _pwSection() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Row(children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: _maroon),
          SizedBox(width: 10),
          Text('Change Password',
              style: TextStyle(color: _text, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
        GestureDetector(
          onTap: () => setState(() => _showPwForm = !_showPwForm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _maroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_showPwForm ? 'Cancel' : 'Change',
                style: const TextStyle(color: _maroon, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
      if (_showPwForm) ...[
        const SizedBox(height: 16),
        _pwField('Current Password', _oldPassCtrl, _obscureOld,
            () => setState(() => _obscureOld = !_obscureOld)),
        const SizedBox(height: 12),
        _pwField('New Password', _newPassCtrl, _obscureNew,
            () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 12),
        _pwField('Confirm New Password', _confPassCtrl, _obscureConf,
            () => setState(() => _obscureConf = !_obscureConf)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: Material(
            color: _maroon,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _changingPw ? null : _changePassword,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: _changingPw
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Update Password',
                        style: TextStyle(color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    ]));
  }

  Widget _pwField(String label, TextEditingController ctrl, bool obscure,
      VoidCallback toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 11.5,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: _text, fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _muted, size: 18),
              onPressed: toggle,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _pwSuccessBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
    ),
    child: const Row(children: [
      Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
      SizedBox(width: 10),
      Expanded(child: Text('Password updated successfully!',
          style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600,
              fontSize: 13))),
    ]),
  );

  Widget _signOutButton(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: OutlinedButton.icon(
      onPressed: () {
        Session.instance.clear();
        Navigator.pushReplacementNamed(context, '/login');
      },
      icon: const Icon(Icons.logout_rounded, color: _maroon, size: 18),
      label: const Text('Sign Out',
          style: TextStyle(color: _maroon, fontSize: 15,
              fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _maroon, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}
