import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class RiskResult {
  final double score;          // Combined score (0-100)
  final double clinicalScore;  // Clinical only
  final double visualScore;    // Image only
  final String category;       // "High" | "Intermediate" | "Low"
  final String recommendation;
  final String confidence;
  final List<String> explanation;
  final List<String> suggestions;

  const RiskResult({
    required this.score,
    required this.clinicalScore,
    required this.visualScore,
    required this.category,
    required this.recommendation,
    required this.confidence,
    required this.explanation,
    required this.suggestions,
  });

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    return RiskResult(
      score: (json['clinicalRiskScore'] as num?)?.toDouble() ?? 0.0,
      clinicalScore: (json['clinicalRiskScore'] as num?)?.toDouble() ?? 0.0,
      visualScore: 0.0, // Clinical-only endpoint
      category: json['clinicalRiskCategory']?.toString() ?? 'Pending',
      recommendation: json['biopsyRecommendation']?.toString() ?? '',
      confidence: json['confidence']?.toString() ?? '',
      explanation: List<String>.from(json['riskExplanation'] ?? []),
      suggestions: List<String>.from(json['clinicalSuggestions'] ?? []),
    );
  }
}

class RiskScorer {
  // 🏠 LOCAL MODE (College Submission Ready)
  static const String apiUrl = 'http://10.19.181.87:5000/predict';

  static Future<RiskResult> predictFull({
    required int caseId,
    required Map<String, dynamic> clinicalData,
    required File imageFile,
  }) async {
    final uri = Uri.parse('http://10.19.181.87:5000/predict_full');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Bypass-Tunnel-Reminder': 'true',
    });

    request.fields['case_id'] = caseId.toString();
    request.fields['clinical_json'] = jsonEncode(clinicalData);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RiskResult(
          score: (data['finalRiskScore'] as num?)?.toDouble() ?? 0.0,
          clinicalScore: (data['clinicalRiskScore'] as num?)?.toDouble() ?? 0.0,
          visualScore: (data['visualRiskScore'] as num?)?.toDouble() ?? 0.0,
          category: data['riskCategory']?.toString() ?? 'Pending',
          recommendation: data['biopsyRecommendation']?.toString() ?? '',
          confidence: data['confidence']?.toString() ?? '',
          explanation: List<String>.from(data['riskExplanation'] ?? []),
          suggestions: List<String>.from(data['clinicalSuggestions'] ?? []),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return RiskResult(
        score: 0.0,
        clinicalScore: 0.0,
        visualScore: 0.0,
        category: 'ERROR',
        recommendation: 'Failed to connect for multi-modal analysis: $e',
        confidence: 'N/A',
        explanation: ['Connection Error'],
        suggestions: ['Check server connection'],
      );
    }
  }

  static Future<RiskResult> score({
    required int    age,
    required String sex,
    required String smokingStatus,
    required int    smokingDuration,
    required String smokingFrequency,
    required bool   smokelessTobacco,
    required String alcohol,
    required bool   diabetes,
    required bool   immunocompromised,
    required bool   autoimmune,
    required bool   steroids,
    required bool   chemotherapy,
    required bool   immunosuppressants,
    required String duration,
    required String onset,
    required String recurrence,
    required String pain,
    required String healingPattern,
    required String site,
    required int    sizeMm,
    required String shape,
    required String margins,
    required String edge,
    required bool   induration,
    required bool   bleeding,
    required bool   lymphPalpable,
    required String tender,
    required String nodeMobility,
    required bool   paraesthesia,
    required bool   weightLoss,
    required bool   fever,
  }) async {
    
    final payload = {
      "age": age, "sex": sex, "smoking_status": smokingStatus,
      "smoking_duration": smokingDuration, "smoking_frequency": smokingFrequency,
      "smokeless_tobacco": smokelessTobacco ? 1 : 0, "alcohol": alcohol,
      "diabetes": diabetes ? 1 : 0, "immunocompromised": immunocompromised ? 1 : 0,
      "autoimmune": autoimmune ? 1 : 0, "steroids": steroids ? 1 : 0,
      "chemotherapy": chemotherapy ? 1 : 0, "immunosuppressants": immunosuppressants ? 1 : 0,
      "duration": duration, "onset": onset, "recurrence": recurrence, "pain": pain,
      "healing_pattern": healingPattern, "site": site, "size_mm": sizeMm,
      "shape": shape, "margins": margins, "edge": edge, "induration": induration ? 1 : 0,
      "bleeding": bleeding ? 1 : 0, "lymph_palpable": lymphPalpable ? 1 : 0,
      "tender": tender.toLowerCase() == 'yes' ? 1 : 0, "node_mobility": nodeMobility,
      "paraesthesia": paraesthesia ? 1 : 0, "weight_loss": weightLoss ? 1 : 0, "fever": fever ? 1 : 0,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return RiskResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      return RiskResult(
        score: 0.0,
        clinicalScore: 0.0,
        visualScore: 0.0,
        category: 'ERROR',
        recommendation: 'Connection Error',
        confidence: 'N/A',
        explanation: ['Error: $e'],
        suggestions: ['Check server'],
      );
    }
  }
}
