import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/local_db.dart';
import '../ml/risk_scorer.dart';

class WebImageUploadPage extends StatefulWidget {
  const WebImageUploadPage({super.key});

  @override
  State<WebImageUploadPage> createState() => _WebImageUploadPageState();
}

class _WebImageUploadPageState extends State<WebImageUploadPage> {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isAnalyzing = false;
  String _step = '';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _analyze(int caseId) async {
    if (_selectedImageBytes == null) return;
    setState(() {
      _isAnalyzing = true;
      _step = 'Fetching clinical data...';
    });

    try {
      final caseData = await LocalDb.instance.getCase(caseId);
      if (caseData == null) {
        _showError('Case record not found.');
        return;
      }

      setState(() => _step = 'Preparing clinical data...');
      final Map<String, dynamic> clinical = Map<String, dynamic>.from(
          (caseData['clinical_json'] != null && caseData['clinical_json'].toString().isNotEmpty)
              ? jsonDecode(caseData['clinical_json'] as String)
              : {});

      final Map<String, dynamic> demo = Map<String, dynamic>.from(clinical['demographics'] ?? {});
      final Map<String, dynamic> lesion = Map<String, dynamic>.from(clinical['lesionHistory'] ?? {});
      final Map<String, dynamic> exam = Map<String, dynamic>.from(clinical['clinicalExam'] ?? {});
      final Map<String, dynamic> findings = Map<String, dynamic>.from(clinical['associatedFindings'] ?? {});

      final patientId = (caseData['patient_id'] ?? '').toString();
      final patientData = await LocalDb.instance.getPatient(patientId);
      final int age  = (patientData?['age'] as int?) ?? 45;
      final String sex = (patientData?['sex'] as String?) ?? 'Male';

      setState(() => _step = 'Running Multi-Modal AI analysis...');
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
        imageFile: null,
        imageBytes: _selectedImageBytes,
        fileName: _selectedImageName,
      );

      setState(() => _step = 'Saving diagnostics...');
      final imagePathToSave = result.serverImagePath ?? '';

      await LocalDb.instance.completeCase(
        caseId:              caseId,
        imagePath:           imagePathToSave,
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
        Navigator.pushReplacementNamed(context, '/ai_result', arguments: caseId);
      }
    } catch (e) {
      _showError('AI diagnostic analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));
  }

  @override
  Widget build(BuildContext context) {
    final int caseId = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Lesion Image Upload', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: _text),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: _maroon.withOpacity(0.04), blurRadius: 32, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Image selector
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: _isAnalyzing ? null : _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 380,
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border, width: 2),
                      ),
                      child: _selectedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 48, color: _maroon),
                                const SizedBox(height: 16),
                                const Text('Drag & Drop or Click to Upload', style: TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 6),
                                Text('PNG, JPG, or JPEG formats supported', style: TextStyle(color: _muted, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                // Right side: Controls
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Diagnostic Image Input', style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        'Provide a clear, high-resolution clinical photograph of the oral lesion. The visual deep learning engine will analyze risk parameters dynamically.',
                        style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: _accent, size: 20),
                            const SizedBox(width: 14),
                            Text('Diagnostic Case Reference ID: #$caseId', style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_isAnalyzing) ...[
                        Column(
                          children: [
                            const CircularProgressIndicator(color: _maroon),
                            const SizedBox(height: 20),
                            Text(_step, style: const TextStyle(color: _maroon, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _selectedImageBytes == null ? null : () => _analyze(caseId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _maroon,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('ANALYZE LESION VISUALS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
