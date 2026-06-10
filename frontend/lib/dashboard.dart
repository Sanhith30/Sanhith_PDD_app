import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'db/local_db.dart';
import 'db/session.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _allCases = [];
  List<Map<String, dynamic>> _uniquePatients = [];
  bool _loading = true;
  
  // ── Surgical Luxury Palette ────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF7B1E3A); // Brand Maroon
  static const Color _depth     = Color(0xFF5C1028); // Deep Maroon
  static const Color _accent    = Color(0xFFC9A84C); // Warm Gold
  static const Color _bg        = Color(0xFFFAF7F4); // Ivory Background
  static const Color _surface   = Color(0xFFFFFFFF); // Pure White
  static const Color _text      = Color(0xFF1E0A10); // Near-black Maroon
  static const Color _muted     = Color(0xFF9E8A8F); // Warm Muted Text

  bool _compactView = false;
  List<String> _dismissedNotifications = [];
  List<Map<String, dynamic>> _activeNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    final prefs = await SharedPreferences.getInstance();
    final compact = prefs.getBool('pref_compact_view') ?? false;
    final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // Load dismissed notifications list
    final dismissedList = prefs.getStringList('pref_dismissed_notifications') ?? [];
    
    // Deduplicate to find Unique Patients (latest case for each)
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in cases) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }

    final uniquePatients = uniqueMap.values.toList();

    // Dynamically generate clinician notifications
    final List<Map<String, dynamic>> notifications = [];

    // 1. High Risk Case Alerts
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

    // 2. Milestones Alerts
    final totalCasesCount = uniquePatients.length;
    final highCasesCount = uniquePatients.where((c) =>
        (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH')).length;

    final hasBronze = totalCasesCount >= 1;
    final hasSilver = totalCasesCount >= 5;
    final hasGold = highCasesCount >= 2;

    if (hasBronze && !dismissedList.contains('milestone_rookie')) {
      notifications.add({
        'key': 'milestone_rookie',
        'type': 'milestone',
        'title': 'Milestone Achieved',
        'body': 'Unlocked: "Screening Rookie" milestone badge is active.',
        'icon': Icons.shield_outlined,
        'color': const Color(0xFFCD7F32), // Bronze
      });
    }
    if (hasSilver && !dismissedList.contains('milestone_veteran')) {
      notifications.add({
        'key': 'milestone_veteran',
        'type': 'milestone',
        'title': 'Milestone Achieved',
        'body': 'Unlocked: "Diagnostic Veteran" milestone badge is active.',
        'icon': Icons.emoji_events_outlined,
        'color': const Color(0xFFC0C0C0), // Silver
      });
    }
    if (hasGold && !dismissedList.contains('milestone_sentinel')) {
      notifications.add({
        'key': 'milestone_sentinel',
        'type': 'milestone',
        'title': 'Milestone Achieved',
        'body': 'Unlocked: "Risk Sentinel" milestone badge is active.',
        'icon': Icons.local_fire_department_outlined,
        'color': _accent,
      });
    }

    // 3. Cloud Database Status Alert
    final latency = await LocalDb.instance.pingServer();
    if (latency != null && !dismissedList.contains('sync_online')) {
      notifications.add({
        'key': 'sync_online',
        'type': 'sync',
        'title': 'Clinical Portal Connected',
        'body': 'Successfully connected to PostgreSQL FastAPI backend (latency: ${latency}ms).',
        'icon': Icons.cloud_done_rounded,
        'color': Colors.green,
      });
    }

    if (mounted) {
      setState(() {
        _compactView = compact;
        _allCases = cases;
        _uniquePatients = uniquePatients;
        _dismissedNotifications = dismissedList;
        _activeNotifications = notifications;
        _loading = false;
      });
    }
  }

  Future<void> _dismissNotification(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(_dismissedNotifications);
    if (!list.contains(key)) {
      list.add(key);
    }
    await prefs.setStringList('pref_dismissed_notifications', list);
    if (mounted) {
      setState(() {
        _dismissedNotifications = list;
        _activeNotifications.removeWhere((item) => item['key'] == key);
      });
    }
  }

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_rounded, color: _accent, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "CLINICAL ALERTS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ),
                  
                  // Body
                  Expanded(
                    child: _activeNotifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_rounded, color: _muted.withOpacity(0.3), size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  "No active notifications",
                                  style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            itemCount: _activeNotifications.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _activeNotifications[index];
                              return Dismissible(
                                key: Key(item['key']),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                                ),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) async {
                                  final String key = item['key'];
                                  await _dismissNotification(key);
                                  setModalState(() {});
                                },
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (item['color'] as Color).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
                                  ),
                                  title: Text(
                                    item['title'] as String,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _text),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item['body'] as String,
                                      style: const TextStyle(fontSize: 11, color: _muted, height: 1.3),
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
                                  onTap: () {
                                    Navigator.pop(context); // Close bottom sheet
                                    if (item['type'] == 'high_risk') {
                                      Navigator.pushNamed(context, '/case_detail', arguments: item['caseId']).then((_) {
                                        _loadCases();
                                      });
                                    } else if (item['type'] == 'milestone') {
                                      Navigator.pushNamed(context, '/profile').then((_) {
                                        _loadCases();
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildDoctorGreeting(),
                      const SizedBox(height: 24),
                      _buildNewCaseCTA(),
                      const SizedBox(height: 32),
                      _buildStatsRow(),
                      const SizedBox(height: 32),
                      _buildSectionTitle("RECENT ASSESSMENTS"),
                      const SizedBox(height: 16),
                      _buildRecentList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: null,
        ),
      ],
    );
  }

  // ── COMPONENTS ─────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_depth, _primary],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -20,
                child: Icon(Icons.medical_services_outlined, 
                  color: Colors.white.withOpacity(0.05), size: 180),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "DR. ${Session.instance.displayName.toUpperCase()}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _getFormattedDate(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 24),
                                    onPressed: _showNotificationsBottomSheet,
                                  ),
                                  if (_activeNotifications.isNotEmpty)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: _accent,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 14,
                                          minHeight: 14,
                                        ),
                                        child: Text(
                                          '${_activeNotifications.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/profile').then((_) {
                                  if (mounted) setState(() {});
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: _buildDoctorAvatar(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "GOOD MORNING";
    if (hour < 17) return "GOOD AFTERNOON";
    return "GOOD EVENING";
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    final days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    return "${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}";
  }

  Widget _buildDoctorGreeting() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: _accent, size: 16),
          SizedBox(width: 10),
          Text(
            "AI SYSTEM ONLINE",
            style: TextStyle(
              color: _accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          Spacer(),
          Icon(Icons.check_circle, color: Colors.green, size: 14),
        ],
      ),
    );
  }

  Widget _buildNewCaseCTA() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/new_case').then((_) => _loadCases()),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _depth],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.add_circle, color: Colors.white.withOpacity(0.05), size: 140),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "New Case Assessment",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Begin AI diagnostic scoring",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: _accent, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final highCount = _uniquePatients.where((c) => (c['risk_category'] ?? '').toString().contains('High')).length;
    final medCount  = _uniquePatients.where((c) => (c['risk_category'] ?? '').toString().contains('Intermediate')).length;

    return Row(
      children: [
        _buildStatPill("PATIENTS", _uniquePatients.length.toString(), _primary),
        const SizedBox(width: 8),
        _buildStatPill("CASES", _allCases.length.toString(), _muted),
        const SizedBox(width: 8),
        _buildStatPill("HIGH RISK", highCount.toString(), Colors.red),
        const SizedBox(width: 8),
        _buildStatPill("FOLLOW-UP", medCount.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: _muted, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_uniquePatients.isEmpty) return const Center(child: Text("No assessments yet", style: TextStyle(color: _muted)));

    return Column(
      children: _uniquePatients.take(5).map((c) => _buildRecentCard(c)).toList(),
    );
  }

  Widget _buildRecentCard(Map<String, dynamic> c) {
    final String risk = (c['risk_category'] ?? 'Low').toString();
    final Color riskColor = risk.contains('High') ? Colors.red : (risk.contains('Intermediate') ? Colors.orange : Colors.green);

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/case_detail', arguments: c['id']).then((_) => _loadCases()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: _compactView ? 6 : 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: _compactView ? 8 : 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _text.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _bg,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _buildPatientAvatar(c['patient_photo']),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['patient_name'] ?? "Anonymous", style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text("ID: ${c['patient_id']}", style: const TextStyle(color: _muted, fontSize: 10)),
                      const SizedBox(width: 8),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: _muted, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text("Dr. ${c['doctor_name'] ?? 'Unknown'}", style: TextStyle(color: _primary.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                risk.toUpperCase(),
                style: TextStyle(color: riskColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.5,
      ),
    );
  }

  Widget _buildPatientAvatar(String? photo) {
    if (photo == null || photo.isEmpty) {
      return const Icon(Icons.person_outline, color: _muted);
    }
    if (photo.startsWith('/static') || photo.startsWith('http')) {
      final String fullUrl = photo.startsWith('http')
          ? photo
          : '${LocalDb.baseUrl}$photo';
      return Image.network(
        fullUrl,
        headers: const {'Bypass-Tunnel-Reminder': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person_outline, color: _muted),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: _primary),
            ),
          );
        },
      );
    } else if (!kIsWeb && File(photo).existsSync()) {
      return Image.file(File(photo), fit: BoxFit.cover);
    } else {
      return const Icon(Icons.person_outline, color: _muted);
    }
  }

  Widget _buildDoctorAvatar() {
    final path = Session.instance.photoPath;
    if (path == null || path.isEmpty) {
      return const Icon(Icons.person_rounded, color: _accent, size: 22);
    }
    if (path.startsWith('/static') || path.startsWith('http')) {
      final String fullUrl = path.startsWith('http')
          ? path
          : '${LocalDb.baseUrl}$path';
      return Image.network(
        fullUrl,
        headers: const {'Bypass-Tunnel-Reminder': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person_rounded, color: _accent, size: 22),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent),
            ),
          );
        },
      );
    } else if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    } else {
      return const Icon(Icons.person_rounded, color: _accent, size: 22);
    }
  }
}