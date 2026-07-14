import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db/local_db.dart';

class WebCaseDetailPage extends StatelessWidget {
  const WebCaseDetailPage({super.key});

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  Future<void> _exportPdfReport(Map<String, dynamic> c) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SAVEETHA DENTAL COLLEGE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Oral Ulcer AI Diagnostic Report', style: pw.TextStyle(fontSize: 13)),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 20),
                pw.Text('Patient Name: ${c['patient_name'] ?? 'N/A'}'),
                pw.Text('Patient UHID: ${c['patient_id'] ?? 'N/A'}'),
                pw.Text('Assessing Clinician: ${c['doctor_name'] ?? 'N/A'}'),
                pw.Text('Screened Date: ${DateTime.fromMillisecondsSinceEpoch(c['created_at'] as int? ?? 0).toLocal()}'),
                pw.SizedBox(height: 20),
                pw.Text('Clinical Analysis Findings:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Risk Level: ${(c['risk_category'] ?? 'PENDING').toString().toUpperCase()}'),
                pw.Text('Risk Severity Index: ${double.tryParse(c['risk_score']?.toString() ?? '0')?.toStringAsFixed(1)}%'),
                pw.Text('Biopsy Indication: ${c['biopsy_recommendation'] ?? 'N/A'}'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final int caseId = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Clinical Assessment Report', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: _text),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: LocalDb.instance.getCase(caseId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _maroon));
          }
          final c = snap.data!;

          final String patId   = c['patient_id']?.toString()   ?? 'Unknown';
          final String patName = c['patient_name']?.toString() ?? '';
          final String doctorName = c['doctor_name']?.toString() ?? 'Unknown';
          final String risk    = c['risk_category']?.toString() ?? 'PENDING';
          final String imagePath = c['image_path']?.toString()  ?? '';
          final double riskScore = (c['risk_score'] as num?)?.toDouble() ?? 0.0;
          final double clinicalScore = (c['clinical_score'] as num?)?.toDouble() ?? 0.0;
          final double visualScore = (c['visual_score'] as num?)?.toDouble() ?? 0.0;
          final String biopsy  = c['biopsy_recommendation']?.toString() ?? '';
          final String conf    = c['confidence']?.toString() ?? '';

          final int ms = (c['created_at'] as int?) ?? 0;
          final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
          final String dateStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

          final List<dynamic> explanations = c['risk_explanation_json'] != null
              ? jsonDecode(c['risk_explanation_json'] as String) : [];
          final List<dynamic> suggestions  = c['suggestions_json'] != null
              ? jsonDecode(c['suggestions_json'] as String) : [];

          Map<String, dynamic> clinical = {};
          try {
            clinical = c['clinical_json'] != null && c['clinical_json'].toString().isNotEmpty
                ? Map<String, dynamic>.from(jsonDecode(c['clinical_json'] as String))
                : {};
          } catch (_) {}

          final Map<String, dynamic> demo    = Map<String, dynamic>.from(clinical['demographics']       ?? {});
          final Map<String, dynamic> lesion  = Map<String, dynamic>.from(clinical['lesionHistory']      ?? {});
          final Map<String, dynamic> exam    = Map<String, dynamic>.from(clinical['clinicalExam']       ?? {});
          final Map<String, dynamic> assoc   = Map<String, dynamic>.from(clinical['associatedFindings'] ?? {});

