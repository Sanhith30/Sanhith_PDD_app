import 'dart:convert';
import 'package:flutter/material.dart';
import '../db/local_db.dart';

class WebAiResultScreen extends StatelessWidget {
  const WebAiResultScreen({super.key});

  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _red     = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final int caseId = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('AI Diagnostic Results', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
              label: const Text('RETURN TO DASHBOARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: LocalDb.instance.getCase(caseId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _maroon));
          }

          final data = snapshot.data!;
          final String category = data['risk_category'] ?? 'UNKNOWN';
          final String recommendation = data['biopsy_recommendation'] ?? 'Consult physician';
          final String confidence = data['confidence'] ?? 'N/A';
          final String imagePath = data['image_path'] ?? '';
          final String patientId = data['patient_id']?.toString() ?? 'Unknown';
          final String patientName = data['patient_name']?.toString() ?? '';

          final double riskScore = (data['risk_score'] as num?)?.toDouble() ?? 0.0;
          final double clinicalScore = (data['clinical_score'] as num?)?.toDouble() ?? 0.0;
          final double visualScore = (data['visual_score'] as num?)?.toDouble() ?? 0.0;

          final List<dynamic> explanations = data['risk_explanation_json'] != null
              ? jsonDecode(data['risk_explanation_json'] as String)
              : ['No critical clinical flags identified.'];
          final List<dynamic> suggestions = data['suggestions_json'] != null
              ? jsonDecode(data['suggestions_json'] as String)
              : [];

          Color riskColor, riskBg;
          IconData riskIcon;
          if (category.toLowerCase().contains('high')) {
            riskColor = _red;
            riskBg = const Color(0xFFFFEBEE);
            riskIcon = Icons.warning_rounded;
          } else if (category.toLowerCase().contains('inter') || category.toLowerCase().contains('med')) {
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
                // Left Column: Triage statistics
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      _buildRiskBanner(category, recommendation, confidence, riskColor, riskBg, riskIcon),
                      const SizedBox(height: 24),
                      _buildScoreGauges(clinicalScore, visualScore, riskScore, riskColor),
                      const SizedBox(height: 24),
                      _buildPatientCard(patientId, patientName, imagePath),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Right Column: Factors & Suggestions
                Expanded(
                  flex: 13,
                  child: Column(
                    children: [
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                category.toUpperCase(),
                style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: color.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            'Biopsy Guideline: $recommendation',
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.85), fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'AI Diagnostic Confidence: $confidence',
            style: TextStyle(color: color.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGauges(double clinical, double visual, double combined, Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGauge('Clinical AI', clinical, _gold),
          Container(width: 1, height: 80, color: _border),
          _buildGauge('Visual AI', visual, Colors.blueAccent),
          Container(width: 1, height: 80, color: _border),
          _buildGauge('Combined Risk', combined, color, isLarge: true),
        ],
      ),
    );
  }

  Widget _buildGauge(String label, double percent, Color color, {bool isLarge = false}) {
    final double size = isLarge ? 96 : 80;
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
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(color: _text, fontSize: isLarge ? 16 : 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPatientCard(String id, String name, String photo) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Diagnosed Patient File', style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.badge_outlined, color: _gold, size: 18),
              const SizedBox(width: 12),
              Text('Patient UHID: $id', style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, color: _gold, size: 18),
              const SizedBox(width: 12),
              Text('Full Name: $name', style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          if (photo.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                width: double.infinity,
                color: _bg,
                child: Image.network(LocalDb.resolveUrl(photo), fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard(List<dynamic> factors, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Risk Explanations', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Main diagnostic triggers causing higher severity index.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 24),
          ...factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: color, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f.toString(), style: const TextStyle(color: _text, fontSize: 14))),
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
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Differentials', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Potential conditions based on symptoms & visual AI.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 24),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added_outlined, color: _gold, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.toString(), style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
