import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  API SERVICE  —  Now connects to PostgreSQL FastAPI Backend
//  Replaces local SQLite database logic
// ─────────────────────────────────────────────────────────────────────────────

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  
  // 🏠 LOCAL MODE (College Submission Ready)
  // Use your computer's Local IP for physical devices:
  static const String baseUrl = 'http://10.19.181.87:5000'; 
  // Use 'http://10.0.2.2:5000' if testing on the Android Emulator

  // Dummy db accessor to prevent breaking main.dart
  Future<void> get db async {}

  // ══════════════════════════════════════════════════════════════════════════
  //  APP SETTINGS / ONBOARDING
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_done') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLINICIAN / AUTH
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = data['user'] as Map<String, dynamic>;
        user['token'] = data['access_token'];
        return user;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> signUp(String name, String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = data['user'] as Map<String, dynamic>;
        user['token'] = data['access_token'];
        // Mark as new signup for tour
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_tour_next', true);
        return user;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> requestPasswordReset(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/reset_password'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmPasswordReset(String email, String otp, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/confirm_password_reset'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  
  Future<bool> changePassword(String email, String oldPassword, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/change_password'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({
          'email': email,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProfilePhoto(String photoPath) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/clinicians/profile_photo'),
        headers: _headers,
        body: jsonEncode({'photo_path': photoPath}),
      );
      if (res.statusCode == 200) {
        Session.instance.photoPath = photoPath;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Map<String, String> get _headers {
    final token = Session.instance.token;
    final Map<String, String> h = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
    if (token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PATIENTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getPatient(String patientId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/patients/$patientId'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> savePatient({
    required String patientId,
    required String name,
    required int age,
    required String sex,
    String photoPath = '',
    Map<String, dynamic> clinicalData = const {},
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/patients'),
        headers: _headers,
        body: jsonEncode({
          'patient_id': patientId,
          'name': name,
          'age': age,
          'sex': sex,
          'photo_path': photoPath,
          'clinical_json': jsonEncode(clinicalData),
          'doctor_id': Session.instance.doctorId,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CASES
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertCase({
    required String patientId,
    required String patientName,
    required String doctorId,
    required Map<String, dynamic> clinicalData,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/cases'),
        headers: _headers,
        body: jsonEncode({
          'patient_id': patientId,
          'patient_name': patientName,
          'doctor_id': doctorId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'clinical_json': jsonEncode(clinicalData),
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['id'] as int;
      }
    } catch (_) {}
    return -1;
  }

  Future<void> completeCase({
    required int caseId,
    required String imagePath,
    required double riskScore,
    double clinicalScore = 0.0,
    double visualScore = 0.0,
    required String riskCategory,
    required String biopsyRecommendation,
    required String confidence,
    required List<String> riskExplanation,
    required List<String> clinicalSuggestions,
  }) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/cases/$caseId/complete'),
        headers: _headers,
        body: jsonEncode({
          'image_path': imagePath,
          'risk_score': riskScore,
          'clinical_score': clinicalScore,
          'visual_score': visualScore,
          'risk_category': riskCategory,
          'biopsy_recommendation': biopsyRecommendation,
          'confidence': confidence,
          'risk_explanation_json': jsonEncode(riskExplanation),
          'suggestions_json': jsonEncode(clinicalSuggestions),
        }),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getCase(int caseId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cases/$caseId'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getCases(String doctorId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cases'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getPatientHistory(String patientId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/patients/$patientId/history'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ── APP TOUR STATE ────────────────────────────────────────────────────────
  Future<bool> isTourDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('tour_done') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markTourDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tour_done', true);
    } catch (_) {}
  }
}
