import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'db/local_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CASE DETAIL PAGE  —  Screen 14
//  Full clinical breakdown of a single assessed case
//  Reads from local SQLite — no network calls
// ─────────────────────────────────────────────────────────────────────────────

class CaseDetailPage extends StatelessWidget {
  const CaseDetailPage({super.key});

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  @override
  Widget build(BuildContext context) {
    final int caseId =
        ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: LocalDb.instance.getCase(caseId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(
                color: _maroon, strokeWidth: 2));
          }
          final c = snap.data!;
          return _buildBody(context, c);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> c) {
    final String patId   = c['patient_id']?.toString()   ?? 'Unknown';
    final String patName = c['patient_name']?.toString() ?? '';
    final String doctorName = c['doctor_name']?.toString() ?? 'Unknown';
    final String risk    = c['risk_category']?.toString() ?? 'PENDING';
    final String status  = c['status']?.toString()        ?? '';
    final String imagePath = c['image_path']?.toString()  ?? '';
    final double riskScore = (c['risk_score'] as num?)?.toDouble() ?? 0.0;
    final String biopsy  = c['biopsy_recommendation']?.toString() ?? '';
    final String conf    = c['confidence']?.toString() ?? '';

    final int ms = (c['created_at'] as int?) ?? 0;
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final String dateStr =
        '${dt.day.toString().padLeft(2,'0')}/'
        '${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    final List<dynamic> explanations = c['risk_explanation_json'] != null
        ? jsonDecode(c['risk_explanation_json'] as String) : [];
    final List<dynamic> suggestions  = c['suggestions_json'] != null
        ? jsonDecode(c['suggestions_json'] as String) : [];

    Map<String, dynamic> clinical = {};
    try {
      clinical = c['clinical_json'] != null &&
              c['clinical_json'].toString().isNotEmpty
          ? Map<String, dynamic>.from(
              jsonDecode(c['clinical_json'] as String))
          : {};
    } catch (_) {}

    final Map<String, dynamic> demo    = Map<String, dynamic>.from(clinical['demographics']       ?? {});
    final Map<String, dynamic> lesion  = Map<String, dynamic>.from(clinical['lesionHistory']      ?? {});
    final Map<String, dynamic> exam    = Map<String, dynamic>.from(clinical['clinicalExam']       ?? {});
    final Map<String, dynamic> assoc   = Map<String, dynamic>.from(clinical['associatedFindings'] ?? {});

    // Risk colours
    Color riskColor, riskBg;
    IconData riskIcon;
    if (risk.toUpperCase().contains('HIGH')) {
      riskColor = const Color(0xFFC62828);
      riskBg    = const Color(0xFFFFEBEE);
      riskIcon  = Icons.warning_rounded;
    } else if (risk.toUpperCase().contains('INTERMEDIATE')) {
      riskColor = const Color(0xFFE65100);
      riskBg    = const Color(0xFFFFF8E1);
      riskIcon  = Icons.info_rounded;
    } else if (risk.toUpperCase().contains('LOW')) {
      riskColor = const Color(0xFF2E7D32);
      riskBg    = const Color(0xFFE8F5E9);
      riskIcon  = Icons.check_circle_rounded;
    } else {
      riskColor = _muted;
      riskBg    = const Color(0xFFF7F3F0);
      riskIcon  = Icons.hourglass_empty_rounded;
    }

    final patPhoto = c['patient_photo']?.toString() ?? '';

    return Column(children: [
      _header(context, patId, doctorName, risk, riskColor),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Patient & Date strip ──────────────────────────────────────
            _patientStrip(patId, patName, dateStr, status, patPhoto),
            const SizedBox(height: 16),

            // ── Risk banner ───────────────────────────────────────────────
            _riskBanner(risk, riskScore, biopsy, conf,
                riskColor, riskBg, riskIcon),
            const SizedBox(height: 20),

            // ── Patient Trend (Clinical Progression) ──────────────────────
            _sectionTitle('Clinical Risk Progression'),
            const SizedBox(height: 12),
            _trendCard(patId),
            const SizedBox(height: 20),

            // ── Lesion Image ──────────────────────────────────────────────
            _imageCard(imagePath),
            const SizedBox(height: 20),

            // ── Key Factors ───────────────────────────────────────────────
            if (explanations.isNotEmpty) ...[
              _sectionTitle('Key Risk Factors'),
              const SizedBox(height: 10),
              _factorsCard(explanations, riskColor),
              const SizedBox(height: 20),
            ],

            // ── Differential diagnoses ─────────────────────────────────
            if (suggestions.isNotEmpty) ...[
              _sectionTitle('Differential Diagnoses'),
              const SizedBox(height: 10),
              _suggestionsCard(suggestions, riskColor),
              const SizedBox(height: 20),
            ],

            // ── Section A — Demographics ──────────────────────────────────
            _sectionTitle('A — Patient Demographics'),
            const SizedBox(height: 10),
            _clinicalCard([
              _row('Smoking Status',     demo['smokingStatus']    ?? '—'),
              if ((demo['smokingStatus'] ?? '') != 'No') ...[
                _row('Smoking Duration', '${demo['smokingDuration'] ?? '—'} yrs'),
                _row('Frequency',        demo['smokingFrequency'] ?? '—'),
              ],
              _row('Smokeless Tobacco',  _bool(demo['smokelessTobacco'])),
              _row('Alcohol Use',        demo['alcohol']          ?? '—'),
              _row('Diabetes',           _bool(demo['diabetes'])),
              _row('Immunocompromised',  _bool(demo['immunocompromised'])),
              _row('Autoimmune',         _bool(demo['autoimmune'])),
              _row('Steroids',           _bool(demo['steroids'])),
              _row('Chemotherapy',       _bool(demo['chemotherapy'])),
              _row('Immunosuppressants', _bool(demo['immunosuppressants'])),
            ]),
            const SizedBox(height: 16),

            // ── Section B — Lesion History ────────────────────────────────
            _sectionTitle('B — Lesion History'),
            const SizedBox(height: 10),
            _clinicalCard([
              _row('Duration',         lesion['duration']       ?? '—'),
              _row('Onset',            lesion['onset']          ?? '—'),
              _row('Recurrence',       lesion['recurrence']     ?? '—'),
              _row('Pain',             lesion['pain']           ?? '—'),
              _row('Healing Pattern',  lesion['healingPattern'] ?? '—'),
            ]),
            const SizedBox(height: 16),

            // ── Section C — Clinical Exam ─────────────────────────────────
            _sectionTitle('C — Clinical Examination'),
            const SizedBox(height: 10),
            _clinicalCard([
              _row('Anatomical Site',  exam['site']?.toString().replaceAll('⚠️','').trim() ?? '—'),
              _row('Lesion Size',      '${exam['size'] ?? 0} mm'),
              _row('Shape',            exam['shape']    ?? '—'),
              _row('Margins',          exam['margins']  ?? '—'),
              _row('Edge Type',        exam['edge']?.toString().replaceAll('(Risk ⚠️)','').trim() ?? '—'),
              _row('Induration',       _bool(exam['induration'])),
              _row('Bleeding on Touch',_bool(exam['bleeding'])),
            ]),
            const SizedBox(height: 16),

            // ── Section D — Associated Findings ──────────────────────────
            _sectionTitle('D — Associated Findings'),
            const SizedBox(height: 10),
            _clinicalCard([
              _row('Lymph Node Palpable', _bool(assoc['lymphPalpable'])),
              if (assoc['lymphPalpable'] == true) ...[
                _row('Node Tender',    assoc['tender']       ?? '—'),
                _row('Node Mobility',  assoc['nodeMobility'] ?? '—'),
              ],
              _row('Paraesthesia',     _bool(assoc['paraesthesia'])),
              _row('Weight Loss',      _bool(assoc['weightLoss'])),
              _row('Fever',            _bool(assoc['fever'])),
            ]),
          ]),
        ),
      ),
    ]);
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context, String patId, String doctorName,
      String risk, Color riskColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_maroonD, _maroon],
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
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Case Detail — $patId',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text('Assessed by Dr. ${doctorName}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5, fontWeight: FontWeight.w500)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withOpacity(0.4), width: 1),
              ),
              child: Text(risk,
                  style: TextStyle(color: _gold.withOpacity(0.90),
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _generatePdfReport(context, patId),
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              tooltip: 'Generate Clinical Report',
            ),
          ]),
        ),
      ),
    );
  }

  // ── Patient strip ─────────────────────────────────────────────────────────
  Widget _patientStrip(String id, String name, String date, String status, String photo) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: _maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                image: photo.isNotEmpty && !kIsWeb && File(photo).existsSync()
                  ? DecorationImage(image: FileImage(File(photo)), fit: BoxFit.cover)
                  : null),
            child: photo.isEmpty || kIsWeb || !File(photo).existsSync()
              ? Icon(Icons.person_rounded,
                  color: _maroon.withOpacity(0.7), size: 20)
              : null),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(id, style: const TextStyle(color: _text, fontSize: 14,
              fontWeight: FontWeight.w700)),
          if (name.isNotEmpty)
            Text(name, style: const TextStyle(color: _muted, fontSize: 12)),
          Text(date, style: TextStyle(color: _muted.withOpacity(0.7),
              fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'Completed'
                ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(
                color: status == 'Completed'
                    ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Risk banner ───────────────────────────────────────────────────────────
  Widget _riskBanner(String risk, double score, String biopsy, String conf,
      Color riskColor, Color riskBg, IconData riskIcon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: riskBg, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.10),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        // Gauge
        SizedBox(width: 70, height: 70,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              color: riskColor,
              backgroundColor: riskColor.withOpacity(0.12),
              strokeWidth: 7,
            ),
            Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(color: riskColor, fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(riskIcon, color: riskColor, size: 18),
            const SizedBox(width: 6),
            Text(risk, style: TextStyle(color: riskColor, fontSize: 18,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          Text(biopsy, style: TextStyle(color: riskColor.withOpacity(0.8),
              fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('AI Confidence: $conf',
              style: TextStyle(color: riskColor.withOpacity(0.55),
                  fontSize: 11)),
        ])),
      ]),
    );
  }

  // ── Image card ────────────────────────────────────────────────────────────
  Widget _imageCard(String imagePath) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Lesion Image'),
      const SizedBox(height: 10),
      Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EDE8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imagePath.isNotEmpty && !kIsWeb && File(imagePath).existsSync()
              ? Image.file(File(imagePath), fit: BoxFit.cover)
              : Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 36, color: _muted.withOpacity(0.4)),
                const SizedBox(height: 8),
                Text('No image captured',
                    style: TextStyle(color: _muted.withOpacity(0.6),
                        fontSize: 12)),
              ])),
        ),
      ),
    ]);
  }

  // ── Section title ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Row(children: [
    Container(width: 4, height: 16,
        decoration: BoxDecoration(color: _maroon,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(color: _text, fontSize: 13.5,
        fontWeight: FontWeight.w700)),
  ]);

  // ── Clinical card ─────────────────────────────────────────────────────────
  Widget _clinicalCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      children: rows.asMap().entries.map((e) {
        final isLast = e.key == rows.length - 1;
        return Column(children: [
          e.value,
          if (!isLast) Divider(height: 0, color: _border, indent: 16, endIndent: 16),
        ]);
      }).toList(),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Expanded(flex: 2, child: Text(label,
          style: TextStyle(color: _muted, fontSize: 12.5,
              fontWeight: FontWeight.w500))),
      Expanded(flex: 3, child: Text(value,
          style: const TextStyle(color: _text, fontSize: 12.5,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
    ]),
  );

  // ── Factors card ──────────────────────────────────────────────────────────
  Widget _factorsCard(List<dynamic> items, Color riskColor) => Container(
    decoration: BoxDecoration(
      color: _surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [
              Container(width: 26, height: 26,
                  decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(Icons.warning_amber_rounded,
                      color: riskColor, size: 14)),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value.toString(),
                  style: const TextStyle(color: _text, fontSize: 12.5,
                      fontWeight: FontWeight.w500))),
            ]),
          ),
          if (!isLast) Divider(height: 0, color: _border),
        ]);
      }).toList(),
    ),
  );

  // ── Suggestions card ──────────────────────────────────────────────────────
  Widget _suggestionsCard(List<dynamic> items, Color riskColor) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: riskColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: riskColor.withOpacity(0.18), width: 1),
        ),
        child: Text(s.toString(), style: TextStyle(color: riskColor,
            fontSize: 12, fontWeight: FontWeight.w600)),
      )).toList(),
    ),
  );

  // ── Trend Card ────────────────────────────────────────────────────────────
  Widget _trendCard(String patientId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalDb.instance.getPatientHistory(patientId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final history = snap.data!;
        if (history.length < 2) {
          return Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: const Text('More assessments needed to show clinical trends.', 
                textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
          );
        }

        final List<FlSpot> spots = [];
        for (int i = 0; i < history.length; i++) {
          final score = (history[i]['risk_score'] as num?)?.toDouble() ?? 0.0;
          spots.add(FlSpot(i.toDouble(), score));
        }

        return Container(
          height: 200, width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 20, 24, 10),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 25),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: _maroon,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _maroon.withOpacity(0.1),
                  ),
                ),
              ],
              minY: 0, maxY: 100,
            ),
          ),
        );
      },
    );
  }

  // ── PDF Generation ────────────────────────────────────────────────────────
  Future<void> _generatePdfReport(BuildContext context, String patientId) async {
    final history = await LocalDb.instance.getPatientHistory(patientId);
    if (history.isEmpty) return;
    
    final c = history.last; 
    final doc = pw.Document();

    // Parse clinical JSON for tables
    Map<String, dynamic> clinical = {};
    try { clinical = jsonDecode(c['clinical_json'] ?? '{}'); } catch(_) {}
    final demo   = clinical['demographics']       ?? {};
    final lesion = clinical['lesionHistory']      ?? {};
    final exam   = clinical['clinicalExam']       ?? {};
    final assoc  = clinical['associatedFindings'] ?? {};
    final factors = jsonDecode(c['risk_explanation_json'] ?? '[]');

    // Risk Color
    final risk = (c['risk_category'] ?? '').toString().toUpperCase();
    final pdfColor = risk.contains('HIGH') ? PdfColors.red900 : (risk.contains('INTER') ? PdfColors.orange900 : PdfColors.green900);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SAVEETHA DENTAL COLLEGE & HOSPITAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColor.fromInt(0xFF7B1E3A))),
                  pw.Text('Saveetha Institute of Medical & Technical Sciences', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Department of Oral Medicine and Radiology', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Text('CLINICAL REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColor.fromInt(0xFF7B1E3A), thickness: 1.5),
          pw.SizedBox(height: 20),
        ]),
        footer: (pw.Context context) => pw.Column(children: [
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Oral Ulcer AI v2.0', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ],
          ),
        ]),
        build: (pw.Context context) {
          return [
            // 1. Patient & Case Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _pdfLabelValue('Patient Name', c['patient_name'] ?? 'N/A'),
                  _pdfLabelValue('Patient ID',   patientId),
                  _pdfLabelValue('Assessed By',  'Dr. ${c['doctor_name'] ?? 'Unknown'}'),
                ])),
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _pdfLabelValue('Assessment Date', DateTime.now().toLocal().toString().split('.')[0]),
                  _pdfLabelValue('Report ID', 'SOR-${c['id']}'),
                  _pdfLabelValue('Status', c['status'] ?? 'Completed'),
                ])),
              ],
            ),

            pw.SizedBox(height: 25),

            // 2. Risk Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: pdfColor, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('AI RISK CLASSIFICATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfColor)),
                    pw.Text(risk, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pdfColor)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('SCORE: ${c['risk_score']}%', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Confidence: ${c['confidence']}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]),
                ],
              ),
            ),

            pw.SizedBox(height: 25),

            // 3. Clinical Findings Sections
            pw.Text('I. CLINICAL FINDINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Section', 'Clinical Parameters', 'Finding'],
              data: [
                ['Demographics', 'Smoking Status', demo['smokingStatus'] ?? '—'],
                ['Demographics', 'Tobacco / Alcohol', '${demo['smokelessTobacco'] == true ? "Yes" : "No"} / ${demo['alcohol'] ?? "No"}'],
                ['History', 'Lesion Duration', lesion['duration'] ?? '—'],
                ['History', 'Onset / Pain', '${lesion['onset'] ?? "—"} / ${lesion['pain'] ?? "No"}'],
                ['Exam', 'Anatomical Site', exam['site']?.toString().replaceAll('⚠️','').trim() ?? '—'],
                ['Exam', 'Size / Induration', '${exam['size'] ?? 0}mm / ${exam['induration'] == true ? "Yes" : "No"}'],
                ['Assoc.', 'Lymph Nodes', assoc['lymphPalpable'] == true ? "Palpable" : "Not Palpable"],
              ],
            ),

            pw.SizedBox(height: 25),

            // 4. AI Analysis Factors
            pw.Text('II. AI RISK LOGIC & KEY FACTORS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: factors.map<pw.Widget>((f) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Bullet(text: f.toString(), style: const pw.TextStyle(fontSize: 9)),
              )).toList(),
            ),

            pw.SizedBox(height: 25),

            // 5. Recommendations
            pw.Text('III. RECOMMENDATIONS & PLAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Text(c['biopsy_recommendation'] ?? 'Monitor and review in 2 weeks.', style: const pw.TextStyle(fontSize: 10)),
            ),

            pw.SizedBox(height: 40),

            // 6. Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)))),
                  pw.SizedBox(height: 5),
                  pw.Text('Attending Clinician', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Dr. ${c['doctor_name'] ?? '—'}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)))),
                  pw.SizedBox(height: 5),
                  pw.Text('HOD / Department Stamp', style: const pw.TextStyle(fontSize: 10)),
                ]),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Text('NOTE: This is an AI-assisted diagnostic tool. Results must be correlated with histopathological findings for definitive diagnosis.', 
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Clinical_Report_$patientId.pdf',
    );
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
      ])),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _bool(dynamic v) => v == true ? 'Yes' : 'No';
}
