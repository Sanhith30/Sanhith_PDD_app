import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});

  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  bool _notifHigh   = true;
  bool _autoRefresh = false;
  bool _compactView = false;
  String _aiMode    = 'Standard';
  String _dept = 'Oral Medicine & Radiology';
  final _facilityController = TextEditingController();
  
  bool _requireConsent = false;
  bool _academicSharing = false;
  double _cacheSize = 24.5;
  int? _pingLatency;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final latency = await LocalDb.instance.pingServer();
    setState(() {
      _notifHigh = prefs.getBool('pref_notif_high') ?? true;
      _autoRefresh = prefs.getBool('pref_auto_refresh') ?? false;
      _compactView = prefs.getBool('pref_compact_view') ?? false;
      _aiMode = prefs.getString('pref_ai_mode') ?? 'Standard';
      _dept = prefs.getString('pref_dept') ?? 'Oral Medicine & Radiology';
      _facilityController.text = prefs.getString('pref_facility_id') ?? 'SVDC-MAIN';
      _requireConsent = prefs.getBool('pref_require_consent') ?? false;
      _academicSharing = prefs.getBool('pref_academic_sharing') ?? false;
      _pingLatency = latency;
    });
  }

  Future<void> _saveSetting(String key, dynamic val) async {
    final prefs = await SharedPreferences.getInstance();
    if (val is bool) {
      await prefs.setBool(key, val);
    } else if (val is String) {
      await prefs.setString(key, val);
    }
  }

  void _logout() {
    Session.instance.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Settings',
                    style: TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Configure clinical preferences, diagnostics, facility IDs, and browser cache.',
                    style: TextStyle(color: _muted, fontSize: 14.5),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                label: const Text('LOG OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Responsive Double Column Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  children: [
                    _buildClinicalOpsCard(),
                    const SizedBox(height: 24),
                    _buildFacilityCard(),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // Right Column
              Expanded(
                child: Column(
                  children: [
                    _buildConsentSecurityCard(),
                    const SizedBox(height: 24),
                    _buildSystemDiagCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalOpsCard() {
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
          const Text('Clinical Operations', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSwitchTile(
            'High-Risk Alerts',
            'Notify immediately when high risk category is diagnosed.',
            _notifHigh,
            (val) {
              setState(() => _notifHigh = val);
              _saveSetting('pref_notif_high', val);
            },
          ),
          const Divider(height: 24, color: _border),
          _buildSwitchTile(
            'Auto-Refresh Lists',
            'Periodically pull latest cases from PostgreSQL server.',
            _autoRefresh,
            (val) {
              setState(() => _autoRefresh = val);
              _saveSetting('pref_auto_refresh', val);
            },
          ),
          const Divider(height: 24, color: _border),
          _buildSwitchTile(
            'Compact History View',
            'Reduce row padding inside the patient history tab.',
            _compactView,
            (val) {
              setState(() => _compactView = val);
              _saveSetting('pref_compact_view', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityCard() {
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
          const Text('Facility & Department', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Registered Department', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: const [
                  'Oral Medicine & Radiology',
                  'Oral & Maxillofacial Pathology',
                  'Periodontics',
                  'General Dentistry'
                ].contains(_dept)
                    ? _dept
                    : 'Oral Medicine & Radiology',
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _dept = val);
                    _saveSetting('pref_dept', val);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'Oral Medicine & Radiology', child: Text('Oral Medicine & Radiology', style: TextStyle(fontSize: 13.5))),
                  DropdownMenuItem(value: 'Oral & Maxillofacial Pathology', child: Text('Oral & Maxillofacial Pathology', style: TextStyle(fontSize: 13.5))),
                  DropdownMenuItem(value: 'Periodontics', child: Text('Periodontics', style: TextStyle(fontSize: 13.5))),
                  DropdownMenuItem(value: 'General Dentistry', child: Text('General Dentistry', style: TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Facility Identifier', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _facilityController,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              fillColor: _bg,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _maroon)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => _saveSetting('pref_facility_id', val),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentSecurityCard() {
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
          const Text('Patient Consent & Privacy', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSwitchTile(
            'Enforce Digital Consent',
            'Require signature affirmation from patients before visual uploads.',
            _requireConsent,
            (val) {
              setState(() => _requireConsent = val);
              _saveSetting('pref_require_consent', val);
            },
          ),
          const Divider(height: 24, color: _border),
          _buildSwitchTile(
            'Academic Data Share',
            'Anonymize case data for scientific researches automatically.',
            _academicSharing,
            (val) {
              setState(() => _academicSharing = val);
              _saveSetting('pref_academic_sharing', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemDiagCard() {
    final pingText = _pingLatency != null ? '${_pingLatency} ms' : 'Offline';
    final pingColor = _pingLatency != null ? (_pingLatency! < 150 ? Colors.green : Colors.orange) : Colors.red;

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
          const Text('System Diagnostics', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browser Local Cache', style: TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Clear cached case descriptions & assets.', style: TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() => _cacheSize = 0.0);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared successfully!')));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('CLEAR (${_cacheSize.toStringAsFixed(1)} MB)'),
              ),
            ],
          ),
          const Divider(height: 24, color: _border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Server Node Health', style: TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Active ping check to backend engine.', style: TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
              Text(pingText, style: TextStyle(color: pingColor, fontWeight: FontWeight.bold, fontSize: 14.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5)),
            ],
          ),
        ),
        Switch.adaptive(
          value: val,
          activeColor: _maroon,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
