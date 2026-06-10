import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HISTORY SCREEN  —  "Surgical Luxury"
//  Reads from PostgreSQL backend API
// ─────────────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _maroon = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold = Color(0xFFC9A84C);
  static const Color _muted = Color(0xFF9E8A8F);
  static const Color _bg = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _text = Color(0xFF1E0A10);
  static const Color _border = Color(0xFFE8DDD8);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterRisk = 'ALL'; // ALL | HIGH | INTERMEDIATE | LOW
  bool _filterBiopsy = false;
  bool _filterBleeding = false;
  bool _filterInduration = false;

  List<Map<String, dynamic>> _allCases = [];
  bool _loading = true;
  bool _compactView = false;
  bool _isGridView = false; // Grid View toggle
  bool _deduplicate = true; // Deduplicated Patients vs All Visits Timeline
  DateTimeRange? _selectedDateRange; // Date range filter
  final Set<int> _selectedCaseIds = {}; // Selection tracker for batch actions

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final compact = prefs.getBool('pref_compact_view') ?? false;
      final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
      
      List<Map<String, dynamic>> processedCases = cases;
      if (_deduplicate) {
        // Keep only the latest visit of each patient_id
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
          _compactView = compact;
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
    } else if (_selectedDateRange != null) {
      setState(() {
        _selectedDateRange = null;
      });
    }
  }

  Widget _highlightText(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(text, style: baseStyle);
    }
    final matches = query.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = text.toLowerCase().indexOf(matches, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + matches.length),
        style: baseStyle.copyWith(
          color: _gold, 
          fontWeight: FontWeight.bold,
          backgroundColor: _maroon.withOpacity(0.08),
        ),
      ));
      start = index + matches.length;
    }
    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildClinicalChip({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _gold : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _gold : Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? _text : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, color: _text, size: 12),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<Map<String, dynamic>> filteredCases) {
    if (_selectedCaseIds.isNotEmpty) {
      return AppBar(
        backgroundColor: _maroonD,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () {
            setState(() {
              _selectedCaseIds.clear();
            });
          },
        ),
        title: Text(
          '${_selectedCaseIds.length} Selected',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded, color: Colors.white, size: 20),
            tooltip: 'Select All',
            onPressed: () {
              setState(() {
                _selectedCaseIds.addAll(filteredCases.map((c) => (c['id'] as num?)?.toInt() ?? 0));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.grid_on_outlined, color: Colors.white, size: 20),
            tooltip: 'Batch Export CSV',
            onPressed: () => _exportCsv(filteredCases.where((c) => _selectedCaseIds.contains(c['id'])).toList()),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            tooltip: 'Batch Export PDF Audit',
            onPressed: () => _exportPdf(filteredCases.where((c) => _selectedCaseIds.contains(c['id'])).toList()),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: _maroon,
      elevation: 0,
      title: const Text('Patient History',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
          tooltip: _isGridView ? 'Switch to List View' : 'Switch to Gallery View',
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
        IconButton(
          icon: Icon(_deduplicate ? Icons.people_outline_rounded : Icons.history_rounded, size: 20),
          tooltip: _deduplicate ? 'Show All Visits Timeline' : 'Show Deduplicated Patients Only',
          onPressed: () {
            setState(() {
              _deduplicate = !_deduplicate;
            });
            _loadCases();
          },
        ),
        IconButton(
          icon: Icon(_selectedDateRange != null ? Icons.calendar_today_rounded : Icons.calendar_month_outlined, 
              color: _selectedDateRange != null ? _gold : Colors.white, size: 20),
          tooltip: 'Filter by Date Range',
          onPressed: _selectDateRange,
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded, size: 20),
          tooltip: 'Export Current List (CSV)',
          onPressed: () => _exportCsv(filteredCases),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = _allCases;
    
    // Apply risk filter
    if (_filterRisk != 'ALL') {
      filtered = filtered.where((c) =>
          (c['risk_category'] ?? '').toString().toUpperCase()
              .contains(_filterRisk)).toList();
    }
    
    // Apply search query (matches name, ID, or doctor name)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final pid = (c['patient_id'] ?? '').toString().toLowerCase();
        final name = (c['patient_name'] ?? '').toString().toLowerCase();
        final doc = (c['doctor_name'] ?? '').toString().toLowerCase();
        return pid.contains(q) || name.contains(q) || doc.contains(q);
      }).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((c) {
        final int ms = (c['created_at'] as num?)?.toInt() ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(ms);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        return date.isAfter(start) && date.isBefore(end);
      }).toList();
    }

    // Apply clinical data filters
    if (_filterBiopsy || _filterBleeding || _filterInduration) {
      filtered = filtered.where((c) {
        Map<String, dynamic> clinical = {};
        try {
          clinical = jsonDecode((c['clinical_json'] ?? '{}') as String);
        } catch (_) {}

        final exam = clinical['clinicalExam'] ?? {};

        if (_filterBiopsy) {
          final recommendation = (c['biopsy_recommendation'] ?? '').toString().toLowerCase();
          if (!recommendation.contains('biopsy')) return false;
        }

        if (_filterBleeding) {
          final bleeding = exam['bleeding'] == true || exam['bleeding'] == 'Yes';
          if (!bleeding) return false;
        }

        if (_filterInduration) {
          final induration = exam['induration'] == true || exam['induration'] == 'Yes';
          if (!induration) return false;
        }

        return true;
      }).toList();
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(filtered),
      body: Column(
        children: [
          // Search Bar and Filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            color: _maroon,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by Patient Name, ID, or Doctor...',
                    hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chip in ['ALL', 'HIGH', 'INTERMEDIATE', 'LOW'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filterRisk = chip),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _filterRisk == chip ? Colors.white : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Text(
                                chip,
                                style: TextStyle(
                                  color: _filterRisk == chip ? _maroon : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildClinicalChip(
                        label: '⚠️ Biopsy Rec.',
                        isActive: _filterBiopsy,
                        onTap: () => setState(() => _filterBiopsy = !_filterBiopsy),
                      ),
                      const SizedBox(width: 8),
                      _buildClinicalChip(
                        label: '🩸 Bleeding',
                        isActive: _filterBleeding,
                        onTap: () => setState(() => _filterBleeding = !_filterBleeding),
                      ),
                      const SizedBox(width: 8),
                      _buildClinicalChip(
                        label: '🔬 Induration',
                        isActive: _filterInduration,
                        onTap: () => setState(() => _filterInduration = !_filterInduration),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _maroon))
                : RefreshIndicator(
                    onRefresh: _loadCases,
                    color: _maroon,
                    backgroundColor: _bg,
                    child: filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.65,
                              alignment: Alignment.center,
                              child: _buildEmptyState(
                                isSearch: _searchQuery.isNotEmpty || 
                                    _selectedDateRange != null || 
                                    _filterBiopsy || 
                                    _filterBleeding || 
                                    _filterInduration
                              ),
                            ),
                          )
                        : _isGridView
                            ? GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) => _buildHistoryGridCard(filtered[index]),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) => _buildHistoryCard(filtered[index], filtered),
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c, List<Map<String, dynamic>> filteredList) {
    final int caseId = (c['id'] as num?)?.toInt() ?? 0;
    final bool isSelected = _selectedCaseIds.contains(caseId);

    final String risk = (c['risk_category'] ?? 'PENDING').toString();
    Color riskColor = risk.toUpperCase().contains('HIGH')
        ? const Color(0xFFC62828)
        : risk.toUpperCase().contains('INTERMEDIATE')
            ? const Color(0xFFE65100)
            : risk.toUpperCase().contains('LOW')
                ? const Color(0xFF2E7D32)
                : Colors.grey;

    final int ms = (c['created_at'] as num?)?.toInt() ?? 0;
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final String formattedDate =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    final String imagePath = (c['image_path'] ?? '').toString();
    final double riskScore = (c['risk_score'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: _compactView ? 6 : 12),
      elevation: isSelected ? 3 : 0,
      color: isSelected ? riskColor.withOpacity(0.04) : _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected 
              ? riskColor 
              : risk.toUpperCase().contains('HIGH')
                  ? const Color(0xFFC62828).withOpacity(0.2)
                  : _border, 
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: _compactView ? 4 : 10),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            if (_selectedCaseIds.isNotEmpty)
              Checkbox(
                value: isSelected,
                activeColor: _maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedCaseIds.add(caseId);
                    } else {
                      _selectedCaseIds.remove(caseId);
                    }
                  });
                },
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: _compactView ? 40 : 54,
                  height: _compactView ? 40 : 54,
                  decoration: BoxDecoration(
                    color: _bg,
                    border: Border.all(
                      color: risk.toUpperCase().contains('HIGH') ? const Color(0xFFC62828) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: imagePath.isEmpty
                      ? const Icon(Icons.image_not_supported, color: Colors.grey, size: 20)
                      : (imagePath.startsWith('/static') || imagePath.startsWith('http'))
                          ? Image.network(
                              imagePath.startsWith('http') ? imagePath : '${LocalDb.baseUrl}$imagePath',
                              headers: const {'Bypass-Tunnel-Reminder': 'true'},
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                            )
                          : (!kIsWeb && File(imagePath).existsSync())
                              ? Image.file(File(imagePath), fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: _highlightText(
                c['patient_id']?.toString() ?? 'Unknown ID',
                _searchQuery,
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _text),
              ),
            ),
            if (c['biopsy_recommendation']?.toString().toLowerCase().contains('biopsy') ?? false)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3), width: 0.5),
                ),
                child: const Text(
                  '⚠️ BIOPSY',
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _highlightText(
              c['patient_name']?.toString() ?? 'Unnamed Patient',
              _searchQuery,
              const TextStyle(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(formattedDate, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                const SizedBox(width: 8),
                const Text("•", style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(width: 8),
                Expanded(
                  child: _highlightText(
                    "Dr. ${c['doctor_name'] ?? 'Unknown'}",
                    _searchQuery,
                    const TextStyle(fontSize: 10.5, color: _maroon, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (!_compactView) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: riskScore / 100.0,
                        minHeight: 5,
                        backgroundColor: _border,
                        valueColor: AlwaysStoppedAnimation(riskColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${riskScore.toStringAsFixed(0)}%',
                    style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: _selectedCaseIds.isNotEmpty
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: riskColor.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      risk,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                ],
              ),
        onTap: () {
          if (_selectedCaseIds.isNotEmpty) {
            setState(() {
              if (isSelected) {
                _selectedCaseIds.remove(caseId);
              } else {
                _selectedCaseIds.add(caseId);
              }
            });
          } else {
            _showQuickActions(c);
          }
        },
        onLongPress: () {
          setState(() {
            _selectedCaseIds.add(caseId);
          });
        },
      ),
    );
  }

  Widget _buildHistoryGridCard(Map<String, dynamic> c) {
    final int caseId = (c['id'] as num?)?.toInt() ?? 0;
    final bool isSelected = _selectedCaseIds.contains(caseId);

    final String risk = (c['risk_category'] ?? 'PENDING').toString();
    Color riskColor = risk.toUpperCase().contains('HIGH')
        ? const Color(0xFFC62828)
        : risk.toUpperCase().contains('INTERMEDIATE')
            ? const Color(0xFFE65100)
            : risk.toUpperCase().contains('LOW')
                ? const Color(0xFF2E7D32)
                : Colors.grey;

    final String imagePath = (c['image_path'] ?? '').toString();
    final double riskScore = (c['risk_score'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () {
        if (_selectedCaseIds.isNotEmpty) {
          setState(() {
            if (isSelected) {
              _selectedCaseIds.remove(caseId);
            } else {
              _selectedCaseIds.add(caseId);
            }
          });
        } else {
          _showQuickActions(c);
        }
      },
      onLongPress: () {
        setState(() {
          _selectedCaseIds.add(caseId);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? riskColor 
                : risk.toUpperCase().contains('HIGH')
                    ? const Color(0xFFC62828).withOpacity(0.2)
                    : _border,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: imagePath.isEmpty
                  ? Container(
                      color: _bg,
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
                    )
                  : (imagePath.startsWith('/static') || imagePath.startsWith('http'))
                      ? Image.network(
                          imagePath.startsWith('http') ? imagePath : '${LocalDb.baseUrl}$imagePath',
                          headers: const {'Bypass-Tunnel-Reminder': 'true'},
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: _bg,
                                child: const Icon(Icons.broken_image, color: Colors.grey, size: 36),
                              ),
                        )
                      : (!kIsWeb && File(imagePath).existsSync())
                          ? Image.file(File(imagePath), fit: BoxFit.cover)
                          : Container(
                              color: _bg,
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
                            ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  risk,
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_selectedCaseIds.isNotEmpty)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: _maroon,
                    shape: const CircleBorder(),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCaseIds.add(caseId);
                        } else {
                          _selectedCaseIds.remove(caseId);
                        }
                      });
                    },
                  ),
                ),
              ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.75), Colors.black.withOpacity(0.55)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _highlightText(
                      c['patient_id']?.toString() ?? 'Unknown ID',
                      _searchQuery,
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c['patient_name']?.toString() ?? 'Unnamed Patient',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI Score: ${riskScore.toStringAsFixed(0)}%',
                          style: TextStyle(color: riskColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        if (c['biopsy_recommendation']?.toString().toLowerCase().contains('biopsy') ?? false)
                          const Text(
                            '⚠️ BIOPSY',
                            style: TextStyle(color: Color(0xFFC62828), fontSize: 8.5, fontWeight: FontWeight.bold),
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
    );
  }

  void _showQuickActions(Map<String, dynamic> c) {
    final int caseId = (c['id'] as num?)?.toInt() ?? 0;
    final String pid = c['patient_id']?.toString() ?? 'Unknown ID';
    final String pName = c['patient_name']?.toString() ?? 'Unnamed Patient';
    final int ms = (c['created_at'] as num?)?.toInt() ?? 0;
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final String dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: _bg,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _maroon.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: _maroon, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$pid • $pName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                          const SizedBox(height: 2),
                          Text('Screened on $dateStr by Dr. ${c['doctor_name'] ?? "Unknown"}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.remove_red_eye_outlined, color: _text),
                  title: const Text('View AI Diagnostic Results', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    if (c['status'] == 'Completed') {
                      Navigator.pushNamed(this.context, '/ai_result', arguments: caseId).then((_) => _loadCases());
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: _text),
                  title: const Text('Export Single Case PDF Report', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    _exportSingleCasePdf(c);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _text),
                  title: const Text('Edit Patient Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDetailsDialog(c);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDetailsDialog(Map<String, dynamic> c) {
    final int caseId = (c['id'] as num?)?.toInt() ?? 0;
    final pIdController = TextEditingController(text: c['patient_id']?.toString());
    final pNameController = TextEditingController(text: c['patient_name']?.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: _bg,
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: _maroon),
              SizedBox(width: 10),
              Text('Edit Patient Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pIdController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Patient ID',
                  labelStyle: TextStyle(color: _maroon),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _maroon)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pNameController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  labelStyle: TextStyle(color: _maroon),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _maroon)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newId = pIdController.text.trim();
                final newName = pNameController.text.trim();
                if (newId.isNotEmpty && newName.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() => _loading = true);
                  
                  final success = await LocalDb.instance.updateCasePatientDetails(
                    caseId: caseId,
                    patientId: newId,
                    patientName: newName,
                  );
                  
                  if (success) {
                    await _loadCases();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                        content: Text('Patient details updated successfully.'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  } else {
                    setState(() => _loading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                        content: Text('Failed to update patient details.'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _exportCsv(List<Map<String, dynamic>> cases) async {
    if (cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No cases to export.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    
    try {
      final StringBuffer csv = StringBuffer();
      csv.writeln("Case ID,Patient ID,Patient Name,Doctor Name,Date,Risk Category,Risk Score %,Recommendation,Confidence,Status");
      for (var c in cases) {
        final ms = (c['created_at'] as num?)?.toInt() ?? 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
        
        final name = (c['patient_name'] ?? 'N/A').toString().replaceAll('"', '""');
        final doc = (c['doctor_name'] ?? 'N/A').toString().replaceAll('"', '""');
        final rec = (c['biopsy_recommendation'] ?? 'N/A').toString().replaceAll('"', '""');
        final cat = (c['risk_category'] ?? 'N/A').toString().replaceAll('"', '""');
        
        csv.writeln("${c['id']},${c['patient_id']},\"$name\",\"$doc\",$dateStr,\"$cat\",${c['risk_score']},\"$rec\",${c['confidence']},${c['status']}");
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'SDC_Caseload_Export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv.toString());
      
      // Open native system save/share window
      await Printing.sharePdf(
        bytes: Uint8List.fromList(utf8.encode(csv.toString())),
        filename: filename,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('CSV file shared successfully.'),
        backgroundColor: Colors.green,
      ));
      
      setState(() {
        _selectedCaseIds.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to export CSV: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _exportPdf(List<Map<String, dynamic>> cases) async {
    if (cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No cases to generate PDF audit.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    try {
      final pdfDoc = pw.Document();
      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1E3A)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("SAVEETHA DENTAL COLLEGE & HOSPITALS", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFC9A84C), fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text("CLINICAL CASELOAD BATCH AUDIT REPORT", style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Text(
                      "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("CLINICIAN: DR. ${Session.instance.displayName.toUpperCase()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE8DDD8), width: 0.5),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1E3A)),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Case ID', 'Patient ID', 'Patient Name', 'Date', 'Risk Category', 'Risk Score %'],
                data: cases.map((c) {
                  final ms = (c['created_at'] as num?)?.toInt() ?? 0;
                  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                  final dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                  return [
                    c['id'].toString(),
                    c['patient_id'].toString(),
                    c['patient_name'].toString(),
                    dateStr,
                    c['risk_category'].toString(),
                    '${((c['risk_score'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}%'
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("STAMP: SDC CLINICAL GATEWAY", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, fontWeight: pw.FontWeight.bold)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 100, height: 0.5, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text("AUTHORIZED CLINICIAN SIGNATURE", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfDoc.save(),
        name: 'SDC_Caseload_Audit_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
      setState(() {
        _selectedCaseIds.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to generate PDF Audit: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _exportSingleCasePdf(Map<String, dynamic> c) async {
    try {
      final int caseId = (c['id'] as num?)?.toInt() ?? 0;
      final String pid = c['patient_id']?.toString() ?? 'N/A';
      final String name = c['patient_name']?.toString() ?? 'N/A';
      final double riskScore = (c['risk_score'] as num?)?.toDouble() ?? 0.0;
      final String riskCategory = c['risk_category']?.toString() ?? 'N/A';
      final String biopsy = c['biopsy_recommendation']?.toString() ?? 'N/A';
      final String confidence = c['confidence']?.toString() ?? 'N/A';

      final int ms = (c['created_at'] as num?)?.toInt() ?? 0;
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final String dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

      final pdfDoc = pw.Document();
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1E3A)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SAVEETHA DENTAL COLLEGE & HOSPITALS", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFC9A84C), fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text("INDIVIDUAL CLINICAL ASSESSMENT REPORT", style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Text("Case ID: #$caseId", style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text("PATIENT DEMOGRAPHICS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Patient ID: $pid", style: const pw.TextStyle(fontSize: 9.5)),
                        pw.Text("Patient Name: $name", style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 9.5)),
                        pw.Text("Clinician: Dr. ${Session.instance.displayName.toUpperCase()}", style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(height: 1, color: const PdfColor.fromInt(0xFFE8DDD8)),
                pw.SizedBox(height: 16),
                pw.Text("AI DIAGNOSTIC BREAKDOWN", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8DDD8)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                      child: pw.Column(
                        children: [
                          pw.Text(riskCategory, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                          pw.Text("Risk Category", style: const pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8DDD8)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                      child: pw.Column(
                        children: [
                          pw.Text("${riskScore.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                          pw.Text("Risk Score", style: const pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8DDD8)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                      child: pw.Column(
                        children: [
                          pw.Text(confidence, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                          pw.Text("AI Confidence", style: const pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text("CLINICAL RECOMMENDATION", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAF7F4)),
                  child: pw.Text(biopsy, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7B1E3A))),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("VERIFIED BY SDC CLINICAL GATEWAY", style: pw.TextStyle(fontSize: 7.5, color: const PdfColor.fromInt(0xFFC9A84C), fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                      children: [
                        pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                        pw.SizedBox(height: 3),
                        pw.Text("AUTHORIZED CLINICIAN SIGNATURE", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfDoc.save(),
        name: 'SDC_Case_Report_${pid}_$caseId.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to generate PDF Report: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _maroon.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(isSearch ? Icons.search_off_rounded : Icons.folder_open_rounded, size: 48, color: _maroon),
          ),
          const SizedBox(height: 20),
          Text(
            isSearch ? 'No matching patients found' : 'No history recorded yet',
            style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch ? 'Try clearing your search filters or range.' : 'Run screenings to catalog case logs.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (isSearch) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _filterRisk = 'ALL';
                  _filterBiopsy = false;
                  _filterBleeding = false;
                  _filterInduration = false;
                  _selectedDateRange = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}