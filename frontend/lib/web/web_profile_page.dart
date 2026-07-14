import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  final _oldPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _loading = false;
  int _totalCases = 0;
  int _highRisk = 0;
  String _dept = 'Oral Medicine & Radiology';
  String _facilityId = 'SVDC-MAIN';
  String _licenseNo = 'DCI-98745-A';

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConf = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final raw = await LocalDb.instance.getCases(Session.instance.doctorId);
    
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

    final prefs = await SharedPreferences.getInstance();
    final dept = prefs.getString('pref_dept') ?? 'Oral Medicine & Radiology';
    final facility = prefs.getString('pref_facility_id') ?? 'SVDC-MAIN';
    final license = prefs.getString('pref_license_no') ?? 'DCI-98745-A';

    setState(() {
      _totalCases = uniqueCases.length;
      _highRisk = high;
      _dept = dept;
      _facilityId = facility;
      _licenseNo = license;
    });
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      setState(() => _loading = true);
      try {
        final bytes = await file.readAsBytes();
        final success = await LocalDb.instance.updateProfilePhoto(
          imageBytes: bytes,
          fileName: file.name,
        );
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated successfully!')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confPass = _confPassCtrl.text;

    if (oldPass.isEmpty || newPass.isEmpty || confPass.isEmpty) {
      _error('Please fill in all password fields.');
      return;
    }
    if (newPass.length < 6) {
      _error('New password must be at least 6 characters.');
      return;
    }
    if (newPass.contains(' ')) {
      _error('Password cannot contain spaces.');
      return;
    }
    if (!newPass.contains(RegExp(r'[A-Za-z]')) || !newPass.contains(RegExp(r'[0-9]')) || !newPass.contains(RegExp(r'[^A-Za-z0-9]'))) {
      _error('Password must contain letters, numbers, and a special character.');
      return;
    }
    if (newPass != confPass) {
      _error('New passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await LocalDb.instance.changePassword(
        Session.instance.email ?? '',
        oldPass,
        newPass,
      );

      if (success) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confPassCtrl.clear();
        _success('Password updated successfully!');
      } else {
        _error('Incorrect current password.');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Clinician Profile',
            style: TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage clinician profile photo, medical credentials, and security password.',
            style: TextStyle(color: _muted, fontSize: 14.5),
          ),
          const SizedBox(height: 40),

          // Double column profile panels
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Profile Card & Stats
              Expanded(
                flex: 12,
                child: Column(
                  children: [
                    _buildClinicianCard(),
                    const SizedBox(height: 24),
                    _buildStatsCard(),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // Right Column: Change Password Card
              Expanded(
                flex: 11,
                child: _buildChangePasswordCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicianCard() {
    final String photo = Session.instance.photoPath ?? '';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Profile image
          Stack(
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: _bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withOpacity(0.5), width: 2),
                  image: photo.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(LocalDb.resolveUrl(photo)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photo.isEmpty ? const Icon(Icons.person_rounded, color: _muted, size: 48) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: _maroon, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: _pickProfilePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          // Description details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Session.instance.displayName, style: const TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(Session.instance.email ?? '', style: const TextStyle(color: _muted, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.business_rounded, color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_dept, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Text('Facility ID: $_facilityId', style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Performance statistics', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(_totalCases.toString(), style: const TextStyle(color: _text, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Total Screened', style: TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: _border),
              Expanded(
                child: Column(
                  children: [
                    Text(_highRisk.toString(), style: const TextStyle(color: _red, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('High Risk Alerts', style: TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: _border),
              Expanded(
                child: Column(
                  children: [
                    Text(_licenseNo, style: const TextStyle(color: _maroon, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('License No.', style: TextStyle(color: _muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Update Security Password', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Set a new credentials passphrase.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 28),

          _buildLabel('Current Password'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _oldPassCtrl,
            hint: 'Enter old password',
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
            controller: _newPassCtrl,
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
            controller: _confPassCtrl,
            hint: 'Confirm new password',
            obscure: _obscureConf,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConf = !_obscureConf),
              child: Icon(_obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _muted),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _changePassword,
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
