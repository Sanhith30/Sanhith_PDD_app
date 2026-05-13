import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'db/local_db.dart';
import 'ml/risk_scorer.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  IMAGE UPLOAD PAGE  —  "Surgical Luxury"
//  Logic: local image copy + on-device AI scoring — no Cloudinary, no Render.com
// ─────────────────────────────────────────────────────────────────────────────

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage>
    with SingleTickerProviderStateMixin {

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  File? _selectedImage;
  bool  _isAnalyzing = false;
  String _step = '';

  final ImagePicker _picker = ImagePicker();

  late AnimationController _revealController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)
      ..forward();
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _revealController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  IMAGE PICK
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      _showError('Error capturing image: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ANALYSE — local scoring, no network calls
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _analyzeLocal(int caseId) async {
    if (_selectedImage == null) return;
    setState(() { _isAnalyzing = true; _step = 'Saving image…'; });

    try {
      // 1. Copy image to app documents folder
      final dir  = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'ulcer_$caseId.jpg');
      await _selectedImage!.copy(dest);

      // 2. Load clinical data from SQLite
      setState(() => _step = 'Loading clinical data…');
      final caseData = await LocalDb.instance.getCase(caseId);
      if (caseData == null) {
        _showError('Case not found in database.'); return;
      }

      final Map<String, dynamic> clinical =
          Map<String, dynamic>.from(
              (caseData['clinical_json'] != null &&
                      caseData['clinical_json'].toString().isNotEmpty)
                  ? jsonDecode(caseData['clinical_json'] as String)
                  : {});

      final Map<String, dynamic> demo =
          Map<String, dynamic>.from(clinical['demographics'] ?? {});
      final Map<String, dynamic> lesion =
          Map<String, dynamic>.from(clinical['lesionHistory'] ?? {});
      final Map<String, dynamic> exam =
          Map<String, dynamic>.from(clinical['clinicalExam'] ?? {});
      final Map<String, dynamic> findings =
          Map<String, dynamic>.from(clinical['associatedFindings'] ?? {});

      final patientId = (caseData['patient_id'] ?? '').toString();
      final patientData = await LocalDb.instance.getPatient(patientId);
      final int age  = (patientData?['age'] as int?) ?? 45;
      final String sex = (patientData?['sex'] as String?) ?? 'Male';

      // 3. Run Multi-Modal AI analysis (Clinical AI + Image Deep Learning)
      setState(() => _step = 'Running Multi-Modal AI analysis…');

      // Flatten the clinical data for the AI model
      final flattenedClinical = {
        "age": age,
        "sex": sex,
        "smoking_status": demo['smokingStatus'] ?? 'No',
        "smoking_duration": int.tryParse(demo['smokingDuration']?.toString() ?? '0') ?? 0,
        "smoking_frequency": demo['smokingFrequency'] ?? '',
        "smokeless_tobacco": (demo['smokelessTobacco'] == true) ? 1 : 0,
        "alcohol": demo['alcohol'] ?? 'No',
        "diabetes": (demo['diabetes'] == true) ? 1 : 0,
        "immunocompromised": (demo['immunocompromised'] == true) ? 1 : 0,
        "autoimmune": (demo['autoimmune'] == true) ? 1 : 0,
        "steroids": (demo['steroids'] == true) ? 1 : 0,
        "chemotherapy": (demo['chemotherapy'] == true) ? 1 : 0,
        "immunosuppressants": (demo['immunosuppressants'] == true) ? 1 : 0,
        "duration": lesion['duration'] ?? '< 2 weeks',
        "onset": lesion['onset'] ?? 'Sudden',
        "recurrence": lesion['recurrence'] ?? 'First episode',
        "pain": lesion['pain'] ?? 'Painful',
        "healing_pattern": lesion['healingPattern'] ?? 'Healing',
        "site": (exam['site'] ?? '').toString().replaceAll('⚠️', '').trim(),
        "size_mm": (exam['size'] as int?) ?? 0,
        "shape": exam['shape'] ?? 'Round/Ovoid',
        "margins": exam['margins'] ?? 'Well-defined',
        "edge": (exam['edge'] ?? '').toString().replaceAll('(Risk ⚠️)', '').trim(),
        "induration": (exam['induration'] == true) ? 1 : 0,
        "bleeding": (exam['bleeding'] == true) ? 1 : 0,
        "lymph_palpable": (findings['lymphPalpable'] == true) ? 1 : 0,
        "tender": (findings['tender']?.toString().toLowerCase() == 'yes') ? 1 : 0,
        "node_mobility": findings['nodeMobility']?.toString() ?? 'Mobile',
        "paraesthesia": (findings['paraesthesia'] == true) ? 1 : 0,
        "weight_loss": (findings['weightLoss'] == true) ? 1 : 0,
        "fever": (findings['fever'] == true) ? 1 : 0,
      };

      final result = await RiskScorer.predictFull(
        caseId: caseId,
        clinicalData: flattenedClinical,
        imageFile: _selectedImage!,
      );

      // 4. Save result to SQLite
      setState(() => _step = 'Saving results…');
      await LocalDb.instance.completeCase(
        caseId:              caseId,
        imagePath:           dest,
        riskScore:           result.score,
        clinicalScore:       result.clinicalScore,
        visualScore:         result.visualScore,
        riskCategory:        result.category,
        biopsyRecommendation:result.recommendation,
        confidence:          result.confidence,
        riskExplanation:     result.explanation,
        clinicalSuggestions: result.suggestions,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/ai_result',
            arguments: caseId);
      }

    } catch (e) {
      _showError('Analysis failed: $e');
    } finally {
      if (mounted) setState(() { _isAnalyzing = false; _step = ''; });
    }
  }

  void _showError(String msg) {
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
      duration: const Duration(seconds: 4),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final int caseId =
        ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(children: [
                  _buildImageCard(),
                  const SizedBox(height: 20),
                  _buildPickerButtons(),
                  const SizedBox(height: 20),
                  _buildGuidanceCard(),
                ]),
              ),
            ),
            _buildAnalyzeButton(caseId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [_maroonD, _maroon],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Capture Lesion',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w600)),
                Text('Photograph the oral ulcer clearly',
                    style: TextStyle(color: Colors.white.withOpacity(0.60),
                        fontSize: 11.5)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _gold.withOpacity(0.35), width: 1),
              ),
              child: Text('Step 2 of 2',
                  style: TextStyle(color: _gold.withOpacity(0.90),
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      height: 300, width: double.infinity,
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: _selectedImage != null
                ? _maroon.withOpacity(0.3) : _border,
            width: _selectedImage != null ? 1.5 : 1.0),
        boxShadow: [BoxShadow(color: _maroon.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(fit: StackFit.expand, children: [
                kIsWeb 
                    ? const Center(child: Text("Image preview not available on Web"))
                    : Image.file(_selectedImage!, fit: BoxFit.cover),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Image ready', style: TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            )
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _maroon.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_a_photo_outlined,
                      size: 32, color: _maroon.withOpacity(0.5))),
              const SizedBox(height: 16),
              Text('No image selected',
                  style: TextStyle(color: _muted, fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('Tap Camera or Gallery below',
                  style: TextStyle(color: _muted.withOpacity(0.6),
                      fontSize: 12)),
            ]),
    );
  }

  Widget _buildPickerButtons() {
    return Row(children: [
      Expanded(child: _buildPickerBtn(
        Icons.camera_alt_rounded,
        _selectedImage == null ? 'Camera' : 'Retake',
        _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
      )),
      const SizedBox(width: 14),
      Expanded(child: _buildPickerBtn(
        Icons.photo_library_rounded, 'Gallery',
        _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
      )),
    ]);
  }

  Widget _buildPickerBtn(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: _maroon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _maroon, fontSize: 14,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildGuidanceCard() {
    final tips = [
      ('Good lighting',        Icons.wb_sunny_outlined),
      ('Clear focus on ulcer', Icons.center_focus_strong_outlined),
      ('Avoid shadows',        Icons.block_outlined),
      ('Capture full lesion',  Icons.open_in_full_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tips_and_updates_outlined,
                color: _gold.withOpacity(0.85), size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Photography Tips', style: TextStyle(color: _text,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: tips.map((tip) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tip.$2, size: 13, color: _muted),
              const SizedBox(width: 5),
              Text(tip.$1, style: const TextStyle(color: _muted, fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _buildAnalyzeButton(int caseId) {
    final bool canAnalyze = _selectedImage != null && !_isAnalyzing;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_isAnalyzing) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _gold.withOpacity(0.7))),
            const SizedBox(width: 10),
            Text(_step, style: TextStyle(color: _muted, fontSize: 12,
                fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity, height: 52,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canAnalyze ? () => _analyzeLocal(caseId) : null,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: canAnalyze
                      ? const LinearGradient(
                          colors: [_maroon, _maroonD],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: canAnalyze ? null : _border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canAnalyze
                      ? [BoxShadow(color: _maroon.withOpacity(0.35),
                          blurRadius: 16, offset: const Offset(0, 6))]
                      : [],
                ),
                child: Center(
                  child: _isAnalyzing
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(
                            _selectedImage == null
                                ? Icons.camera_alt_outlined
                                : Icons.psychology_rounded,
                            color: _selectedImage == null
                                ? _muted : Colors.white,
                            size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _selectedImage == null
                                ? 'Select an image first'
                                : 'Process AI Analysis',
                            style: TextStyle(
                              color: _selectedImage == null
                                  ? _muted : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedImage != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 17),
                          ],
                        ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}