import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebAnalyticsPage extends StatefulWidget {
  const WebAnalyticsPage({super.key});

  @override
  State<WebAnalyticsPage> createState() => _WebAnalyticsPageState();
}

class _WebAnalyticsPageState extends State<WebAnalyticsPage> {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  List<Map<String, dynamic>> _allCases = [];
  bool _loading = true;
  int? _pingLatency;
  String _licenseNo = 'DCI-98745-A';
  final List<Map<String, dynamic>> _savedAudits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final raw = await LocalDb.instance.getCases(Session.instance.doctorId);
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in raw) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    final cases = uniqueMap.values.toList();
    final latency = await LocalDb.instance.pingServer();
    final prefs = await SharedPreferences.getInstance();
    final license = prefs.getString('pref_license_no') ?? 'DCI-98745-A';

    if (mounted) {
      setState(() {
        _allCases = cases;
        _pingLatency = latency;
        _licenseNo = license;
        _loading = false;
      });
    }
  }

  Future<void> _generateReportPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SAVEETHA DENTAL COLLEGE & HOSPITAL', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Oral Ulcer AI - Clinical Report', style: pw.TextStyle(fontSize: 14)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),
                pw.Text('Clinician Name: ${Session.instance.displayName}'),
                pw.Text('License Number: $_licenseNo'),
                pw.Text('Date Generated: ${DateTime.now().toLocal().toString().split(".")[0]}'),
                pw.SizedBox(height: 20),
                pw.Text('Diagnostic Statistics summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Bullet(text: 'Total patients screened: ${_allCases.length}'),
                pw.Bullet(text: 'High-risk cases detected: ${_allCases.where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH')).length}'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _maroon));
    }

    final total = _allCases.length;
    final high = _allCases.where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains('HIGH')).length;
    final moderate = _allCases.where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains('INTERMEDIATE') || (c['risk_category'] ?? '').toString().toUpperCase().contains('MODERATE')).length;
    final low = total - high - moderate;

    return SingleChildScrollView(
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
                    'Clinical Analytics',
                    style: TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Visualize distributions, export records, and manage licensing statistics.',
                    style: TextStyle(color: _muted, fontSize: 14.5),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _generateReportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 18),
                label: const Text('GENERATE SYSTEM REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _maroon,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Two-column responsive layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Pie Chart and Statistics
              Expanded(
                flex: 12,
                child: Column(
                  children: [
                    _buildChartCard(total, high, moderate, low),
                    const SizedBox(height: 24),
                    _buildLatencyCard(),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // Right Column: License settings and general stats
              Expanded(
                flex: 11,
                child: Column(
                  children: [
                    _buildLicenseCard(),
                    const SizedBox(height: 24),
                    _buildAuditsCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(int total, int high, int moderate, int low) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Distribution Summary', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            height: 240,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          color: Colors.red,
                          value: high.toDouble(),
                          title: high > 0 ? '$high' : '',
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        PieChartSectionData(
                          color: Colors.orange,
                          value: moderate.toDouble(),
                          title: moderate > 0 ? '$moderate' : '',
                          radius: 54,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        PieChartSectionData(
                          color: Colors.green,
                          value: low.toDouble(),
                          title: low > 0 ? '$low' : '',
                          radius: 48,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartLegend(Colors.red, 'High Risk Cases ($high)'),
                    const SizedBox(height: 12),
                    _buildChartLegend(Colors.orange, 'Intermediate Cases ($moderate)'),
                    const SizedBox(height: 12),
                    _buildChartLegend(Colors.green, 'Low Risk Cases ($low)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLatencyCard() {
    final delay = _pingLatency;
    final isOnline = delay != null;
    final delayText = isOnline ? '$delay ms' : 'Offline';
    final delayColor = isOnline ? (delay < 150 ? Colors.green : Colors.orange) : Colors.red;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: delayColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.network_ping_rounded, color: delayColor, size: 24),
              ),
              const SizedBox(width: 20),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Server Connection Latency', style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Active web node status check', style: TextStyle(color: _muted, fontSize: 12.5)),
                ],
              ),
            ],
          ),
          Text(
            delayText,
            style: TextStyle(color: delayColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinician Authorization Settings', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Configure dental license and active credentials.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 28),
          const Text('Dental Council License Registration', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: _maroon, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(_licenseNo, style: const TextStyle(color: _text, fontSize: 14.5, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: _showEditLicenseDialog,
                  icon: const Icon(Icons.edit_outlined, color: _muted, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditLicenseDialog() {
    final ctrl = TextEditingController(text: _licenseNo);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Dental License', style: TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: _text),
            decoration: InputDecoration(
              hintText: 'Enter Registration License No.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('pref_license_no', val);
                  setState(() => _licenseNo = val);
                }
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _maroon),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuditsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Access Logs & Audits', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Recent security and synchronization events.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 24),
          if (_savedAudits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No recent audits registered on this browser.', style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
