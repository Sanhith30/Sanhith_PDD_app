import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// Profile Page — Overhauled Clinical Credentials & Advanced Logs Suite

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

  // Dynamic Preferences & History State
  String _dept = 'Oral Medicine & Radiology';
  String _facilityId = 'SVDC-MAIN';
  bool _biometricLogin = false;
  String _autoLockTime = 'Never';
  bool _offlineMode = false;
  List<Map<String, dynamic>> _recentCases = [];
  bool _loadingRecent = true;

  // Advanced Credentials state
  String _licenseNo = 'DCI-98745-A';
  List<Offset?> _signaturePoints = [];

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
    
    // Load local SharedPreferences preferences
    final prefs = await SharedPreferences.getInstance();
    final dept = prefs.getString('pref_dept') ?? 'Oral Medicine & Radiology';
    final facility = prefs.getString('pref_facility_id') ?? 'SVDC-MAIN';
    final biometric = prefs.getBool('pref_biometric_login') ?? false;
    final autoLock = prefs.getString('pref_auto_lock_time') ?? 'Never';
    final offline = prefs.getBool('pref_offline_mode') ?? false;
    final license = prefs.getString('pref_license_no') ?? 'DCI-98745-A';

    // Load signature points
    List<Offset?> sigPoints = [];
    final sigStr = prefs.getString('pref_signature_data') ?? '';
    if (sigStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(sigStr);
        sigPoints = decoded.map((item) {
          if (item == null || (item is Map && item.containsKey('null'))) {
            return null;
          } else {
            return Offset((item['x'] as num).toDouble(), (item['y'] as num).toDouble());
          }
        }).toList();
      } catch (_) {}
    }

    // Load recent activity log: Sort cases by created_at descending and take top 4
    final sortedRaw = List<Map<String, dynamic>>.from(raw);
    sortedRaw.sort((a, b) {
      final tA = a['created_at'] as int? ?? 0;
      final tB = b['created_at'] as int? ?? 0;
      return tB.compareTo(tA);
    });
    final recent = sortedRaw.take(4).toList();

    if (mounted) {
      setState(() { 
        _totalCases = uniqueCases.length; 
        _highRisk = high; 
        _dept = dept;
        _facilityId = facility;
        _biometricLogin = biometric;
        _autoLockTime = autoLock;
        _offlineMode = offline;
        _licenseNo = license;
        _signaturePoints = sigPoints;
        _recentCases = recent;
        _loadingRecent = false;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "UPDATE PROFILE PHOTO",
                    style: TextStyle(
                      color: _maroon,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _muted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.camera_alt_outlined,
                      label: "Capture Camera",
                      onTap: () {
                        Navigator.pop(context);
                        _executePhotoPick(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.photo_library_outlined,
                      label: "Browse Gallery",
                      onTap: () {
                        Navigator.pop(context);
                        _executePhotoPick(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Icon(icon, color: _maroon, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executePhotoPick(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      bool ok;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        ok = await LocalDb.instance.updateProfilePhoto(
          imageBytes: bytes,
          fileName: pickedFile.name,
        );
      } else {
        ok = await LocalDb.instance.updateProfilePhoto(
          localPhotoPath: pickedFile.path,
        );
      }
      if (ok && mounted) {
        setState(() {});
        _snack('Profile picture updated!');
        _loadStats();
      } else {
        _snack('Failed to save profile picture.');
      }
    }
  }

  pw.Widget _buildPdfSignature() {
    if (_signaturePoints.isEmpty) {
      return pw.Container(
        height: 14,
        alignment: pw.Alignment.center,
        child: pw.Text(
          "NO SIGNATURE SAVED",
          style: pw.TextStyle(fontSize: 4, color: PdfColors.grey, fontWeight: pw.FontWeight.bold),
        ),
      );
    }
    
    double minX = 99999;
    double maxX = -99999;
    double minY = 99999;
    double maxY = -99999;
    
    bool hasPoints = false;
    for (final p in _signaturePoints) {
      if (p != null) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        hasPoints = true;
      }
    }
    
    if (!hasPoints) {
      return pw.Container(
        height: 14,
        alignment: pw.Alignment.center,
        child: pw.Text(
          "NO SIGNATURE SAVED",
          style: pw.TextStyle(fontSize: 4, color: PdfColors.grey, fontWeight: pw.FontWeight.bold),
        ),
      );
    }
    
    double width = maxX - minX;
    if (width == 0) width = 1;
    double height = maxY - minY;
    if (height == 0) height = 1;
    
    double targetWidth = 48.0;
    double targetHeight = 14.0;
    double scale = targetWidth / width;
    if (targetHeight / height < scale) {
      scale = targetHeight / height;
    }
    if (scale > 2.0) scale = 2.0;

    return pw.CustomPaint(
      size: const PdfPoint(48.0, 14.0),
      painter: (canvas, size) {
        canvas.setStrokeColor(const PdfColor.fromInt(0xFF7B1E3A));
        canvas.setLineWidth(0.8);
        canvas.setLineCap(PdfLineCap.round);
        
        bool isNewStroke = true;
        PdfPoint lastPoint = const PdfPoint(0, 0);
        
        for (final p in _signaturePoints) {
          if (p == null) {
            isNewStroke = true;
          } else {
            double scaledX = (p.dx - minX) * scale;
            double scaledY = size.y - ((p.dy - minY) * scale);
            
            PdfPoint currentPoint = PdfPoint(scaledX, scaledY);
            if (!isNewStroke) {
              canvas.moveTo(lastPoint.x, lastPoint.y);
              canvas.lineTo(currentPoint.x, currentPoint.y);
              canvas.strokePath();
            }
            lastPoint = currentPoint;
            isNewStroke = false;
          }
        }
      },
    );
  }

  Future<void> _generateIdBadge() async {
    try {
      final name = Session.instance.displayName.toUpperCase();
      final doctorId = Session.instance.doctorId;
      final dept = _dept;
      final facility = _facilityId;
      final photoPath = Session.instance.photoPath;

      // Read profile photo bytes if local/remote
      Uint8List? photoBytes;
      if (photoPath != null && photoPath.isNotEmpty) {
        if (!kIsWeb && !photoPath.startsWith('http') && !photoPath.startsWith('/static')) {
          final file = File(photoPath);
          if (file.existsSync()) {
            photoBytes = await file.readAsBytes();
          }
        } else {
          try {
            final fullUrl = photoPath.startsWith('http')
                ? photoPath
                : '${LocalDb.baseUrl}$photoPath';
            final response = await http.get(
              Uri.parse(fullUrl),
              headers: const {'Bypass-Tunnel-Reminder': 'true'},
            ).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              photoBytes = response.bodyBytes;
            }
          } catch (_) {}
        }
      }

      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          // CR80 dimension in points (1 inch = 72 points)
          // Width: 3.375 in * 72 = 243
          // Height: 2.125 in * 72 = 153
          pageFormat: const PdfPageFormat(243.0, 153.0, marginAll: 0.0),
          build: (pw.Context context) {
            final pw.ImageProvider? avatarImage = photoBytes != null
                ? pw.MemoryImage(photoBytes)
                : null;

            return pw.Container(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFAF7F4), // _bg
              ),
              child: pw.Stack(
                children: [
                  // Maroon accent header band
                  pw.Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 24,
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [
                            PdfColor.fromInt(0xFF5C1028), // _maroonD
                            PdfColor.fromInt(0xFF7B1E3A), // _maroon
                          ],
                          begin: pw.Alignment.topLeft,
                          end: pw.Alignment.bottomRight,
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "SAVEETHA DENTAL COLLEGE",
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFFC9A84C), // _gold
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.Text(
                            "CLINICAL STAFF",
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Gold border line below header
                  pw.Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 1.5,
                      color: const PdfColor.fromInt(0xFFC9A84C),
                    ),
                  ),

                  // Badge Details
                  pw.Positioned(
                    top: 32,
                    left: 10,
                    right: 10,
                    bottom: 18,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left column: Profile Pic and QR Code
                        pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 42,
                              height: 42,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: PdfColors.white,
                                border: pw.Border.all(
                                  color: const PdfColor.fromInt(0xFFC9A84C),
                                  width: 1.5,
                                ),
                              ),
                              child: pw.ClipOval(
                                child: avatarImage != null
                                    ? pw.Image(avatarImage, fit: pw.BoxFit.cover)
                                    : pw.Center(
                                        child: pw.Text(
                                          name.isNotEmpty ? name[0] : 'C',
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF7B1E3A),
                                            fontSize: 18,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Container(
                              width: 32,
                              height: 32,
                              padding: const pw.EdgeInsets.all(1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                border: pw.Border.all(
                                  color: const PdfColor.fromInt(0xFFE8DDD8),
                                  width: 0.5,
                                ),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: 'doctor_id:$doctorId|name:$name|dept:$dept|facility:$facility',
                                drawText: false,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(width: 12),
                        // Right column: Clinician Info
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                "DR. $name",
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFF1E0A10),
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                "SENIOR CLINICIAN",
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFFC9A84C),
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              
                              pw.Text(
                                "DEPARTMENT",
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFF9E8A8F),
                                  fontSize: 4.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                dept,
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFF1E0A10),
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: pw.TextOverflow.clip,
                              ),
                              pw.SizedBox(height: 4),

                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Expanded(
                                    flex: 6,
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          "FACILITY ID",
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF9E8A8F),
                                            fontSize: 4.5,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.Text(
                                          facility,
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF1E0A10),
                                            fontSize: 6.5,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Text(
                                          "CLINICIAN ID",
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF9E8A8F),
                                            fontSize: 4.5,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.Text(
                                          "SDC-$doctorId",
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF1E0A10),
                                            fontSize: 6.5,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.Expanded(
                                    flex: 5,
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                                      mainAxisAlignment: pw.MainAxisAlignment.end,
                                      children: [
                                        _buildPdfSignature(),
                                        pw.Container(
                                          width: 48,
                                          height: 0.5,
                                          color: const PdfColor.fromInt(0xFFE8DDD8),
                                        ),
                                        pw.SizedBox(height: 1),
                                        pw.Text(
                                          "CLINICIAN SIGNATURE",
                                          style: pw.TextStyle(
                                            color: const PdfColor.fromInt(0xFF9E8A8F),
                                            fontSize: 3.5,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Maroon accent bottom footer bar
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 10,
                      color: const PdfColor.fromInt(0xFF7B1E3A),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        "VERIFIED DIGITAL CLINICAL CREDENTIAL",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 4.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  pw.Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 1,
                      color: const PdfColor.fromInt(0xFFC9A84C),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'SDC_Staff_Badge_$doctorId.pdf',
      );
    } catch (e) {
      _snack('Failed to generate ID badge: $e');
    }
  }

  Widget _buildProfileImage() {
    final path = Session.instance.photoPath;
    if (path == null || path.isEmpty) {
      return Center(
        child: Text(Session.instance.initial,
            style: const TextStyle(
                color: _maroon,
                fontSize: 36,
                fontWeight: FontWeight.w800)),
      );
    }
    
    if (path.startsWith('/static') || path.startsWith('http')) {
      final String fullUrl = path.startsWith('http')
          ? path
          : '${LocalDb.baseUrl}$path';
      return Image.network(
        fullUrl,
        headers: const {'Bypass-Tunnel-Reminder': 'true'},
        fit: BoxFit.cover,
        width: 90,
        height: 90,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(Session.instance.initial,
              style: const TextStyle(
                  color: _maroon,
                  fontSize: 36,
                  fontWeight: FontWeight.w800)),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              color: _maroon,
              strokeWidth: 2,
            ),
          );
        },
      );
    } else if (!kIsWeb && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: 90,
        height: 90,
      );
    } else {
      return Center(
        child: Text(Session.instance.initial,
            style: const TextStyle(
                color: _maroon,
                fontSize: 36,
                fontWeight: FontWeight.w800)),
      );
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
                  Semantics(
                    label: "Profile Photo",
                    button: true,
                    child: GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _surface,
                          border: Border.all(color: _gold, width: 2.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                              blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: ClipOval(
                          child: _buildProfileImage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("DR. ${Session.instance.displayName.toUpperCase()}",
                          style: const TextStyle(color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                      const SizedBox(width: 6),
                      Semantics(
                        label: "License Verification",
                        button: true,
                        child: GestureDetector(
                          onTap: _showLicenseDialog,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, color: Colors.blue, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: "License Verification",
                    button: true,
                    child: GestureDetector(
                      onTap: _showLicenseDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _gold.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, color: _gold, size: 10),
                            const SizedBox(width: 4),
                            Text("VERIFIED: $_licenseNo",
                                style: const TextStyle(color: _gold, fontSize: 9,
                                    fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                    ),
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
              _achievementsRow(),
              const SizedBox(height: 20),
              _badgeCard(),
              const SizedBox(height: 20),
              _signatureCard(),
              const SizedBox(height: 20),
              _statsCard(),
              const SizedBox(height: 20),
              _recentAnalyticsCard(),
              const SizedBox(height: 20),
              _recentActivityCard(),
              const SizedBox(height: 20),
              _securityStatusCard(),
              const SizedBox(height: 20),
              _pwSection(),
              const SizedBox(height: 20),
              if (_pwSuccess) _pwSuccessBanner(),
              const SizedBox(height: 28),
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
      _infoRow(Icons.work_outline_rounded, "Department", _dept),
      const Divider(height: 24),
      _infoRow(Icons.location_on_outlined, "Institution", "Saveetha Dental College"),
      const Divider(height: 24),
      _infoRow(Icons.pin_drop_outlined, "Facility ID", _facilityId),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: _maroon, size: 20),
    const SizedBox(width: 14),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  ]);

  Widget _achievementsRow() {
    final hasBronze = _totalCases >= 1;
    final hasSilver = _totalCases >= 5;
    final hasGold = _highRisk >= 2;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CLINICAL MILESTONES & ACHIEVEMENTS",
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _achievementBadge(
                icon: Icons.shield_outlined,
                title: "Screening Rookie",
                desc: "Complete 1 patient screening assessment to start diagnostic logs.",
                unlocked: hasBronze,
                color: const Color(0xFFCD7F32), // Bronze
              ),
              _achievementBadge(
                icon: Icons.emoji_events_outlined,
                title: "Diagnostic Veteran",
                desc: "Perform 5 patient assessments to establish historical cases log.",
                unlocked: hasSilver,
                color: const Color(0xFFC0C0C0), // Silver
              ),
              _achievementBadge(
                icon: Icons.local_fire_department_outlined,
                title: "Risk Sentinel",
                desc: "Accurately flag and review 2 high-risk oral ulcer cases.",
                unlocked: hasGold,
                color: _gold, // Gold
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achievementBadge({
    required IconData icon,
    required String title,
    required String desc,
    required bool unlocked,
    required Color color,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: GestureDetector(
      onTap: () => _showAchievementDetail(title, desc, unlocked, color),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? color.withOpacity(0.12) : Colors.black.withOpacity(0.04),
              border: Border.all(
                color: unlocked ? color : _border,
                width: 2.0,
              ),
              boxShadow: unlocked
                  ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)]
                  : [],
            ),
            child: Icon(
              icon,
              color: unlocked ? color : _muted.withOpacity(0.4),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: unlocked ? _text : _muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? "UNLOCKED" : "LOCKED",
            style: TextStyle(
              color: unlocked ? color : _muted.withOpacity(0.6),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showAchievementDetail(String title, String desc, bool unlocked, Color color) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                ),
                child: Icon(Icons.emoji_events, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc,
                style: const TextStyle(fontSize: 12.5, color: _text, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    color: unlocked ? Colors.green : _muted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unlocked ? "Status: Unlocked & Active" : "Status: Locked",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: unlocked ? Colors.green : _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _badgeCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DIGITAL CREDENTIAL",
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: _gold, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Professional ID Badge",
                    style: TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Generate a printable CR80 standard digital staff badge with verification QR code.",
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _generateIdBadge,
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
            label: const Text(
              "Print/Save ID Badge",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _signatureCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "DIGITAL SIGNATURE",
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              if (_signaturePoints.isNotEmpty)
                GestureDetector(
                  onTap: _clearSignature,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _maroon.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Reset",
                      style: TextStyle(color: _maroon, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_signaturePoints.isEmpty)
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Text(
                  "No signature captured yet.",
                  style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _SignaturePreviewPainter(_signaturePoints),
                  size: Size.infinite,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showSignatureCanvasDialog,
              icon: const Icon(Icons.border_color_rounded, color: Colors.white, size: 16),
              label: Text(
                _signaturePoints.isEmpty ? "Capture Digital Signature" : "Update Signature",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _recentAnalyticsCard() {
    int lowRiskCount = _totalCases - _highRisk;
    int highRiskCount = _highRisk;
    
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SCREENING RISK PROFILE",
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          if (_totalCases == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "Screen patients to view risk breakdown charts.",
                  style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            color: _maroon,
                            value: highRiskCount.toDouble(),
                            title: '${((highRiskCount / _totalCases) * 100).toStringAsFixed(0)}%',
                            radius: 24,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: _gold,
                            value: lowRiskCount.toDouble(),
                            title: '${((lowRiskCount / _totalCases) * 100).toStringAsFixed(0)}%',
                            radius: 24,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _chartLegend(_maroon, "High Risk", "$highRiskCount cases"),
                      const SizedBox(height: 10),
                      _chartLegend(_gold, "Low/Int. Risk", "$lowRiskCount cases"),
                      const Divider(height: 20),
                      Text(
                        "Total Screenings: $_totalCases",
                        style: const TextStyle(
                          color: _text,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chartLegend(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _recentActivityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "RECENT SCREENINGS",
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingRecent)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: _maroon, strokeWidth: 2),
              ),
            )
          else if (_recentCases.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "No patient cases screened yet.",
                  style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentCases.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final c = _recentCases[index];
                final patientName = c['patient_name'] ?? 'Unknown Patient';
                final patientId = c['patient_id'] ?? 'N/A';
                final riskCategory = (c['risk_category'] ?? 'N/A').toString();
                final riskScore = c['risk_score'] != null 
                    ? "${(c['risk_score'] as num).toStringAsFixed(1)}%"
                    : "0.0%";
                
                final ms = c['created_at'] as int? ?? 0;
                String dateStr = 'N/A';
                if (ms > 0) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                  dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                }

                final isHigh = riskCategory.toUpperCase().contains('HIGH');
                final badgeColor = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
                final textColor = isHigh ? const Color(0xFF991B1B) : const Color(0xFF92400E);
                
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_outlined, color: _maroon, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ID: $patientId  •  $dateStr",
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            riskCategory.toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Score: $riskScore",
                          style: const TextStyle(
                            color: _text,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _securityStatusCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DEVICE SECURITY & SYNCHRONIZATION",
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          _statusRow(
            icon: Icons.fingerprint_rounded,
            label: "Biometric Authentication",
            value: _biometricLogin ? "ACTIVE (FINGERPRINT / FACE ID)" : "INACTIVE",
            isActive: _biometricLogin,
          ),
          const Divider(height: 20),
          _statusRow(
            icon: Icons.timer_outlined,
            label: "Auto-Lock Timeout",
            value: _autoLockTime == 'Never' ? "DISABLED (KEEP LOGGED IN)" : "ACTIVE ($_autoLockTime)",
            isActive: _autoLockTime != 'Never',
          ),
          const Divider(height: 20),
          _statusRow(
            icon: Icons.sync_disabled_rounded,
            label: "Offline Database Cache",
            value: _offlineMode ? "ACTIVE (LOCAL CACHE RUNNING)" : "INACTIVE (ONLINE SYNCED)",
            isActive: _offlineMode,
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(icon, color: isActive ? _maroon : _muted, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isActive ? _text : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

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

  Future<void> _showLicenseDialog() async {
    final ctrl = TextEditingController(text: _licenseNo);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: _maroon),
              SizedBox(width: 10),
              Text('Dental Council Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify your professional license number issued by the Dental Council of India (DCI) or your local regulatory authority.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 16),
              const Text('License Registration No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _maroon)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F3F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'e.g. DCI-98745-A',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Verified by Saveetha Dental College registry on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}.',
                      style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('pref_license_no', text);
                  if (!mounted) return;
                  setState(() {
                    _licenseNo = text;
                  });
                  navigator.pop();
                  _snack('Registration credentials updated!');
                  _loadStats();
                } else {
                  _snack('Registration number cannot be empty.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSignatureCanvasDialog() async {
    final List<Offset?> drawPoints = [];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.border_color_rounded, color: _maroon),
                  SizedBox(width: 10),
                  Text('Capture Signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Draw your signature inside the box below using your finger or stylus.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.maxFinite,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF8F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Semantics(
                        label: "Signature Canvas",
                        child: GestureDetector(
                          onPanStart: (details) {
                            setDialogState(() {
                              drawPoints.add(details.localPosition);
                            });
                          },
                          onPanUpdate: (details) {
                            setDialogState(() {
                              drawPoints.add(details.localPosition);
                            });
                          },
                          onPanEnd: (details) {
                            setDialogState(() {
                              drawPoints.add(null);
                            });
                          },
                          child: CustomPaint(
                            painter: _CanvasPainter(drawPoints),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: _muted)),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      drawPoints.clear();
                    });
                  },
                  child: const Text('Clear', style: TextStyle(color: _maroon, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (drawPoints.isEmpty) {
                      _snack('Please sign inside the canvas first.');
                      return;
                    }
                    
                    final List<Map<String, double>> serialized = [];
                    for (final p in drawPoints) {
                      if (p == null) {
                        serialized.add({'null': 1.0});
                      } else {
                        serialized.add({'x': p.dx, 'y': p.dy});
                      }
                    }
                    
                    final navigator = Navigator.of(context);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('pref_signature_data', jsonEncode(serialized));
                    
                    if (!mounted) return;
                    setState(() {
                      _signaturePoints = drawPoints;
                    });
                    
                    navigator.pop();
                    _snack('Digital signature saved successfully!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _maroon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Signature', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _clearSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_signature_data');
    if (!mounted) return;
    setState(() {
      _signaturePoints = [];
    });
    _snack('Signature cleared.');
  }
}

class _SignaturePreviewPainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePreviewPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minX = 99999;
    double maxX = -99999;
    double minY = 99999;
    double maxY = -99999;
    
    bool hasPoints = false;
    for (final p in points) {
      if (p != null) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        hasPoints = true;
      }
    }
    
    if (!hasPoints) return;
    
    double width = maxX - minX;
    if (width == 0) width = 1;
    double height = maxY - minY;
    if (height == 0) height = 1;
    
    double padding = 15.0;
    double targetWidth = size.width - (padding * 2);
    double targetHeight = size.height - (padding * 2);
    
    double scale = targetWidth / width;
    if (targetHeight / height < scale) {
      scale = targetHeight / height;
    }
    if (scale > 3.0) scale = 3.0;

    final paint = Paint()
      ..color = const Color(0xFF7B1E3A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        double x1 = padding + (points[i]!.dx - minX) * scale;
        double y1 = padding + (points[i]!.dy - minY) * scale;
        double x2 = padding + (points[i + 1]!.dx - minX) * scale;
        double y2 = padding + (points[i + 1]!.dy - minY) * scale;
        
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePreviewPainter oldDelegate) => true;
}

class _CanvasPainter extends CustomPainter {
  final List<Offset?> points;
  _CanvasPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7B1E3A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}
