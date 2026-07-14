import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebDashboardPage extends StatefulWidget {
  const WebDashboardPage({super.key});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  List<Map<String, dynamic>> _uniquePatients = [];
  bool _loading = true;
  String _searchQuery = "";
  String _riskFilter = "All";

  static const Color _primary   = Color(0xFF7B1E3A);
  static const Color _accent    = Color(0xFFC9A84C);
  static const Color _bg        = Color(0xFFFAF7F4);
  static const Color _surface   = Color(0xFFFFFFFF);
  static const Color _text      = Color(0xFF1E0A10);
  static const Color _muted     = Color(0xFF9E8A8F);
  static const Color _border    = Color(0xFFE8DDD8);

  List<Map<String, dynamic>> _activeNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    final prefs = await SharedPreferences.getInstance();
    final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
    final dismissedList = prefs.getStringList('pref_dismissed_notifications') ?? [];

    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in cases) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    final uniquePatients = uniqueMap.values.toList();

    // Notifications
    final List<Map<String, dynamic>> notifications = [];
    for (final c in uniquePatients) {
      final risk = (c['risk_category'] ?? '').toString();
      final caseId = c['id']?.toString() ?? '';
      final patientName = c['patient_name'] ?? 'Anonymous';
      final key = 'high_risk_$caseId';

      if (risk.toUpperCase().contains('HIGH') && !dismissedList.contains(key)) {
        notifications.add({
          'key': key,
          'type': 'high_risk',
          'title': 'Urgent: High Risk Case',
          'body': 'Biopsy recommendation and follow-up needed for $patientName.',
          'icon': Icons.warning_rounded,
          'color': Colors.red,
          'caseId': c['id'],
        });
      }
    }

    if (mounted) {
      setState(() {
        _uniquePatients = uniquePatients;
        _activeNotifications = notifications;
        _loading = false;
      });
    }
  }

  Future<void> _dismissNotification(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('pref_dismissed_notifications') ?? [];
    list.add(key);
    await prefs.setStringList('pref_dismissed_notifications', list);
    setState(() {
      _activeNotifications.removeWhere((item) => item['key'] == key);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    // Stats
    final totalCases = _uniquePatients.length;
    final highRisk = _uniquePatients.where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH')).length;
    final intRisk = _uniquePatients.where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains('INTERMEDIATE') || (c['risk_category'] ?? '').toString().toUpperCase().contains('MODERATE')).length;
    final lowRisk = totalCases - highRisk - intRisk;

    // Filters & Search
    final filteredPatients = _uniquePatients.where((c) {
      final name = (c['patient_name'] ?? '').toString().toLowerCase();
      final pid = (c['patient_id'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || pid.contains(_searchQuery.toLowerCase());
      
      if (_riskFilter == "All") return matchesSearch;
      final category = (c['risk_category'] ?? '').toString().toUpperCase();
      if (_riskFilter == "High") return matchesSearch && category.contains("HIGH");
      if (_riskFilter == "Intermediate") return matchesSearch && (category.contains("INTERMEDIATE") || category.contains("MODERATE"));
      if (_riskFilter == "Low") return matchesSearch && category.contains("LOW");
      return matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 32),

          // Stat Cards
          Row(
            children: [
              _buildStatCard('Total Patients', totalCases.toString(), Icons.people_outline_rounded, _primary),
              const SizedBox(width: 24),
              _buildStatCard('High Risk Alerts', highRisk.toString(), Icons.error_outline_rounded, Colors.red),
              const SizedBox(width: 24),
              _buildStatCard('Intermediate Cases', intRisk.toString(), Icons.warning_amber_rounded, Colors.orange),
              const SizedBox(width: 24),
              _buildStatCard('Low Risk Cases', lowRisk.toString(), Icons.check_circle_outline_rounded, Colors.green),
            ],
          ),
          const SizedBox(height: 32),

          // Notifications Section if any
          if (_activeNotifications.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _activeNotifications.map((n) => _buildNotificationBanner(n)).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Search and Filters
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search patients by name or ID...',
                      hintStyle: TextStyle(color: _muted.withOpacity(0.55)),
                      prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _buildFilterChip('All'),
              const SizedBox(width: 10),
              _buildFilterChip('High'),
              const SizedBox(width: 10),
              _buildFilterChip('Intermediate'),
              const SizedBox(width: 10),
              _buildFilterChip('Low'),
            ],
          ),
          const SizedBox(height: 24),

          // Patients List / Table
          Expanded(
            child: filteredPatients.isEmpty
                ? _buildEmptyState()
                : Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: filteredPatients.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: _border),
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          return _buildPatientRow(patient);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clinician Dashboard',
              style: TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome, ${Session.instance.displayName}. Monitor and assess patient diagnostic cases.',
              style: const TextStyle(color: _muted, fontSize: 14.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: _primary.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: const TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBanner(Map<String, dynamic> n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: (n['color'] as Color).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (n['color'] as Color).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(n['icon'] as IconData, color: n['color'] as Color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: _text, fontSize: 13.5),
                children: [
                  TextSpan(text: '${n['title']}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: n['body'] as String),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (n['caseId'] != null)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/case_detail', arguments: n['caseId']);
              },
              child: const Text('Review', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            onPressed: () => _dismissNotification(n['key'] as String),
            icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _riskFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _riskFilter = label);
        }
      },
      selectedColor: _primary,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _muted,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: selected ? _primary : _border),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    );
  }

  Widget _buildPatientRow(Map<String, dynamic> patient) {
    final riskCategory = (patient['risk_category'] ?? 'Pending').toString();
    final double riskScore = double.tryParse(patient['risk_score']?.toString() ?? '') ?? 0.0;
    
    Color riskColor = _muted;
    if (riskCategory.toUpperCase().contains('HIGH')) {
      riskColor = Colors.red;
    } else if (riskCategory.toUpperCase().contains('INTERMEDIATE') || riskCategory.toUpperCase().contains('MODERATE')) {
      riskColor = Colors.orange;
    } else if (riskCategory.toUpperCase().contains('LOW')) {
      riskColor = Colors.green;
    }

    return ListTile(
      onTap: () {
        Navigator.pushNamed(context, '/case_detail', arguments: patient['id']);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _bg,
          shape: BoxShape.circle,
          image: patient['patient_photo'] != null && patient['patient_photo'].toString().isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(LocalDb.resolveUrl(patient['patient_photo'].toString())),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: patient['patient_photo'] == null || patient['patient_photo'].toString().isEmpty
            ? const Icon(Icons.person_rounded, color: _muted)
            : null,
      ),
      title: Text(
        patient['patient_name'] ?? 'Anonymous Patient',
        style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          'Patient ID: ${patient['patient_id']}',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: riskColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(
              riskCategory,
              style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 20),
          Text(
            '${riskScore.toStringAsFixed(1)}%',
            style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(width: 20),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF7F3F0)),
            child: const Icon(Icons.medical_services_outlined, size: 48, color: _muted),
          ),
          const SizedBox(height: 20),
          const Text('No diagnostic cases found', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Create a new case from the sidebar to get started.', style: TextStyle(color: _muted, fontSize: 13.5)),
        ],
      ),
    );
  }
}
