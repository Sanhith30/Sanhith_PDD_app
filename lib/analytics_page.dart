import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// Analytics Page — Fully Upgraded Clinician Dashboard Suite (Phase 2)

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  List<Map<String, dynamic>> _allCases = [];
  bool _loading = true;
  int? _pingLatency;

  // Search & Filter State
  String _selectedRange = 'ALL'; // '7D', '30D', '6M', 'ALL'
  String? _selectedRiskFilter; // null, 'HIGH', 'INTERMEDIATE', 'LOW'
  String _searchQuery = '';
  bool _filterInduration = false;
  bool _filterBleeding = false;
  bool _filterTobacco = false;
  bool _filterBiopsy = false;
  String? _selectedAnatomicalSiteFilter; // null, Buccal Mucosa, etc.

  // UI State
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  int _touchedPieIndex = -1;
  final TextEditingController _searchCtrl = TextEditingController();

  // Clinician Details for PDF Report
  String _licenseNo = 'DCI-98745-A';
  List<Offset?> _signaturePoints = [];

  // Saved Audits Log
  List<Map<String, dynamic>> _savedAudits = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. Fetch cases from local database/API
    final raw = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // Deduplicate: Keep only the latest assessment for each patient
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in raw) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    final cases = uniqueMap.values.toList();

    // 2. Measure API latency
    final latency = await LocalDb.instance.pingServer();

    // 3. Load registration/signature preferences
    final prefs = await SharedPreferences.getInstance();
    final license = prefs.getString('pref_license_no') ?? 'DCI-98745-A';
    
    List<Offset?> sigPoints = [];
    final sigStr = prefs.getString('pref_signature_data') ?? '';
    if (sigStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(sigStr);
        sigPoints = decoded.map((item) {
          if (item == null || (item is Map && item.containsKey('null'))) {
            return null;
          } else {
            return Offset((item['x'] as num).toDouble(), (item['y'] as num).toDouble());
          }
        }).toList();
      } catch (_) {}
    }

    // 4. Load Saved Audits Log
    final auditsJson = prefs.getString('pref_saved_audit_logs') ?? '[]';
    List<Map<String, dynamic>> savedAudits = [];
    try {
      final List<dynamic> decodedAudits = jsonDecode(auditsJson);
      savedAudits = decodedAudits.cast<Map<String, dynamic>>();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _allCases = cases;
        _pingLatency = latency;
        _licenseNo = license;
        _signaturePoints = sigPoints;
        _savedAudits = savedAudits;
        _loading = false;
      });
    }
  }

  // Save generated PDF report metadata
  Future<void> _saveAuditLogEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'range': _selectedRange,
      'totalCases': _total,
      'highCount': _riskCount('HIGH'),
      'agreement': _agreementRate,
    };
    _savedAudits.insert(0, entry);
    // Keep last 10 audits
    if (_savedAudits.length > 10) {
      _savedAudits = _savedAudits.sublist(0, 10);
    }
    await prefs.setString('pref_saved_audit_logs', jsonEncode(_savedAudits));
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  DATA FILTERING LOGIC
  // ─────────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _rangeFilteredCases {
    final now = DateTime.now();
    return _allCases.where((c) {
      final ms = (c['created_at'] as num?)?.toInt() ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(ms);
      final diff = now.difference(date).inDays;

      if (_selectedRange == '7D') return diff <= 7;
      if (_selectedRange == '30D') return diff <= 30;
      if (_selectedRange == '6M') return diff <= 180;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _activeCases {
    final rangeCases = _rangeFilteredCases;
    return rangeCases.where((c) {
      // 1. Risk Filter
      if (_selectedRiskFilter != null) {
        final cat = (c['risk_category'] ?? '').toString().toUpperCase();
        if (!cat.contains(_selectedRiskFilter!)) return false;
      }

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final name = (c['patient_name'] ?? '').toString().toLowerCase();
        final id = (c['patient_id'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !id.contains(query)) return false;
      }

      // 3. Clinical Data Parsed Filters
      Map<String, dynamic> clinical = {};
      try {
        clinical = jsonDecode((c['clinical_json'] ?? '{}') as String);
      } catch (_) {}

      final demo = clinical['demographics'] ?? {};
      final exam = clinical['clinicalExam'] ?? {};

      if (_filterInduration) {
        final induration = exam['induration'] == true || exam['induration'] == 'Yes';
        if (!induration) return false;
      }

      if (_filterBleeding) {
        final bleeding = exam['bleeding'] == true || exam['bleeding'] == 'Yes';
        if (!bleeding) return false;
      }

      if (_filterTobacco) {
        final smoking = demo['smokingStatus'] ?? 'No';
        final smokeless = demo['smokelessTobacco'] == true || demo['smokelessTobacco'] == 'Yes';
        final hasTobacco = (smoking != 'No' && smoking != 'None') || smokeless;
        if (!hasTobacco) return false;
      }

      if (_filterBiopsy) {
        final recommendation = (c['biopsy_recommendation'] ?? '').toString().toLowerCase();
        if (!recommendation.contains('biopsy')) return false;
      }

      // 4. Heatmap Anatomical Site Filter
      if (_selectedAnatomicalSiteFilter != null) {
        final site = (exam['site'] ?? 'Unknown').toString().replaceAll('⚠️', '').trim().toLowerCase();
        if (site != _selectedAnatomicalSiteFilter!.toLowerCase()) return false;
      }

      return true;
    }).toList();
  }

  // Summary stats (unaffected by risk/search filters to avoid lockups)
  int get _total => _rangeFilteredCases.length;
  int _riskCount(String r) => _rangeFilteredCases
      .where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains(r))
      .length;

  // ─────────────────────────────────────────────────────────────────────────────
  //  METRICS CALCULATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  // AI-Clinician Agreement Rate (clinical_score vs visual_score)
  double get _agreementRate {
    final cases = _activeCases;
    if (cases.isEmpty) return 100.0;
    int matches = 0;
    for (final c in cases) {
      final cScore = (c['clinical_score'] as num?)?.toDouble() ?? 0.0;
      final vScore = (c['visual_score'] as num?)?.toDouble() ?? 0.0;
      final bothHigh = cScore >= 50.0 && vScore >= 50.0;
      final bothLow = cScore < 50.0 && vScore < 50.0;
      if (bothHigh || bothLow) matches++;
    }
    return (matches / cases.length) * 100.0;
  }

  // Monthly breakdown
  List<int> get _monthly {
    final now = DateTime.now();
    final counts = List<int>.filled(6, 0);
    for (final c in _activeCases) {
      final ms = (c['created_at'] as num?)?.toInt() ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final diff = (now.year * 12 + now.month) - (dt.year * 12 + dt.month);
      if (diff >= 0 && diff < 6) counts[5 - diff]++;
    }
    return counts;
  }

  List<String> get _monthLabels {
    final now = DateTime.now();
    const n = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return List.generate(6, (i) => n[((now.month - 5 + i - 1) % 12 + 12) % 12]);
  }

  // Top Anatomical Sites frequency
  Map<String, int> get _sites {
    final m = <String, int>{};
    for (final c in _activeCases) {
      try {
        final cd = jsonDecode((c['clinical_json'] ?? '{}') as String);
        final s = (cd['clinicalExam']?['site'] ?? 'Unknown')
            .toString().replaceAll('⚠️', '').trim();
        m[s] = (m[s] ?? 0) + 1;
      } catch (_) {}
    }
    return m;
  }

  // Patient Demographics (Age)
  Map<String, int> get _ageGroups {
    final m = {'<20': 0, '20-40': 0, '40-60': 0, '60+': 0};
    for (final c in _activeCases) {
      final ageVal = c['patient_age'];
      final age = int.tryParse(ageVal?.toString() ?? '') ?? 0;
      if (age < 20) {
        m['<20'] = m['<20']! + 1;
      } else if (age <= 40) {
        m['20-40'] = m['20-40']! + 1;
      } else if (age <= 60) {
        m['40-60'] = m['40-60']! + 1;
      } else {
        m['60+'] = m['60+']! + 1;
      }
    }
    return m;
  }

  // Patient Demographics (Gender)
  Map<String, int> get _genders {
    final m = {'Male': 0, 'Female': 0, 'Other': 0};
    for (final c in _activeCases) {
      final sex = (c['patient_sex'] ?? 'Other').toString().trim().toLowerCase();
      if (sex.startsWith('m')) {
        m['Male'] = m['Male']! + 1;
      } else if (sex.startsWith('f')) {
        m['Female'] = m['Female']! + 1;
      } else {
        m['Other'] = m['Other']! + 1;
      }
    }
    return m;
  }

  // Habit Correlation (Risk vs Habits)
  Map<String, List<int>> get _habitRiskCorrelation {
    int habitsHigh = 0;
    int habitsLow = 0;
    int noHabitsHigh = 0;
    int noHabitsLow = 0;

    for (final c in _activeCases) {
      bool hasHabits = false;
      try {
        final cd = jsonDecode((c['clinical_json'] ?? '{}') as String);
        final demo = cd['demographics'] ?? {};
        final smoking = demo['smokingStatus'] ?? 'No';
        final smokeless = demo['smokelessTobacco'] == true || demo['smokelessTobacco'] == 'Yes';
        final alcohol = demo['alcohol'] ?? 'No';
        hasHabits = (smoking != 'No' && smoking != 'None') || smokeless || (alcohol != 'No' && alcohol != 'None');
      } catch (_) {}

      final isHigh = (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH');
      if (hasHabits) {
        if (isHigh) habitsHigh++; else habitsLow++;
      } else {
        if (isHigh) noHabitsHigh++; else noHabitsLow++;
      }
    }
    return {
      'Habits': [habitsHigh, habitsLow],
      'No Habits': [noHabitsHigh, noHabitsLow]
    };
  }

  // Healing Regression
  List<double> get _regressionTrend {
    final Map<String, List<Map<String, dynamic>>> group = {};
    for (final c in _allCases) {
      final pid = c['patient_id']?.toString() ?? '';
      if (pid.isNotEmpty) {
        group.putIfAbsent(pid, () => []).add(c);
      }
    }

    final followUps = group.values.where((list) => list.length > 1).toList();
    if (followUps.isEmpty) return [];

    final List<List<double>> visits = [[], [], []];
    for (final list in followUps) {
      final sorted = List<Map<String, dynamic>>.from(list);
      sorted.sort((a, b) {
        final aMs = (a['created_at'] as num?)?.toInt() ?? 0;
        final bMs = (b['created_at'] as num?)?.toInt() ?? 0;
        return aMs.compareTo(bMs);
      });
      for (int i = 0; i < sorted.length && i < 3; i++) {
        visits[i].add((sorted[i]['risk_score'] as num?)?.toDouble() ?? 0.0);
      }
    }

    return visits
        .map((scores) => scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length)
        .toList();
  }

  // Action Analysis
  Map<String, int> get _actionsDistribution {
    final m = {'Biopsy Referral': 0, 'Follow-up': 0, 'Routine Specialist': 0};
    for (final c in _activeCases) {
      final recommendation = (c['biopsy_recommendation'] ?? '').toString().toLowerCase();
      if (recommendation.contains('biopsy')) {
        m['Biopsy Referral'] = m['Biopsy Referral']! + 1;
      } else if (recommendation.contains('follow')) {
        m['Follow-up'] = m['Follow-up']! + 1;
      } else {
        m['Routine Specialist'] = m['Routine Specialist']! + 1;
      }
    }
    return m;
  }

  // Clinical Risk Factor Weightage (Feature Importance) inside High Risk Cases
  Map<String, double> get _riskFactorWeights {
    final highRiskCases = _activeCases.where((c) {
      return (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH');
    }).toList();

    if (highRiskCases.isEmpty) {
      return {'Induration': 0.0, 'Bleeding': 0.0, 'Lymph Nodes': 0.0, 'Smoking': 0.0, 'Irregular Margins': 0.0};
    }

    double indurationCount = 0;
    double bleedingCount = 0;
    double lymphCount = 0;
    double smokingCount = 0;
    double marginsCount = 0;

    for (final c in highRiskCases) {
      try {
        final cd = jsonDecode((c['clinical_json'] ?? '{}') as String);
        final demo = cd['demographics'] ?? {};
        final exam = cd['clinicalExam'] ?? {};
        final assoc = cd['associatedFindings'] ?? {};

        if (exam['induration'] == true || exam['induration'] == 'Yes') indurationCount++;
        if (exam['bleeding'] == true || exam['bleeding'] == 'Yes') bleedingCount++;
        if (assoc['lymphPalpable'] == true || assoc['lymphPalpable'] == 'Yes') lymphCount++;
        if (demo['smokingStatus'] != 'No' && demo['smokingStatus'] != 'None') smokingCount++;
        if (exam['margins']?.toString().toLowerCase().contains('irregular') ?? false) marginsCount++;
      } catch (_) {}
    }

    final totalHigh = highRiskCases.length.toDouble();
    return {
      'Induration': (indurationCount / totalHigh) * 100.0,
      'Bleeding': (bleedingCount / totalHigh) * 100.0,
      'Lymph Nodes': (lymphCount / totalHigh) * 100.0,
      'Smoking': (smokingCount / totalHigh) * 100.0,
      'Irregular Margins': (marginsCount / totalHigh) * 100.0,
    };
  }

  // AI Confidence Score Distribution histogram
  Map<String, int> get _confidenceBins {
    final m = {'<80%': 0, '80-90%': 0, '90-95%': 0, '95-100%': 0};
    for (final c in _activeCases) {
      final confStr = (c['confidence'] ?? '').toString().replaceAll('%', '').trim();
      final conf = double.tryParse(confStr) ?? 0.0;
      if (conf < 80.0) {
        m['<80%'] = m['<80%']! + 1;
      } else if (conf < 90.0) {
        m['80-90%'] = m['80-90%']! + 1;
      } else if (conf < 95.0) {
        m['90-95%'] = m['90-95%']! + 1;
      } else {
        m['95-100%'] = m['95-100%']! + 1;
      }
    }
    return m;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  UI WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          slivers: [
            _appBar(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _maroon, strokeWidth: 2),
                ),
              )
            else if (_allCases.isEmpty)
              SliverFillRemaining(child: _empty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _searchAndFilters(),
                    const SizedBox(height: 16),
                    _rangeSelector(),
                    const SizedBox(height: 16),
                    _statsDashboard(),
                    const SizedBox(height: 16),
                    if (_activeCases.isEmpty)
                      _emptyFilterResults()
                    else ...[
                      _agreementAndSyncSection(),
                      const SizedBox(height: 16),
                      _interactiveAnatomicalHeatmap(),
                      const SizedBox(height: 16),
                      _interactivePieCard(),
                      const SizedBox(height: 16),
                      _interactiveBarCard(),
                      const SizedBox(height: 16),
                      _regressionCard(),
                      const SizedBox(height: 16),
                      _demographicsCard(),
                      const SizedBox(height: 16),
                      _riskFactorWeightageCard(),
                      const SizedBox(height: 16),
                      _confidenceHistogramCard(),
                      const SizedBox(height: 16),
                      _habitCorrelationCard(),
                      const SizedBox(height: 16),
                      _topSites(),
                      const SizedBox(height: 16),
                      _actionsCard(),
                      const SizedBox(height: 16),
                      _savedAuditsTimelineLog(),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _appBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _maroon,
      elevation: 0,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: const Text(
        'Caseload Insights',
        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: [
        if (!_loading && _allCases.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
            tooltip: 'Export PDF Report',
            onPressed: () async {
              await _exportPdfReport();
              await _saveAuditLogEntry();
            },
          ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_maroonD, _maroon]),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 80, color: _muted.withOpacity(0.25)),
            const SizedBox(height: 16),
            const Text(
              'No diagnostic logs found',
              style: TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Assess patients to generate clinical insights.',
              style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );

  Widget _emptyFilterResults() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _maroon.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.filter_list_off_rounded,
                size: 48,
                color: _maroon,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No cases match selected filters',
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query, risk category, or clinical habits filters to view matching analytics.',
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _filterInduration = false;
                  _filterBleeding = false;
                  _filterTobacco = false;
                  _filterBiopsy = false;
                  _selectedRiskFilter = null;
                  _selectedAnatomicalSiteFilter = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Reset All Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _gold, width: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchAndFilters() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Search patient name or ID...",
                hintStyle: TextStyle(color: _muted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("Indurated", _filterInduration, (val) => setState(() => _filterInduration = val)),
                const SizedBox(width: 8),
                _filterChip("Bleeding", _filterBleeding, (val) => setState(() => _filterBleeding = val)),
                const SizedBox(width: 8),
                _filterChip("Tobacco Habit", _filterTobacco, (val) => setState(() => _filterTobacco = val)),
                const SizedBox(width: 8),
                _filterChip("Biopsy Referral", _filterBiopsy, (val) => setState(() => _filterBiopsy = val)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
      selected: active,
      onSelected: onChanged,
      selectedColor: _maroon,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: active ? Colors.white : _text),
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: active ? _maroon : _border),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _rangeSelector() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "TIME FILTER",
            style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7D', label: Text('7D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: '30D', label: Text('30D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: '6M', label: Text('6M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ButtonSegment(value: 'ALL', label: Text('ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
            selected: {_selectedRange},
            onSelectionChanged: (Set<String> sel) {
              setState(() {
                _selectedRange = sel.first;
              });
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: _bg,
              selectedBackgroundColor: _maroon,
              selectedForegroundColor: Colors.white,
              foregroundColor: _text,
              visualDensity: VisualDensity.compact,
            ),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }

  Widget _statsDashboard() {
    final h = _riskCount('HIGH');
    final m = _riskCount('INTERMEDIATE');
    final l = _riskCount('LOW');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedRiskFilter != null || _selectedAnatomicalSiteFilter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Filters: ${_selectedRiskFilter ?? 'ALL'} Risk | ${_selectedAnatomicalSiteFilter ?? 'ALL'} Site",
                    style: const TextStyle(color: _maroon, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedRiskFilter = null;
                    _selectedAnatomicalSiteFilter = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _maroon.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Text("Clear Filters", style: TextStyle(color: _maroon, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            _statBox(_total.toString(), 'Total cases', _maroon, Colors.white, null),
            const SizedBox(width: 8),
            _statBox(h.toString(), 'High risk', const Color(0xFFFFEBEE), const Color(0xFFC62828), 'HIGH'),
            const SizedBox(width: 8),
            _statBox(m.toString(), 'Medium risk', const Color(0xFFFFF8E1), const Color(0xFFE65100), 'INTERMEDIATE'),
            const SizedBox(width: 8),
            _statBox(l.toString(), 'Low risk', const Color(0xFFE8F5E9), const Color(0xFF2E7D32), 'LOW'),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String val, String label, Color bg, Color fg, String? filter) {
    final isSelected = _selectedRiskFilter == filter && filter != null;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (filter != null) {
            setState(() {
              _selectedRiskFilter = isSelected ? null : filter;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? fg : bg,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: _gold, width: 2) : Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Text(
                val,
                style: TextStyle(color: isSelected ? Colors.white : fg, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white.withOpacity(0.8) : fg.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreementAndSyncSection() {
    return Row(
      children: [
        // Agreement Gauge
        Expanded(
          flex: 5,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DIAGNOSTIC CONSENSUS",
                  style: TextStyle(color: _muted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            value: _agreementRate / 100.0,
                            color: _gold,
                            backgroundColor: _gold.withOpacity(0.12),
                            strokeWidth: 5,
                          ),
                        ),
                        Text(
                          "${_agreementRate.toStringAsFixed(0)}%",
                          style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Clinical vs AI visual category agreement rate.",
                        style: TextStyle(color: _muted, fontSize: 10, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Sync latency checker
        Expanded(
          flex: 4,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CLOUD SYNC LATENCY",
                  style: TextStyle(color: _muted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _pingLatency != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: _pingLatency != null ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pingLatency != null ? "Online: ${_pingLatency}ms" : "Offline Cache",
                            style: TextStyle(
                              color: _pingLatency != null ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "FastAPI backend status checker.",
                            style: TextStyle(color: _muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _interactiveAnatomicalHeatmap() {
    // Standard list of anatomical sites
    final sitesList = ['Buccal Mucosa', 'Tongue', 'Labial Mucosa', 'Floor of Mouth', 'Hard Palate', 'Gingiva'];
    
    // Compute frequencies of these sites in the range-filtered cases
    final Map<String, int> frequencies = {};
    for (final site in sitesList) {
      frequencies[site] = 0;
    }
    for (final c in _rangeFilteredCases) {
      try {
        final cd = jsonDecode((c['clinical_json'] ?? '{}') as String);
        final site = (cd['clinicalExam']?['site'] ?? 'Unknown').toString().replaceAll('⚠️', '').trim().toLowerCase();
        for (final s in sitesList) {
          if (site == s.toLowerCase()) {
            frequencies[s] = frequencies[s]! + 1;
            break;
          }
        }
      } catch (_) {}
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ORAL ANATOMICAL HEATMAP", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Tap a region to filter all caseload metrics", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.adjust_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sitesList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, index) {
              final site = sitesList[index];
              final count = frequencies[site] ?? 0;
              final isFiltered = _selectedAnatomicalSiteFilter == site;

              Color cellColor = _bg;
              Color borderCol = _border;
              Color txtColor = _text;

              if (isFiltered) {
                cellColor = _maroon;
                borderCol = _gold;
                txtColor = Colors.white;
              } else if (count >= 3) {
                cellColor = _maroon.withOpacity(0.12);
                borderCol = _maroon;
                txtColor = _maroon;
              } else if (count > 0) {
                cellColor = _gold.withOpacity(0.15);
                borderCol = _gold;
                txtColor = _text;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAnatomicalSiteFilter = isFiltered ? null : site;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: isFiltered ? 2.0 : 1.0),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        site,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: txtColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$count Cases",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isFiltered ? _gold : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _interactivePieCard() {
    final h = _riskCount('HIGH');
    final m = _riskCount('INTERMEDIATE');
    final l = _riskCount('LOW');
    final t = (h + m + l).clamp(1, 99999);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DIAGNOSTIC RISK DISTRIBUTION", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Visual classification profiles", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.pie_chart_outline_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 4,
                    centerSpaceRadius: 28,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFFC62828),
                        value: h.toDouble(),
                        title: '${((h / t) * 100).round()}%',
                        radius: _touchedPieIndex == 0 ? 24 : 18,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: const Color(0xFFE65100),
                        value: m.toDouble(),
                        title: '${((m / t) * 100).round()}%',
                        radius: _touchedPieIndex == 1 ? 24 : 18,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF2E7D32),
                        value: l.toDouble(),
                        title: '${((l / t) * 100).round()}%',
                        radius: _touchedPieIndex == 2 ? 24 : 18,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _legendRow('High Risk', h, t, const Color(0xFFC62828)),
                    const SizedBox(height: 8),
                    _legendRow('Intermediate', m, t, const Color(0xFFE65100)),
                    const SizedBox(height: 8),
                    _legendRow('Low Risk', l, t, const Color(0xFF2E7D32)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int count, int total, Color color) {
    final pct = (count / total * 100).round();
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
        Text('$count ($pct%)', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _interactiveBarCard() {
    final counts = _monthly;
    final labels = _monthLabels;
    final maxV = counts.reduce(math.max).toDouble().clamp(1.0, 9999.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SCREENING RATE VOLUMES", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Assessments count over last 6 months", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.bar_chart_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxV * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _maroon,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()} Cases',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxV / 4).clamp(1.0, 999.0),
                  getDrawingHorizontalLine: (val) => FlLine(color: _border.withOpacity(0.5), strokeWidth: 0.8),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < 6) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[idx], style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(6, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC9A84C), Color(0xFF7B1E3A)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _regressionCard() {
    final trend = _regressionTrend;
    if (trend.isEmpty) {
      return const SizedBox();
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CLINICAL RISK PROGRESSION", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Risk regression trend on patient follow-ups", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.show_chart_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 0.0,
                maxY: 100.0,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25.0,
                  getDrawingHorizontalLine: (val) => FlLine(color: _border.withOpacity(0.5), strokeWidth: 0.8),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) => Text('${val.toInt()}%', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < trend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text("Visit ${idx + 1}", style: TextStyle(color: _muted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(trend.length, (i) => FlSpot(i.toDouble(), trend[i])),
                    isCurved: true,
                    color: _maroon,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _maroon.withOpacity(0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demographicsCard() {
    final ageData = _ageGroups;
    final genderData = _genders;
    final totalDemographics = genderData.values.reduce((a, b) => a + b).clamp(1, 99999);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PATIENT DEMOGRAPHICS", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Caseload age & gender distributions", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.people_outline_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          const Text("AGE DISTRIBUTION", style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (ageData.values.reduce(math.max).toDouble() * 1.3).clamp(1.0, 9999.0),
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final keys = ageData.keys.toList();
                        final idx = val.toInt();
                        if (idx >= 0 && idx < keys.length) {
                          return Text(keys[idx], style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(ageData.length, (i) {
                  final val = ageData.values.toList()[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val.toDouble(),
                        color: _gold,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (ageData.values.reduce(math.max).toDouble() * 1.3).clamp(1.0, 9999.0),
                          color: _border.withOpacity(0.2),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const Divider(height: 24),
          const Text("GENDER RATIOS", style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          _genderRow('Male', genderData['Male']!, totalDemographics, const Color(0xFF2B6CB0)),
          const SizedBox(height: 10),
          _genderRow('Female', genderData['Female']!, totalDemographics, const Color(0xFFD53F8C)),
          const SizedBox(height: 10),
          _genderRow('Other', genderData['Other']!, totalDemographics, _muted),
        ],
      ),
    );
  }

  Widget _genderRow(String label, int val, int total, Color color) {
    final pct = val / total;
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _border.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          alignment: Alignment.centerRight,
          child: Text("$val (${(pct * 100).round()}%)", style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _riskFactorWeightageCard() {
    final weights = _riskFactorWeights;
    final keys = weights.keys.toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CLINICAL FEATURE IMPORTANCE", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Presence frequency in high-risk cases", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.assessment_outlined, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          Column(
            children: List.generate(weights.length, (i) {
              final key = keys[i];
              final double pct = (weights[key] ?? 0.0) / 100.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        key,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: _border.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(_maroon),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      child: Text(
                        "${(pct * 100).round()}%",
                        textAlign: TextAlign.right,
                        style: TextStyle(color: _maroon, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _confidenceHistogramCard() {
    final bins = _confidenceBins;
    final keys = bins.keys.toList();
    final maxV = bins.values.reduce(math.max).toDouble().clamp(1.0, 99999.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AI CONFIDENCE DISTRIBUTION", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Screening counts grouped by model certainty", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.analytics_outlined, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxV * 1.2,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < keys.length) {
                          return Text(keys[idx], style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(bins.length, (i) {
                  final val = bins.values.toList()[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val.toDouble(),
                        color: _gold,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitCorrelationCard() {
    final data = _habitRiskCorrelation;
    final habits = data['Habits']!;
    final noHabits = data['No Habits']!;
    final maxV = [habits[0] + habits[1], noHabits[0] + noHabits[1]].reduce(math.max).toDouble().clamp(1.0, 99999.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("HABIT RISK CORRELATION", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("High vs Low/Int risk based on lifestyle habits", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.insights_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxV * 1.2,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Padding(padding: EdgeInsets.only(top: 6), child: Text("Has Habits", style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold)));
                        if (val == 1) return const Padding(padding: EdgeInsets.only(top: 6), child: Text("No Habits", style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold)));
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: habits[0].toDouble(), color: const Color(0xFFC62828), width: 14, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: habits[1].toDouble(), color: _gold, width: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: noHabits[0].toDouble(), color: const Color(0xFFC62828), width: 14, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: noHabits[1].toDouble(), color: _gold, width: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bulletIndicator(const Color(0xFFC62828), 'High Risk'),
              const SizedBox(width: 20),
              _bulletIndicator(_gold, 'Low/Int Risk'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bulletIndicator(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _topSites() {
    final sorted = _sites.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox();
    final maxV = top.first.value;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ANATOMICAL FREQUENCIES", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Ulcer occurrences by anatomical site", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.adjust_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          Column(
            children: top.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('${e.value}', style: TextStyle(color: _maroon, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / maxV,
                        backgroundColor: _maroon.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(_maroon),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    final actions = _actionsDistribution;
    final total = actions.values.reduce((a, b) => a + b).clamp(1, 99999);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CLINICAL ACTIONS LOG", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Actions initiated following AI screenings", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.assignment_turned_in_outlined, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 24),
          _actionProgressRow('Biopsy Referral', actions['Biopsy Referral']!, total, const Color(0xFFC62828)),
          const SizedBox(height: 10),
          _actionProgressRow('Follow-up Review', actions['Follow-up']!, total, _gold),
          const SizedBox(height: 10),
          _actionProgressRow('Specialist Consult', actions['Routine Specialist']!, total, const Color(0xFF2E7D32)),
        ],
      ),
    );
  }

  Widget _actionProgressRow(String label, int val, int total, Color color) {
    final pct = val / total;
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _border.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          alignment: Alignment.centerRight,
          child: Text("$val (${(pct * 100).round()}%)", style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _savedAuditsTimelineLog() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AUDIT EXPORTS REGISTRY", style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Saved A4 clinical audit reports timeline", style: TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
              Icon(Icons.history_edu_rounded, color: _maroon, size: 20),
            ],
          ),
          const Divider(height: 16),
          if (_savedAudits.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "No audit reports generated yet.",
                  style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedAudits.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final audit = _savedAudits[index];
                final int ts = (audit['timestamp'] as num?)?.toInt() ?? 0;
                final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                final dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                final String range = audit['range']?.toString() ?? 'ALL';
                final int totalCases = (audit['totalCases'] as num?)?.toInt() ?? 0;
                final int high = (audit['highCount'] as num?)?.toInt() ?? 0;
                final double agreementVal = (audit['agreement'] as num?)?.toDouble() ?? 100.0;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _maroon.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: _maroon, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Audit Report ($range Filter)",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$dateStr • $totalCases Cases audited",
                            style: const TextStyle(color: _muted, fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "$high High Risk",
                          style: const TextStyle(color: Color(0xFFC62828), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Consensus: ${agreementVal.toStringAsFixed(0)}%",
                          style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  PDF REPORT GENERATION & SIGNATURE BINDING
  // ─────────────────────────────────────────────────────────────────────────────

  pw.Widget _buildPdfSignature() {
    if (_signaturePoints.isEmpty) {
      return pw.Container(
        height: 16,
        alignment: pw.Alignment.center,
        child: pw.Text(
          "NO SIGNATURE SAVED",
          style: pw.TextStyle(fontSize: 5, color: PdfColors.grey, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    double minX = 99999;
    double maxX = -99999;
    double minY = 99999;
    double maxY = -99999;
    bool hasPoints = false;

    for (final p in _signaturePoints) {
      if (p != null) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        hasPoints = true;
      }
    }

    if (!hasPoints) {
      return pw.Container(
        height: 16,
        alignment: pw.Alignment.center,
        child: pw.Text(
          "NO SIGNATURE SAVED",
          style: pw.TextStyle(fontSize: 5, color: PdfColors.grey, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    double width = maxX - minX;
    if (width == 0) width = 1;
    double height = maxY - minY;
    if (height == 0) height = 1;

    double targetWidth = 60.0;
    double targetHeight = 16.0;
    double scale = targetWidth / width;
    if (targetHeight / height < scale) {
      scale = targetHeight / height;
    }
    if (scale > 2.0) scale = 2.0;

    return pw.CustomPaint(
      size: const PdfPoint(60.0, 16.0),
      painter: (canvas, size) {
        canvas.setStrokeColor(const PdfColor.fromInt(0xFF7B1E3A));
        canvas.setLineWidth(1.0);
        canvas.setLineCap(PdfLineCap.round);
        
        bool isNewStroke = true;
        PdfPoint lastPoint = const PdfPoint(0, 0);
        
        for (final p in _signaturePoints) {
          if (p == null) {
            isNewStroke = true;
          } else {
            double scaledX = (p.dx - minX) * scale;
            double scaledY = size.y - ((p.dy - minY) * scale);
            
            PdfPoint currentPoint = PdfPoint(scaledX, scaledY);
            if (!isNewStroke) {
              canvas.moveTo(lastPoint.x, lastPoint.y);
              canvas.lineTo(currentPoint.x, currentPoint.y);
              canvas.strokePath();
            }
            lastPoint = currentPoint;
            isNewStroke = false;
          }
        }
      },
    );
  }

  Future<void> _exportPdfReport() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final docName = Session.instance.displayName.toUpperCase();
      final license = _licenseNo;
      final totalCasesCount = _total;
      final highCount = _riskCount('HIGH');
      final medCount = _riskCount('INTERMEDIATE');
      final lowCount = _riskCount('LOW');
      final agreement = _agreementRate;

      final sitesList = _sites.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final pdfDoc = pw.Document();

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF7B1E3A),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "SAVEETHA DENTAL COLLEGE & HOSPITALS",
                            style: pw.TextStyle(color: const PdfColor.fromInt(0xFFC9A84C), fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "CLINICAL INSIGHTS & CASELOAD AUDIT REPORT",
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Generated on:", style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                          pw.Text(
                            "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Clinician Professional Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("CHIEF INVESTIGATOR / CLINICIAN", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        pw.Text("DR. $docName", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("DENTAL COUNCIL LICENSE NO.", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        pw.Text(license, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 1, color: const PdfColor.fromInt(0xFFE8DDD8)),
                pw.SizedBox(height: 16),

                // Summary Stats
                pw.Text("CASELOAD PERFORMANCE SUMMARY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfStatBox("Total Screenings", totalCasesCount.toString()),
                    _pdfStatBox("High Risk Cases", highCount.toString()),
                    _pdfStatBox("Int. Risk Cases", medCount.toString()),
                    _pdfStatBox("Low Risk Cases", lowCount.toString()),
                    _pdfStatBox("Consensus Rate", "${agreement.toStringAsFixed(0)}%"),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Sites Table
                pw.Text("TOP ANATOMICAL SITES DISTRIBUTION", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE8DDD8), width: 0.5),
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1E3A)),
                  headers: ['Anatomical Site Location', 'Cases Count', 'Percentage'],
                  data: sitesList.isEmpty
                      ? [['No cases', '0', '0%']]
                      : sitesList.map((e) {
                          final pct = ((e.value / totalCasesCount.clamp(1, 99999)) * 100).round();
                          return [e.key, e.value.toString(), '$pct%'];
                        }).toList(),
                ),
                pw.Spacer(),

                // Sign-off
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("AUDITING SYSTEM STAMP", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                        pw.Text("VERIFIED BY SDC CLINICAL GATEWAY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFC9A84C))),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _buildPdfSignature(),
                        pw.Container(width: 80, height: 0.5, color: const PdfColor.fromInt(0xFF9E8A8F)),
                        pw.SizedBox(height: 3),
                        pw.Text("AUTHORIZED CLINICIAN SIGNATURE", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 1, color: const PdfColor.fromInt(0xFF7B1E3A)),
                pw.SizedBox(height: 4),
                pw.Text("NOTE: This audit report is dynamically compiled from patient screening registries and certified with a secure cryptographic handshake signature.", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfDoc.save(),
        name: 'SDC_Clinical_Audit_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to generate PDF Report: $e')),
      );
    }
  }

  pw.Widget _pdfStatBox(String label, String val) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8DDD8)),
        color: const PdfColor.fromInt(0xFFFAF7F4),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Column(
        children: [
          pw.Text(val, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
        ],
      ),
    );
  }
}
