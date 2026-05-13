import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'db/session.dart';

// Analytics Page — Screens 44 / 45

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

  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final raw = await LocalDb.instance.getCases(Session.instance.doctorId);
    
    // Deduplicate: Keep only the latest assessment for each patient
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in raw) {
      final pid = c['patient_id']?.toString() ?? 'unknown';
      if (!uniqueMap.containsKey(pid)) {
        uniqueMap[pid] = c;
      }
    }
    
    if (mounted) {
      setState(() { 
        _cases = uniqueMap.values.toList(); 
        _loading = false; 
      });
    }
  }

  int get _total => _cases.length;
  int _risk(String r) => _cases
      .where((c) => (c['risk_category'] ?? '').toString().toUpperCase().contains(r))
      .length;

  List<int> get _monthly {
    final now = DateTime.now();
    final counts = List<int>.filled(6, 0);
    for (final c in _cases) {
      final ms = (c['created_at'] as int?) ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final diff = (now.year * 12 + now.month) - (dt.year * 12 + dt.month);
      if (diff >= 0 && diff < 6) counts[5 - diff]++;
    }
    return counts;
  }

  List<String> get _monthLabels {
    final now = DateTime.now();
    const n = ['J','F','M','A','M','J','J','A','S','O','N','D'];
    return List.generate(6, (i) => n[((now.month - 5 + i - 1) % 12 + 12) % 12]);
  }

  Map<String, int> get _sites {
    final m = <String, int>{};
    for (final c in _cases) {
      try {
        final cd = jsonDecode((c['clinical_json'] ?? '{}') as String);
        final s = (cd['clinicalExam']?['site'] ?? 'Unknown')
            .toString().replaceAll('⚠️', '').trim();
        m[s] = (m[s] ?? 0) + 1;
      } catch (_) {}
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _maroon,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Analytics',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w600)),
            flexibleSpace: Container(decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_maroonD, _maroon]),
            )),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(
                  color: _maroon, strokeWidth: 2)),
            )
          else if (_total == 0)
            SliverFillRemaining(child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverList(delegate: SliverChildListDelegate([
                _stats(),
                const SizedBox(height: 20),
                _barChart(),
                const SizedBox(height: 20),
                _donut(),
                const SizedBox(height: 20),
                _topSites(),
              ])),
            ),
        ]),
      ),
    );
  }

  Widget _empty() => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.bar_chart_rounded, size: 80, color: _muted.withOpacity(0.25)),
    const SizedBox(height: 16),
    const Text('No analytics yet',
        style: TextStyle(color: _muted, fontSize: 18,
            fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Text('Complete cases to see insights',
        style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 13)),
  ]));

  Widget _stats() {
    final h = _risk('HIGH'); final m = _risk('INTERMEDIATE'); final l = _risk('LOW');
    return Row(children: [
      _sBox(_total.toString(), 'Total',    _maroon,               Colors.white),
      const SizedBox(width: 10),
      _sBox(h.toString(),      'High',     const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      const SizedBox(width: 10),
      _sBox(m.toString(),      'Medium',   const Color(0xFFFFF8E1), const Color(0xFFE65100)),
      const SizedBox(width: 10),
      _sBox(l.toString(),      'Low',      const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
    ]);
  }

  Widget _sBox(String v, String l, Color bg, Color fg) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(v, style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(l, style: TextStyle(color: fg.withOpacity(0.7), fontSize: 9.5,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _barChart() {
    final counts = _monthly;
    final labels = _monthLabels;
    final maxV = counts.reduce(math.max).toDouble().clamp(1, 9999);
    return _card('Cases per Month', 'Last 6 months',
      SizedBox(height: 160, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (i) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('${counts[i]}',
                style: TextStyle(color: _maroon, fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: Duration(milliseconds: 350 + i * 60),
              curve: Curves.easeOutCubic,
              height: (counts[i] / maxV) * 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_maroon.withOpacity(0.6), _maroon],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: TextStyle(color: _muted, fontSize: 10.5)),
          ]),
        ))),
      )),
    );
  }

  Widget _donut() {
    final h = _risk('HIGH'); final m = _risk('INTERMEDIATE'); final l = _risk('LOW');
    final t = (h + m + l).clamp(1, 99999);
    return _card('Risk Distribution', 'Completed cases',
      Row(children: [
        SizedBox(width: 130, height: 130, child: CustomPaint(painter: _Donut(
          values: [h / t, m / t, l / t],
          colors: const [Color(0xFFC62828), Color(0xFFE65100), Color(0xFF2E7D32)],
        ))),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _leg('High Risk',    h, t, const Color(0xFFC62828)),
            const SizedBox(height: 10),
            _leg('Intermediate', m, t, const Color(0xFFE65100)),
            const SizedBox(height: 10),
            _leg('Low Risk',     l, t, const Color(0xFF2E7D32)),
          ],
        )),
      ]),
    );
  }

  Widget _leg(String label, int count, int total, Color color) {
    final pct = (count / total * 100).round();
    return Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      Text('$count ($pct%)',
          style: TextStyle(color: _muted, fontSize: 11.5)),
    ]);
  }

  Widget _topSites() {
    final sorted = _sites.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox();
    final maxV = top.first.value;
    return _card('Top Anatomical Sites', 'By frequency',
      Column(children: top.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(e.key,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
            Text('${e.value}',
                style: TextStyle(color: _maroon, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: e.value / maxV,
              backgroundColor: _maroon.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(_maroon),
              minHeight: 6,
            )),
        ]),
      )).toList()),
    );
  }

  Widget _card(String title, String sub, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 14,
            fontWeight: FontWeight.w700)),
        Text(sub, style: TextStyle(color: _muted, fontSize: 11)),
      ]),
      Container(height: 1, color: _gold.withOpacity(0.15),
          margin: const EdgeInsets.symmetric(vertical: 12)),
      child,
    ]),
  );
}

class _Donut extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _Donut({required this.values, required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i]);
      start += sweep;
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFFFFFFF));
  }
  @override
  bool shouldRepaint(_Donut o) => false;
}