          Color riskColor, riskBg;
          IconData riskIcon;
          if (risk.toUpperCase().contains('HIGH')) {
            riskColor = _red;
            riskBg = const Color(0xFFFFEBEE);
            riskIcon = Icons.warning_rounded;
          } else if (risk.toUpperCase().contains('INTERMEDIATE') || risk.toUpperCase().contains('MODERATE')) {
            riskColor = Colors.orange;
            riskBg = const Color(0xFFFFF8E1);
            riskIcon = Icons.info_rounded;
          } else {
            riskColor = Colors.green;
            riskBg = const Color(0xFFE8F5E9);
            riskIcon = Icons.check_circle_rounded;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Core case description
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      // Header panel with export actions
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Case Reference: #$caseId', style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Screened on $dateStr', style: const TextStyle(color: _muted, fontSize: 13)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _exportPdfReport(c),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                                  label: const Text('EXPORT PDF', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: _maroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ],
                            ),
                            const Divider(height: 32, color: _border),
                            _buildInfoText('Patient Name', patName),
                            const SizedBox(height: 10),
                            _buildInfoText('Patient UHID', patId),
                            const SizedBox(height: 10),
                            _buildInfoText('Assessing Clinician', doctorName),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Risk classification card
                      _buildRiskBanner(risk, biopsy, conf, riskColor, riskBg, riskIcon),
                      const SizedBox(height: 24),
                      _buildScoreGauges(clinicalScore, visualScore, riskScore, riskColor),
                      const SizedBox(height: 24),
                      if (imagePath.isNotEmpty) _buildImageCard(imagePath),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Right Column: Complete checklist parameters & explanations
                Expanded(
                  flex: 13,
                  child: Column(
                    children: [
                      _buildClinicalDetailsCard(demo, lesion, exam, assoc),
                      const SizedBox(height: 24),
                      _buildFactorsCard(explanations, riskColor),
                      const SizedBox(height: 24),
                      if (suggestions.isNotEmpty) _buildSuggestionsCard(suggestions, riskColor),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRiskBanner(String category, String recommendation, String confidence, Color color, Color bg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(category.toUpperCase(), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: color.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text('Biopsy: $recommendation', textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('AI Confidence Level: $confidence', style: TextStyle(color: color.withOpacity(0.6), fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildScoreGauges(double clinical, double visual, double combined, Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGauge('Clinical AI', clinical, _gold),
          Container(width: 1, height: 70, color: _border),
          _buildGauge('Visual AI', visual, Colors.blueAccent),
          Container(width: 1, height: 70, color: _border),
          _buildGauge('Combined Risk', combined, color, isLarge: true),
        ],
      ),
    );
  }

  Widget _buildGauge(String label, double percent, Color color, {bool isLarge = false}) {
    final double size = isLarge ? 90 : 72;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size, height: size,
              child: CircularProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                color: color,
                backgroundColor: color.withOpacity(0.08),
                strokeWidth: isLarge ? 8 : 6,
              ),
            ),
            Text('${percent.toStringAsFixed(1)}%', style: TextStyle(color: _text, fontSize: isLarge ? 14.5 : 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildImageCard(String photo) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lesion Image Record', style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 220,
              width: double.infinity,
              color: _bg,
              child: Image.network(LocalDb.resolveUrl(photo), fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalDetailsCard(Map<String, dynamic> demo, Map<String, dynamic> lesion, Map<String, dynamic> exam, Map<String, dynamic> assoc) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Parameters & Findings', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildParamSection('A. Demographics & Habits', [
            'Smoking status: ${demo['smokingStatus'] ?? "No"} (${demo['smokingDuration'] ?? 0} yrs)',
            'Smokeless tobacco: ${demo['smokelessTobacco'] == true ? "Yes" : "No"}',
            'Alcohol: ${demo['alcohol'] ?? "No"}',
            'Diabetes: ${demo['diabetes'] == true ? "Yes" : "No"}',
            'Immunocompromised: ${demo['immunocompromised'] == true ? "Yes" : "No"}',
          ]),
          const Divider(height: 28, color: _border),
          _buildParamSection('B. Lesion History', [
            'Duration: ${lesion['duration'] ?? "N/A"}',
            'Onset: ${lesion['onset'] ?? "N/A"}',
            'Recurrence: ${lesion['recurrence'] ?? "N/A"}',
            'Pain profile: ${lesion['pain'] ?? "N/A"}',
            'Healing pattern: ${lesion['healingPattern'] ?? "N/A"}',
          ]),
          const Divider(height: 28, color: _border),
          _buildParamSection('C. Clinical Examination', [
            'Anatomical site: ${exam['site'] ?? "N/A"}',
            'Size: ${exam['size'] ?? 0} mm',
            'Shape: ${exam['shape'] ?? "N/A"}',
            'Margins: ${exam['margins'] ?? "N/A"}',
            'Edge description: ${exam['edge'] ?? "N/A"}',
            'Induration: ${exam['induration'] == true ? "Yes" : "No"}',
            'Bleeding on palpation: ${exam['bleeding'] == true ? "Yes" : "No"}',
          ]),
        ],
      ),
    );
  }

  Widget _buildParamSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: details.map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                child: Text(d, style: const TextStyle(color: _text, fontSize: 13)),
              )).toList(),
        ),
      ],
    );
  }

  Widget _buildFactorsCard(List<dynamic> factors, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Diagnostic Factors', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (factors.isEmpty)
            const Text('No critical risk triggers identified.', style: TextStyle(color: _muted, fontSize: 13))
          else
            ...factors.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: color, size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f.toString(), style: const TextStyle(color: _text, fontSize: 14.5))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(List<dynamic> suggestions, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Differentials suggestions', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added_outlined, color: _gold, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.toString(), style: const TextStyle(color: _text, fontSize: 14.5, fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
