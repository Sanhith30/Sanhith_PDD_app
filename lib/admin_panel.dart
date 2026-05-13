import 'package:flutter/material.dart';
import 'db/local_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN PANEL  —  Real-time SQLite data viewer
//  Shows: Clinicians, Patients, Cases
// ─────────────────────────────────────────────────────────────────────────────

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {

  // ── Palette (matches app design system) ───────────────────────────────────
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  late TabController _tabController;

  List<Map<String, dynamic>> _clinicians = [];
  List<Map<String, dynamic>> _patients   = [];
  List<Map<String, dynamic>> _cases      = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load all data from SQLite ──────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final db = await LocalDb.instance.db;

    final clinicians = await db.query('clinicians', orderBy: 'id ASC');
    final patients   = await db.query('patients',   orderBy: 'last_updated DESC');
    final cases      = await db.query('cases',      orderBy: 'created_at DESC');

    if (mounted) {
      setState(() {
        _clinicians = clinicians;
        _patients   = patients;
        _cases      = cases;
        _loading    = false;
      });
    }
  }

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  String _formatTs(int? ms) {
    if (ms == null || ms == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
          tabs: [
            Tab(text: 'USERS (${_clinicians.length})'),
            Tab(text: 'PATIENTS (${_patients.length})'),
            Tab(text: 'CASES (${_cases.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _maroon, strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCliniciansTab(),
                _buildPatientsTab(),
                _buildCasesTab(),
              ],
            ),
    );
  }

  // ── CLINICIANS TAB ────────────────────────────────────────────────────────
  Widget _buildCliniciansTab() {
    if (_clinicians.isEmpty) return _buildEmpty('No clinicians registered yet.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clinicians.length,
      itemBuilder: (_, i) {
        final c = _clinicians[i];
        return _buildCard(
          icon: Icons.person_rounded,
          iconColor: _maroon,
          iconBg: _maroon.withOpacity(0.08),
          title: c['name']?.toString() ?? '—',
          subtitle: c['email']?.toString() ?? '—',
          trailing: 'ID: ${c['id']}',
          rows: [
            _row('Name',  c['name']?.toString()     ?? '—'),
            _row('Email', c['email']?.toString()    ?? '—'),
            _row('ID',    c['id']?.toString()       ?? '—'),
            _row('Pass Hash', '••••••••••••  (SHA-256 hashed)'),
          ],
        );
      },
    );
  }

  // ── PATIENTS TAB ──────────────────────────────────────────────────────────
  Widget _buildPatientsTab() {
    if (_patients.isEmpty) return _buildEmpty('No patients added yet.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patients.length,
      itemBuilder: (_, i) {
        final p = _patients[i];
        return _buildCard(
          icon: Icons.medical_information_rounded,
          iconColor: const Color(0xFF1565C0),
          iconBg: const Color(0xFF1565C0).withOpacity(0.07),
          title: p['name']?.toString() ?? '—',
          subtitle: 'ID: ${p['patient_id']}',
          trailing: '${p['age']} yrs • ${p['sex']}',
          rows: [
            _row('Patient ID', p['patient_id']?.toString() ?? '—'),
            _row('Name',       p['name']?.toString()       ?? '—'),
            _row('Age',        '${p['age']} years'),
            _row('Sex',        p['sex']?.toString()        ?? '—'),
            _row('Last Updated', _formatTs(p['last_updated'] as int?)),
            _row('Photo',      p['photo_path']?.toString().isNotEmpty == true
                ? p['photo_path'].toString() : 'No photo'),
          ],
        );
      },
    );
  }

  // ── CASES TAB ─────────────────────────────────────────────────────────────
  Widget _buildCasesTab() {
    if (_cases.isEmpty) return _buildEmpty('No cases recorded yet.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cases.length,
      itemBuilder: (_, i) {
        final c = _cases[i];
        final risk = (c['risk_category'] ?? 'PENDING').toString().toUpperCase();
        Color riskColor;
        Color riskBg;
        if (risk.contains('HIGH')) {
          riskColor = const Color(0xFFC62828); riskBg = const Color(0xFFFFEBEE);
        } else if (risk.contains('INTERMEDIATE')) {
          riskColor = const Color(0xFFE65100); riskBg = const Color(0xFFFFF8E1);
        } else if (risk.contains('LOW')) {
          riskColor = const Color(0xFF2E7D32); riskBg = const Color(0xFFE8F5E9);
        } else {
          riskColor = _muted; riskBg = const Color(0xFFF7F3F0);
        }

        return _buildCard(
          icon: Icons.assignment_rounded,
          iconColor: riskColor,
          iconBg: riskBg,
          title: 'Patient: ${c['patient_name'] ?? c['patient_id'] ?? '—'}',
          subtitle: _formatTs(c['created_at'] as int?),
          trailing: risk,
          trailingColor: riskColor,
          rows: [
            _row('Case ID',        c['id']?.toString()             ?? '—'),
            _row('Patient ID',     c['patient_id']?.toString()     ?? '—'),
            _row('Patient Name',   c['patient_name']?.toString()   ?? '—'),
            _row('Doctor ID',      c['doctor_id']?.toString()      ?? '—'),
            _row('Status',         c['status']?.toString()         ?? '—'),
            _row('Risk Score',     '${c['risk_score'] ?? 0}'),
            _row('Risk Category',  c['risk_category']?.toString()  ?? '—'),
            _row('Confidence',     c['confidence']?.toString()     ?? '—'),
            _row('Biopsy Rec.',    c['biopsy_recommendation']?.toString() ?? '—'),
            _row('Created At',     _formatTs(c['created_at'] as int?)),
            _row('Image Path',     c['image_path']?.toString().isNotEmpty == true
                ? c['image_path'].toString() : 'No image'),
          ],
        );
      },
    );
  }

  // ── Reusable card ──────────────────────────────────────────────────────────
  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String trailing,
    Color? trailingColor,
    required List<Widget> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(color: _text, fontSize: 13.5,
                fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle,
            style: const TextStyle(color: _muted, fontSize: 11.5)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (trailingColor ?? _maroon).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(trailing,
              style: TextStyle(
                  color: trailingColor ?? _maroon,
                  fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        children: [
          Container(height: 1, color: _border,
              margin: const EdgeInsets.only(bottom: 12)),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: _muted, fontSize: 11.5,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: _text, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_rounded, size: 48, color: _muted.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: _muted.withOpacity(0.7), fontSize: 14)),
      ]),
    );
  }
}
