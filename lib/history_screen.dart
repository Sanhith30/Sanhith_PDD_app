import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HISTORY SCREEN  —  "Surgical Luxury"
//  Reads from local SQLite — no Firestore
// ─────────────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _maroon = Color(0xFF7B1E3A);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterRisk  = 'ALL'; // ALL | HIGH | INTERMEDIATE | LOW

  List<Map<String, dynamic>> _allCases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    final cases = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // Deduplicate on client side to be safe: Keep only the first occurrence (latest) of each patient_id
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in cases) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    
    if (mounted) {
      setState(() { 
        _allCases = uniqueMap.values.toList(); 
        _loading = false; 
      });
    }
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
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) =>
          (c['patient_id'] ?? '').toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        title: const Text('Patient History',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          color: _maroon,
          child: Column(children: [
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by Patient ID (e.g. PT001)',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final chip in ['ALL', 'HIGH', 'INTERMEDIATE', 'LOW'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterRisk = chip),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filterRisk == chip
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(chip,
                            style: TextStyle(
                              color: _filterRisk == chip ? _maroon : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
          ]),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _maroon))
              : filtered.isEmpty
                  ? _buildEmptyState(isSearch: _searchQuery.isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildHistoryCard(filtered[index]),
                    ),
        ),
      ]),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) {
    final String risk = (c['risk_category'] ?? 'PENDING').toString();
    Color riskColor = risk.toUpperCase().contains('HIGH')
        ? Colors.red
        : risk.toUpperCase().contains('INTERMEDIATE')
            ? Colors.orange
            : risk.toUpperCase().contains('LOW')
                ? Colors.green
                : Colors.grey;

    final int ms   = (c['created_at'] as int?) ?? 0;
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final String formattedDate =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    final String imagePath = (c['image_path'] ?? '').toString();
    final int caseId = (c['id'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50, height: 50,
            color: Colors.grey.shade100,
            child: imagePath.isNotEmpty && !kIsWeb && File(imagePath).existsSync()
                ? Image.file(File(imagePath), fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),
        title: Text(c['patient_id']?.toString() ?? 'Unknown ID',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(c['patient_name']?.toString() ?? 'Unnamed Patient',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 8),
              const Text("•", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Dr. ${c['doctor_name'] ?? 'Unknown'}", 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7B1E3A))),
              ),
            ],
          ),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(risk,
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
        onTap: () {
          if (c['status'] == 'Completed') {
            Navigator.pushNamed(context, '/ai_result', arguments: caseId)
                .then((_) => _loadCases());
          }
        },
      ),
    );
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isSearch ? Icons.search_off : Icons.folder_open,
            size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(isSearch
            ? 'No matching patients found'
            : 'No history recorded yet',
            style: const TextStyle(color: Colors.grey,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}