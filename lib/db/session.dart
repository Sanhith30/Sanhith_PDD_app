import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SESSION  —  In-memory logged-in clinician state
//  Replaces: FirebaseAuth.instance.currentUser
// ─────────────────────────────────────────────────────────────────────────────

class Session {
  Session._();
  static final Session instance = Session._();

  int?    id;
  String? name;
  String? email;
  String? token; 
  String? photoPath;

  bool get isLoggedIn => id != null && token != null;

  void set(Map<String, dynamic> clinician) {
    id    = clinician['id'] as int;
    name  = clinician['name'] as String;
    email = clinician['email'] as String;
    photoPath = clinician['photo_path'] as String? ?? "";
    if (clinician.containsKey('token')) {
      token = clinician['token'] as String;
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('active_session', jsonEncode(clinician));
    });
  }

  void clear() {
    id    = null;
    name  = null;
    email = null;
    token = null;
    photoPath = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('active_session');
    });
  }

  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStr = prefs.getString('active_session');
      if (sessionStr != null && sessionStr.isNotEmpty) {
        final clinician = jsonDecode(sessionStr) as Map<String, dynamic>;
        id    = clinician['id'] as int;
        name  = clinician['name'] as String;
        email = clinician['email'] as String;
        photoPath = clinician['photo_path'] as String? ?? "";
        if (clinician.containsKey('token')) {
          token = clinician['token'] as String;
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  String get doctorId    => id?.toString() ?? '';
  String get displayName => name ?? 'Clinician';
  String get initial     => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';
}

