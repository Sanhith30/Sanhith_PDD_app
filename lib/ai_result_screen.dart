import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'db/local_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AI RESULT SCREEN  —  "Surgical Luxury"
//  Reads from local SQLite — no Firestore
// ─────────────────────────────────────────────────────────────────────────────

class AiResultScreen extends StatelessWidget {
  const AiResultScreen({super.key});

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
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(
                color: _maroon, strokeWidth: 2));
          }

          final data = snapshot.data!;

          final String category   = data['risk_category']         ?? 'UNKNOWN';
          final String recommendation = data['biopsy_recommendation'] ?? 'Consult physician';
          final String confidence = data['confidence']             ?? 'N/A';
          final String imagePath  = data['image_path']             ?? '';
          final String patientId  = data['patient_id']?.toString() ?? 'Unknown';
          final String patientName = data['patient_name']?.toString() ?? '';

          final double riskScore  = (data['risk_score'] as num?)?.toDouble() ?? 0.0;
          final double clinicalScore = (data['clinical_score'] as num?)?.toDouble() ?? 0.0;
          final double visualScore = (data['visual_score'] as num?)?.toDouble() ?? 0.0;

          final List<dynamic> explanations =
              data['risk_explanation_json'] != null
                  ? jsonDecode(data['risk_explanation_json'] as String)
                  : ['No critical clinical flags identified.'];
          final List<dynamic> suggestions =
              data['suggestions_json'] != null
                  ? jsonDecode(data['suggestions_json'] as String)
                  : [];

          // Derive colours
          Color riskColor, riskBg;
          IconData riskIcon;
          String riskLabel;

          if (category.toLowerCase().contains('high')) {
            riskColor = const Color(0xFFC62828);
            riskBg    = const Color(0xFFFFEBEE);
            riskIcon  = Icons.warning_rounded;
            riskLabel = 'HIGH RISK';
          } else if (category.toLowerCase().contains('inter') || category.toLowerCase().contains('med')) {
            riskColor = const Color(0xFFE65100);
            riskBg    = const Color(0xFFFFF8E1);
            riskIcon  = Icons.info_rounded;
            riskLabel = 'INTERMEDIATE';
          } else {
            riskColor = const Color(0xFF2E7D32);
            riskBg    = const Color(0xFFE8F5E9);
            riskIcon  = Icons.check_circle_rounded;
            riskLabel = 'LOW RISK';
          }

          return Column(children: [
            _buildHeader(context, riskColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _buildRiskBanner(
                    riskLabel: riskLabel, recommendation: recommendation,
                    confidence: confidence, riskColor: riskColor,
                    riskBg: riskBg, riskIcon: riskIcon,
                  ),
                  const SizedBox(height: 20),
                  _buildScoreGauges(clinicalScore, visualScore, riskScore, riskColor),
                  const SizedBox(height: 20),
                  _buildPatientStrip(patientId, patientName),
                  const SizedBox(height: 20),
                  _buildImageCard(imagePath),
                  const SizedBox(height: 20),
                  _buildFactorsCard(explanations, riskColor),
                  const SizedBox(height: 20),
                  if (suggestions.isNotEmpty)
                    _buildSuggestionsCard(suggestions, riskColor),
                ]),
              ),
            ),
            _buildReturnButton(context),
          ]);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color riskColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_maroonD, _maroon],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 4),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('AI Triage Results', style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              Text('Clinical Decision Support', style: TextStyle(
                  color: Colors.white.withOpacity(0.60), fontSize: 11.5)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withOpacity(0.4), width: 1),
              ),
              child: Text('Completed', style: TextStyle(
                  color: _gold.withOpacity(0.90), fontSize: 10,
                  fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRiskBanner({
    required String riskLabel, required String recommendation,
    required String confidence, required Color riskColor,
    required Color riskBg, required IconData riskIcon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskBg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.10),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(riskIcon, color: riskColor, size: 22),
          const SizedBox(width: 8),
          Text(riskLabel, style: TextStyle(color: riskColor, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        Container(height: 1, color: riskColor.withOpacity(0.15)),
        const SizedBox(height: 10),
        Text('Biopsy: $recommendation', textAlign: TextAlign.center,
            style: TextStyle(color: riskColor.withOpacity(0.85),
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('AI Confidence: $confidence',
            style: TextStyle(color: riskColor.withOpacity(0.60), fontSize: 11.5)),
      ]),
    );
  }

  Widget _buildScoreGauges(double clinical, double visual, double combined, Color riskColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildGauge(label: 'Clinical', percent: clinical,
            color: _gold, isLarge: false),
        Container(width: 1, height: 70, color: _border),
        _buildGauge(label: 'Image AI', percent: visual,
            color: Colors.blueAccent, isLarge: false),
        Container(width: 1, height: 70, color: _border),
        _buildGauge(label: 'Combined', percent: combined,
            color: riskColor, isLarge: true),
      ]),
    );
  }

  Widget _buildGauge({
    required String label, required double percent,
    required Color color, required bool isLarge,
    bool isNA = false,
  }) {
    final double size = isLarge ? 90 : 72;
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(width: size, height: size,
            child: CircularProgressIndicator(
              value: isNA ? 0 : (percent / 100).clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withOpacity(0.10),
              strokeWidth: isLarge ? 8 : 6,
            )),
        Text(isNA ? 'N/A' : '${percent.toStringAsFixed(1)}%',
            style: TextStyle(color: isNA ? _muted : _text,
                fontSize: isLarge ? 15 : 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: _muted, fontSize: 11.5,
          fontWeight: FontWeight.w500)),
      if (isNA)
        Text('Coming soon',
            style: TextStyle(color: _muted.withOpacity(0.5),
                fontSize: 9, letterSpacing: 0.3)),
    ]);
  }

  Widget _buildPatientStrip(String patientId, String patientName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.person_rounded,
                color: _maroon.withOpacity(0.7), size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(patientId, style: const TextStyle(color: _text, fontSize: 13.5,
              fontWeight: FontWeight.w700)),
          if (patientName.isNotEmpty)
            Text(patientName, style: const TextStyle(color: _muted, fontSize: 11.5)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withOpacity(0.30), width: 1)),
          child: Text('Assessed', style: TextStyle(
              color: _gold.withOpacity(0.85), fontSize: 10,
              fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildImageCard(String imagePath) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Lesion Image', style: TextStyle(color: _text, fontSize: 14,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        height: 220, width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EDE8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: imagePath.isNotEmpty && !kIsWeb && File(imagePath).existsSync()
              ? Image.file(File(imagePath), fit: BoxFit.cover)
              : Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 40, color: _muted.withOpacity(0.4)),
                const SizedBox(height: 8),
                Text('No image captured',
                    style: TextStyle(color: _muted.withOpacity(0.6),
                        fontSize: 12)),
              ])),
        ),
      ),
    ]);
  }

  Widget _buildFactorsCard(List<dynamic> explanations, Color riskColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Key Contributing Factors', style: TextStyle(color: _text,
          fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(
          children: explanations.asMap().entries.map((e) {
            final isLast = e.key == explanations.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.warning_amber_rounded,
                          color: riskColor, size: 15)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value.toString(),
                      style: const TextStyle(color: _text, fontSize: 13,
                          fontWeight: FontWeight.w500))),
                ]),
              ),
              if (!isLast) Divider(height: 0, color: _border),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildSuggestionsCard(List<dynamic> suggestions, Color riskColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Differential Diagnoses', style: TextStyle(color: _text,
          fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border)),
        child: Wrap(
          spacing: 8, runSpacing: 8,
          children: suggestions.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: riskColor.withOpacity(0.18), width: 1),
            ),
            child: Text(s.toString(), style: TextStyle(
                color: riskColor.withOpacity(0.85), fontSize: 12,
                fontWeight: FontWeight.w600)),
          )).toList(),
        ),
      ),
    ]);
  }

  Widget _buildReturnButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: BoxDecoration(color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1))),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_maroon, _maroonD],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _maroon.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Center(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Return to Dashboard', style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w600)),
                ],
              )),
            ),
          ),
        ),
      ),
    );
  }
}