import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebHistoryScreen extends StatefulWidget {
  const WebHistoryScreen({super.key});

  @override
  State<WebHistoryScreen> createState() => _WebHistoryScreenState();
}

class _WebHistoryScreenState extends State<WebHistoryScreen> {
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _border  = Color(0xFFE8DDD8);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterRisk = 'ALL';
  bool _deduplicate = true;
  DateTimeRange? _selectedDateRange;

  List<Map<String, dynamic>> _allCases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCases() async {
    setState(() => _loading = true);
    try {
      final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
      List<Map<String, dynamic>> processedCases = cases;
      
      if (_deduplicate) {
        final Map<String, Map<String, dynamic>> uniqueMap = {};
        for (var c in cases) {
          final pid = c['patient_id']?.toString() ?? 'unknown';
          if (!uniqueMap.containsKey(pid)) {
            uniqueMap[pid] = c;
          }
        }
        processedCases = uniqueMap.values.toList();
      }
      
      if (mounted) {
        setState(() { 
          _allCases = processedCases; 
          _loading = false; 
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _maroon,
              onPrimary: Colors.white,
              surface: _bg,
              onSurface: _text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadCases();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _maroon));
    }

    final filtered = _allCases.where((c) {
      final name = (c['patient_name'] ?? '').toString().toLowerCase();
      final pid = (c['patient_id'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || pid.contains(_searchQuery.toLowerCase());

      if (_filterRisk != 'ALL') {
        final cat = (c['risk_category'] ?? '').toString().toUpperCase();
        if (_filterRisk == 'HIGH' && !cat.contains('HIGH')) return false;
        if (_filterRisk == 'INTERMEDIATE' && !cat.contains('INTERMEDIATE') && !cat.contains('MODERATE')) return false;
        if (_filterRisk == 'LOW' && !cat.contains('LOW')) return false;
      }

      if (_selectedDateRange != null) {
        final timestampMs = c['created_at'] as int? ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        if (date.isBefore(_selectedDateRange!.start) || date.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Case History',
                    style: TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete audit record of all clinician case diagnostic screenings.',
                    style: TextStyle(color: _muted, fontSize: 14.5),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDateRange = null;
                      });
                      _loadCases();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('RESET FILTERS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _maroon,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Filters toolbar row
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search case history by name or ID...',
                      hintStyle: TextStyle(color: _muted.withOpacity(0.55)),
                      prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Deduplicate Toggle
              _buildFilterContainer(
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined, color: _maroon, size: 18),
                    const SizedBox(width: 10),
                    const Text('Deduplicate Patients', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 10),
                    Switch.adaptive(
                      value: _deduplicate,
                      activeColor: _maroon,
                      onChanged: (val) {
                        setState(() => _deduplicate = val);
                        _loadCases();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Date Range Picker Button
              _buildFilterContainer(
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: _maroon, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDateRange == null
                              ? 'Filter by Date'
                              : '${_selectedDateRange!.start.toString().split(" ")[0]} - ${_selectedDateRange!.end.toString().split(" ")[0]}',
                          style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Risk Dropdown
              _buildFilterContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: const ['ALL', 'HIGH', 'INTERMEDIATE', 'LOW'].contains(_filterRisk) ? _filterRisk : 'ALL',
                      onChanged: (val) {
                        if (val != null) setState(() => _filterRisk = val);
                      },
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Risks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        DropdownMenuItem(value: 'HIGH', child: Text('High Risk', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediate', style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'LOW', child: Text('Low Risk', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Cases Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      color: _bg,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('PATIENT', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('PATIENT ID', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('AGE / SEX', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('RISK LEVEL', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('RISK SCORE', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('DATE SCREENED', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          Expanded(flex: 1, child: SizedBox()),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border),
                    // Table Rows
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: _border),
                              itemBuilder: (context, index) {
                                return _buildPatientRow(filtered[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _buildPatientRow(Map<String, dynamic> c) {
    final riskCategory = (c['risk_category'] ?? 'Pending').toString();
    final double riskScore = double.tryParse(c['risk_score']?.toString() ?? '') ?? 0.0;
    
    Color riskColor = _muted;
    if (riskCategory.toUpperCase().contains('HIGH')) {
      riskColor = Colors.red;
    } else if (riskCategory.toUpperCase().contains('INTERMEDIATE') || riskCategory.toUpperCase().contains('MODERATE')) {
      riskColor = Colors.orange;
    } else if (riskCategory.toUpperCase().contains('LOW')) {
      riskColor = Colors.green;
    }

    final timestampMs = c['created_at'] as int? ?? 0;
    final dateStr = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal().toString().split(" ")[0];

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/case_detail', arguments: c['id']);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Patient details (Photo & Name)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _bg,
                      shape: BoxShape.circle,
                      image: c['patient_photo'] != null && c['patient_photo'].toString().isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(LocalDb.resolveUrl(c['patient_photo'].toString())),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: c['patient_photo'] == null || c['patient_photo'].toString().isEmpty
                        ? const Icon(Icons.person_rounded, color: _muted, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      c['patient_name'] ?? 'Anonymous',
                      style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Patient ID
            Expanded(
              flex: 2,
              child: Text(c['patient_id'] ?? 'N/A', style: const TextStyle(color: _text, fontSize: 13.5)),
            ),
            // Age / Sex
            Expanded(
              flex: 2,
              child: Text(
                '${c['patient_age'] ?? "N/A"} / ${c['patient_sex'] ?? "N/A"}',
                style: const TextStyle(color: _text, fontSize: 13.5),
              ),
            ),
            // Risk Category
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: riskColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    riskCategory,
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
            // Risk Score
            Expanded(
              flex: 2,
              child: Text(
                '${riskScore.toStringAsFixed(1)}%',
                style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(dateStr, style: const TextStyle(color: _muted, fontSize: 13.5)),
            ),
            // Action
            const Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right_rounded, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF7F3F0)),
            child: const Icon(Icons.search_off_rounded, size: 36, color: _muted),
          ),
          const SizedBox(height: 16),
          const Text('No records match your query', style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Try modifying your search text or filter configurations.', style: TextStyle(color: _muted, fontSize: 13)),
        ],
      ),
    );
  }
}
