import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'db/local_db.dart';
import 'db/session.dart';
import 'dart:ui' as ui;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _allCases = [];
  List<Map<String, dynamic>> _uniquePatients = [];
  bool _loading = true;
  
  // Removed Tour state (moved to MainScaffold)

  // ── Surgical Luxury Palette ────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF7B1E3A); // Brand Maroon
  static const Color _depth     = Color(0xFF5C1028); // Deep Maroon
  static const Color _accent    = Color(0xFFC9A84C); // Warm Gold
  static const Color _bg        = Color(0xFFFAF7F4); // Ivory Background
  static const Color _surface   = Color(0xFFFFFFFF); // Pure White
  static const Color _text      = Color(0xFF1E0A10); // Near-black Maroon
  static const Color _muted     = Color(0xFF9E8A8F); // Warm Muted Text

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    // 1. Fetch ALL cases (Backend already returns the latest per patient for the global list, 
    // but we might want to distinguish between unique patients and total assessments if needed)
    final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // 2. Deduplicate to find Unique Patients (latest case for each)
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in cases) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }

    if (mounted) {
      setState(() {
        _allCases = cases; // All assessments
        _uniquePatients = uniqueMap.values.toList(); // Latest case per patient
        _loading = false;
      });
    }
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
                              IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 24),
                                onPressed: () {},
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/profile'),
                                child: CircleAvatar(
                                  backgroundColor: _accent.withOpacity(0.2),
                                  radius: 20,
                                  child: const Icon(Icons.person_rounded, color: _accent, size: 22),
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
    final lowCount  = _uniquePatients.where((c) => (c['risk_category'] ?? '').toString().contains('Low')).length;

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
      onTap: () => Navigator.pushNamed(context, '/case_detail', arguments: c['id']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _text.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _bg,
              backgroundImage: c['patient_photo'] != null && c['patient_photo']!.isNotEmpty && !ui.window.physicalSize.isEmpty
                ? FileImage(File(c['patient_photo']))
                : null,
              child: c['patient_photo'] == null || c['patient_photo']!.isEmpty
                ? Icon(Icons.person_outline, color: _muted)
                : null,
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
}