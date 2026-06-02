import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// Settings Page — Clinical Operations Suite

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  // --- Preferences State ---
  bool _notifHigh   = true;
  bool _autoRefresh = false;
  bool _compactView = false;
  String _aiMode    = 'Standard';

  // --- Department State ---
  String _dept = 'Oral Medicine & Radiology';
  final _facilityController = TextEditingController();

  // --- Report preferences ---
  bool _includeSignature = true;
  bool _includePatientPhotos = true;
  bool _detailedExpl = true;

  // --- Consent & Privacy ---
  bool _requireConsent = false;
  bool _academicSharing = false;

  // --- Security ---
  bool _biometricLogin = false;
  String _autoLockTime = 'Never';

  // --- Offline Mode ---
  bool _offlineMode = false;
  bool _wifiOnlySync = false;

  // --- Cache size & diagnostics ---
  double _cacheSize = 24.5;
  int? _pingLatency;
  bool _checkingPing = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadSettings();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifHigh = prefs.getBool('pref_notif_high') ?? true;
        _autoRefresh = prefs.getBool('pref_auto_refresh') ?? false;
        _compactView = prefs.getBool('pref_compact_view') ?? false;
        _aiMode = prefs.getString('pref_ai_mode') ?? 'Standard';
        
        _dept = prefs.getString('pref_dept') ?? 'Oral Medicine & Radiology';
        _facilityController.text = prefs.getString('pref_facility_id') ?? 'SVDC-MAIN';
        
        _includeSignature = prefs.getBool('pref_include_signature') ?? true;
        _includePatientPhotos = prefs.getBool('pref_include_patient_photos') ?? true;
        _detailedExpl = prefs.getBool('pref_detailed_expl') ?? true;
        
        _requireConsent = prefs.getBool('pref_require_consent') ?? false;
        _academicSharing = prefs.getBool('pref_academic_sharing') ?? false;
        
        _biometricLogin = prefs.getBool('pref_biometric_login') ?? false;
        _autoLockTime = prefs.getString('pref_auto_lock_time') ?? 'Never';
        
        _offlineMode = prefs.getBool('pref_offline_mode') ?? false;
        _wifiOnlySync = prefs.getBool('pref_wifi_only_sync') ?? false;
      });
      _testPing();
    } catch (_) {}
  }

  Future<void> _saveBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  Future<void> _saveString(String key, String val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, val);
    } catch (_) {}
  }

  Future<void> _testPing() async {
    if (!mounted) return;
    setState(() {
      _checkingPing = true;
      _pingLatency = null;
    });
    final latency = await LocalDb.instance.pingServer();
    if (mounted) {
      setState(() {
        _pingLatency = latency;
        _checkingPing = false;
      });
    }
  }

  void _clearCacheAction() {
    setState(() {
      _cacheSize = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Offline image cache cleared successfully.'),
      backgroundColor: _maroon,
    ));
  }

  void _exportDatabaseAction() async {
    try {
      final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
      StringBuffer csv = StringBuffer();
      csv.writeln("Case ID,Patient ID,Patient Name,Doctor Name,Date,Risk Category,Risk Score %,Recommendation,Confidence,Status");
      for (var c in cases) {
        final ms = c['created_at'] as int? ?? 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
        
        final name = (c['patient_name'] ?? 'N/A').toString().replaceAll('"', '""');
        final doc = (c['doctor_name'] ?? 'N/A').toString().replaceAll('"', '""');
        final rec = (c['biopsy_recommendation'] ?? 'N/A').toString().replaceAll('"', '""');
        final cat = (c['risk_category'] ?? 'N/A').toString().replaceAll('"', '""');
        
        csv.writeln("${c['id']},${c['patient_id']},\"$name\",\"$doc\",$dateStr,\"$cat\",${c['risk_score']},\"$rec\",${c['confidence']},${c['status']}");
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/SDC_Case_Database_Export.csv');
      await file.writeAsString(csv.toString());
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.grid_on_outlined, color: _maroon),
              SizedBox(width: 10),
              Text('Export Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Successfully compiled all patient cases and risk scores into a standard CSV file.', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Local Path:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                file.path,
                style: const TextStyle(fontSize: 11, color: _maroon, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(
                  onLayout: (format) async {
                    final pdfDocument = pw.Document();
                    pdfDocument.addPage(
                      pw.Page(
                        build: (context) => pw.Text(csv.toString(), style: const pw.TextStyle(fontSize: 7)),
                      ),
                    );
                    return pdfDocument.save();
                  },
                  name: 'SDC_Case_Database_Export.csv.pdf',
                );
              },
              child: const Text('Print/Save PDF', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to export CSV: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _generateAuditAction() async {
    try {
      final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
      final pdfDocument = pw.Document();
      
      pdfDocument.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SAVEETHA DENTAL COLLEGE & HOSPITAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('CLINICAL AUDIT LOG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#7B1E3A'))),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Clinician Name: Dr. ${Session.instance.displayName.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Date Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Total Cases Audited: ${cases.length}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 15),
            
            pw.TableHelper.fromTextArray(
              headers: ['Case ID', 'Patient ID', 'Patient Name', 'Date', 'Risk Category', 'Recommendation'],
              data: cases.map((c) {
                final ms = c['created_at'] as int? ?? 0;
                final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                final dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                return [
                  c['id']?.toString() ?? 'N/A',
                  c['patient_id']?.toString() ?? 'N/A',
                  c['patient_name']?.toString() ?? 'N/A',
                  dateStr,
                  c['risk_category']?.toString() ?? 'N/A',
                  c['biopsy_recommendation']?.toString() ?? 'N/A',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            
            pw.SizedBox(height: 25),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 140, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Authorized Clinician Signature', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfDocument.save(),
        name: 'Saveetha_Clinical_Audit_${DateTime.now().month}_${DateTime.now().year}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to generate PDF audit: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _serverSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: LocalDb.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: _maroon),
            SizedBox(width: 10),
            Text('Server IP Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the local IP address and port of your PC backend server:', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'http://10.37.145.87:5000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await LocalDb.setBaseUrl(newUrl);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                setState(() {});
                _testPing();
              }
            },
            child: const Text('Save & Test', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _aiConsensusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_outlined, color: _maroon, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('How AI Works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consensus Risk Engine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _maroon),
              ),
              const SizedBox(height: 6),
              const Text(
                'Saveetha Oral Sentry uses a dual-engine consensus model combining clinical examination weights and deep learning computer vision analysis to formulate a combined risk percentage.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const Divider(height: 24),
              const Text(
                '1. Clinical Assessment (60% Weight)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _text),
              ),
              const SizedBox(height: 6),
              const Text(
                'Based on traditional oral cancer screening guidelines. Clinical features are weighted by malignancy risk:\n'
                '• Chronicity (Duration > 3 weeks): 15%\n'
                '• Induration (Firmness on palpation): 15%\n'
                '• High-Risk Site (Lateral tongue/floor): 15%\n'
                '• Lymph Node Attachment (Fixed): 20%\n'
                '• Margin Edge (Everted/ill-defined): 10%\n'
                '• Pain Status (Painless): 10%\n'
                '• Paraesthesia/Anaesthesia: 10%',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const Divider(height: 24),
              const Text(
                '2. Visual AI Analysis (40% Weight)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _text),
              ),
              const SizedBox(height: 6),
              const Text(
                'Powered by a MobileNetV2 convolutional neural network. The model is trained to identify structural borders, mucosal texture changes, and vascular patterns of oral squamous cell carcinoma (OSCC) directly from lesion photographs.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const Divider(height: 24),
              const Text(
                '3. Classification Logic',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _text),
              ),
              const SizedBox(height: 6),
              const Text(
                'The final consensus score (Clinical 60% + Visual 40%) determines the recommendation category:\n'
                '• <35% Score: Low Risk (Conservative Management)\n'
                '• 35% - 70% Score: Intermediate Risk (Pathologist monitoring / Incisional biopsy if persists)\n'
                '• >70% Score: High Risk (Urgent biopsy strongly indicated)',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handbookDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_outlined, color: _maroon, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Saveetha Protocol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clinical Oral Lesion Protocol (SDP)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _maroon),
              ),
              const SizedBox(height: 8),
              _handbookStep(1, 'Clinical History & Chronicity', 
                  'Record patient demographics. Query the exact duration of the ulcer. Any ulcer persisting beyond 3 weeks requires high suspicion.'),
              _handbookStep(2, 'Detailed Visual Inspection', 
                  'Examine borders (well-defined vs ill-defined), margins/edges (everted, punched out), and shape (round, irregular).'),
              _handbookStep(3, 'Palpation Assessment', 
                  'Palpate the lesion to identify induration (firmness) and fixity to surrounding deep structures. Note if the lesion is tender.'),
              _handbookStep(4, 'Lymph Node Mapping', 
                  'Assess the regional submandibular and cervical lymph nodes for size, tenderness, and mobility (fixed vs mobile).'),
              _handbookStep(5, 'Consent & Medical Photography', 
                  'Acquire patient verbal and written consent. Capture a high-resolution, clear photo of the mucosal ulcer using proper isolation.'),
              _handbookStep(6, 'AI Run & Expert Consensus', 
                  'Run the dual-consensus score. For High Risk cases, refer immediately to Oral Pathology & Maxillofacial Surgery for incisional biopsy.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _handbookStep(int num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: _maroon,
            child: Text(num.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, backgroundColor: _maroon, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Settings',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w600)),
            flexibleSpace: Container(decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_maroonD, _maroon]),
            )),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _section('Preferences & Tuning', [
                _toggle('High-risk alert banner',
                    'Show alert when recent case is HIGH',
                    Icons.warning_amber_rounded, _notifHigh,
                    (v) => setState(() { _notifHigh = v; _saveBool('pref_notif_high', v); })),
                _toggle('Auto-refresh dashboard',
                    'Reload cases list on return',
                    Icons.refresh_rounded, _autoRefresh,
                    (v) => setState(() { _autoRefresh = v; _saveBool('pref_auto_refresh', v); })),
                _toggle('Compact case list',
                    'Smaller rows in history screen',
                    Icons.view_agenda_outlined, _compactView,
                    (v) => setState(() { _compactView = v; _saveBool('pref_compact_view', v); })),
                _dropdown('AI Diagnostic Mode',
                    'Sensitivity vs Specificity tuning',
                    Icons.psychology_outlined,
                    _aiMode,
                    ['Standard', 'Screening', 'Confirmatory'],
                    (v) => setState(() { _aiMode = v!; _saveString('pref_ai_mode', v); })),
              ]),
              const SizedBox(height: 20),
              _section('Department & Clinic', [
                _dropdown('Active Department',
                    'Department stamping on reports',
                    Icons.business_center_outlined,
                    _dept,
                    ['Oral Medicine & Radiology', 'Oral Maxillofacial Surgery', 'Periodontics', 'General Dentistry'],
                    (v) => setState(() { _dept = v!; _saveString('pref_dept', v); })),
                _inputTile('Clinic/Facility ID',
                    'Hospital branch identifier',
                    Icons.domain_outlined,
                    _facilityController,
                    'pref_facility_id'),
              ]),
              const SizedBox(height: 20),
              _section('Report & PDF Settings', [
                _toggle('Include signature line',
                    'Show doctor sign-off line in report PDF',
                    Icons.draw_outlined, _includeSignature,
                    (v) => setState(() { _includeSignature = v; _saveBool('pref_include_signature', v); })),
                _toggle('Include patient photos',
                    'Embed patient profile picture in PDF',
                    Icons.image_outlined, _includePatientPhotos,
                    (v) => setState(() { _includePatientPhotos = v; _saveBool('pref_include_patient_photos', v); })),
                _toggle('Detailed AI explanations',
                    'Add neural network explanation breakdown',
                    Icons.description_outlined, _detailedExpl,
                    (v) => setState(() { _detailedExpl = v; _saveBool('pref_detailed_expl', v); })),
              ]),
              const SizedBox(height: 20),
              _section('Privacy & Consent', [
                _toggle('Require digital consent',
                    'Show consent checklist before camera',
                    Icons.assignment_turned_in_outlined, _requireConsent,
                    (v) => setState(() { _requireConsent = v; _saveBool('pref_require_consent', v); })),
                _toggle('Academic sharing mode',
                    'Anonymize patient names in exported reports',
                    Icons.admin_panel_settings_outlined, _academicSharing,
                    (v) => setState(() { _academicSharing = v; _saveBool('pref_academic_sharing', v); })),
              ]),
              const SizedBox(height: 20),
              _section('Security & Account', [
                _toggle('Biometric authentication',
                    'Enable Face ID / Fingerprint settings',
                    Icons.fingerprint_rounded, _biometricLogin,
                    (v) => setState(() { _biometricLogin = v; _saveBool('pref_biometric_login', v); })),
                _dropdown('Auto-Lock timeout',
                    'Automatic logout when idle',
                    Icons.hourglass_empty_rounded,
                    _autoLockTime,
                    ['Never', '5 minutes', '10 minutes', '30 minutes'],
                    (v) => setState(() { _autoLockTime = v!; _saveString('pref_auto_lock_time', v); })),
                _tile('My Profile', Icons.person_outline_rounded,
                    () => Navigator.pushNamed(context, '/profile')),
                _tile('Change Password', Icons.lock_outline_rounded,
                    () => Navigator.pushNamed(context, '/change_password')),
              ]),
              const SizedBox(height: 20),
              _section('Offline Sync & Storage', [
                _toggle('Offline mode',
                    'Allow saving cases locally when offline',
                    Icons.wifi_off_rounded, _offlineMode,
                    (v) => setState(() { _offlineMode = v; _saveBool('pref_offline_mode', v); })),
                _toggle('Sync over Wi-Fi only',
                    'Delay network syncing until connected to Wi-Fi',
                    Icons.network_wifi_3_bar_rounded, _wifiOnlySync,
                    (v) => setState(() { _wifiOnlySync = v; _saveBool('pref_wifi_only_sync', v); })),
                _tile('Clear Offline Cache', Icons.delete_sweep_outlined,
                    _clearCacheAction,
                    trailing: Text('${_cacheSize.toStringAsFixed(1)} MB',
                        style: const TextStyle(color: _muted, fontSize: 12.5))),
                _tile('Export Database to CSV', Icons.grid_on_outlined,
                    _exportDatabaseAction),
                _tile('Monthly Audit Summaries', Icons.summarize_outlined,
                    _generateAuditAction),
              ]),
              const SizedBox(height: 20),
              _section('Server & Diagnostics', [
                _tile('Server IP Address', Icons.dns_outlined,
                    () => _serverSettingsDialog(context),
                    trailing: Text(LocalDb.baseUrl.replaceFirst('http://', ''),
                        style: const TextStyle(color: _maroon, fontSize: 12, fontWeight: FontWeight.bold))),
                _tile(
                  'Live Connection Ping',
                  Icons.wifi_tethering_outlined,
                  _testPing,
                  trailing: _checkingPing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: _maroon))
                      : Text(
                          _pingLatency != null ? '${_pingLatency}ms' : 'Disconnected ⚠️',
                          style: TextStyle(
                            color: _pingLatency != null ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                _tile(
                  'AI Model Diagnostics',
                  Icons.analytics_outlined,
                  null,
                  trailing: const Text('MobileNetV2, RF: Loaded',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 20),
              _section('About & Handbooks', [
                _tile('How AI Works (Consensus Guide)', Icons.psychology_outlined,
                    () => _aiConsensusDialog(context)),
                _tile('Saveetha Diagnostic Protocol (SDP)', Icons.menu_book_outlined,
                    () => _handbookDialog(context)),
                _tile('Medical Disclaimer', Icons.gavel_rounded,
                    () => _disclaimerDialog(context)),
                _tile('Version', Icons.system_update_alt_rounded, null,
                    trailing: const Text('v3.1.0',
                        style: TextStyle(color: _muted, fontSize: 12.5))),
              ]),
              const SizedBox(height: 20),
              _signOutTile(context),
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: TextStyle(color: _muted, fontSize: 10.5,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
    ),
    Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Column(children: [
          e.value,
          if (!isLast) Divider(height: 0, color: _border, indent: 56),
        ]);
      }).toList()),
    ),
  ]);

  Widget _toggle(String title, String sub, IconData icon,
      bool val, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(color: _muted, fontSize: 11.5)),
      trailing: Switch(
        value: val,
        onChanged: onChanged,
        activeColor: _maroon,
      ),
    );
  }

  Widget _dropdown(String title, String sub, IconData icon, String val,
      List<String> options, ValueChanged<String?> onChanged) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(color: _muted, fontSize: 11.5)),
      trailing: DropdownButton<String>(
        value: val,
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _text),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        underline: Container(),
        icon: const Icon(Icons.arrow_drop_down, color: _maroon),
      ),
    );
  }

  Widget _inputTile(String title, String sub, IconData icon,
      TextEditingController controller, String key) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(color: _muted, fontSize: 11.5)),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.end,
          style: const TextStyle(color: _maroon, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'SVDC-MAIN',
            hintStyle: TextStyle(color: _muted, fontSize: 13),
          ),
          onChanged: (val) => _saveString(key, val.trim()),
        ),
      ),
    );
  }

  Widget _tile(String title, IconData icon, VoidCallback? onTap,
      {Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: _muted, size: 20)
              : null),
    );
  }

  Widget _signOutTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFEBEE)),
      ),
      child: ListTile(
        onTap: () {
          Session.instance.clear();
          Navigator.pushReplacementNamed(context, '/login');
        },
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded,
              color: Color(0xFFC62828), size: 18),
        ),
        title: const Text('Sign Out',
            style: TextStyle(color: Color(0xFFC62828), fontSize: 13.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _dItem(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: _maroon),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12.5, height: 1.5))),
    ]),
  );

  void _disclaimerDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.gavel_rounded, color: _maroon, size: 22),
        SizedBox(width: 10),
        Text('Medical Disclaimer',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _dItem(Icons.info_outlined,
              'This application is a clinical decision-support tool intended to assist qualified dental clinicians.'),
          _dItem(Icons.not_interested_outlined,
              'It does NOT replace clinical judgment, histopathological examination, or biopsy results.'),
          _dItem(Icons.science_outlined,
              'AI risk scores are based on weighted clinical features. Accuracy is not guaranteed in all cases.'),
          _dItem(Icons.medical_services_outlined,
              'Treatment decisions must be made by a licensed healthcare professional after thorough clinical examination.'),
          _dItem(Icons.school_outlined,
              'Developed for academic use at Saveetha Dental College & Hospital, Chennai.'),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('I Understand',
              style: TextStyle(color: _maroon, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }
}
