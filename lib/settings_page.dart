import 'package:flutter/material.dart';
import 'db/session.dart';

// Settings Page — Screens 46 / 47 / 48

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  bool _notifHigh   = true;
  bool _autoRefresh = false;
  bool _compactView = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, backgroundColor: _maroon, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Settings',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w600)),
            flexibleSpace: Container(decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_maroonD, _maroon]),
            )),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _section('Preferences', [
                _toggle('High-risk alert banner',
                    'Show alert when recent case is HIGH',
                    Icons.warning_amber_rounded, _notifHigh,
                    (v) => setState(() => _notifHigh = v)),
                _toggle('Auto-refresh dashboard',
                    'Reload cases list on return',
                    Icons.refresh_rounded, _autoRefresh,
                    (v) => setState(() => _autoRefresh = v)),
                _toggle('Compact case list',
                    'Smaller rows in history screen',
                    Icons.view_agenda_outlined, _compactView,
                    (v) => setState(() => _compactView = v)),
              ]),
              const SizedBox(height: 20),
              _section('Account', [
                _tile('My Profile', Icons.person_outline_rounded,
                    () => Navigator.pushNamed(context, '/profile')),
                _tile('Change Password', Icons.lock_outline_rounded,
                    () => Navigator.pushNamed(context, '/profile')),
              ]),
              const SizedBox(height: 20),
              _section('Data', [
                _tile('Analytics', Icons.bar_chart_rounded,
                    () => Navigator.pushNamed(context, '/analytics')),
                _tile('Patient History', Icons.folder_open_rounded,
                    () => Navigator.pushNamed(context, '/history')),
              ]),
              const SizedBox(height: 20),
              _section('About', [
                _tile('About Oral Ulcer AI', Icons.info_outline_rounded,
                    () => _aboutDialog(context)),
                _tile('Medical Disclaimer', Icons.gavel_rounded,
                    () => _disclaimerDialog(context)),
                _tile('Version', Icons.system_update_alt_rounded, null,
                    trailing: const Text('v3.0.0',
                        style: TextStyle(color: _muted, fontSize: 12.5))),
              ]),
              const SizedBox(height: 20),
              _signOutTile(context),
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: TextStyle(color: _muted, fontSize: 10.5,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
    ),
    Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Column(children: [
          e.value,
          if (!isLast) Divider(height: 0, color: _border, indent: 56),
        ]);
      }).toList()),
    ),
  ]);

  Widget _toggle(String title, String sub, IconData icon,
      bool val, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(color: _muted, fontSize: 11.5)),
      trailing: Switch(
        value: val,
        onChanged: onChanged,
        activeColor: _maroon,
      ),
    );
  }

  Widget _tile(String title, IconData icon, VoidCallback? onTap,
      {Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: _text, fontSize: 13.5,
          fontWeight: FontWeight.w600)),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: _muted, size: 20)
              : null),
    );
  }

  Widget _signOutTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFEBEE)),
      ),
      child: ListTile(
        onTap: () {
          Session.instance.clear();
          Navigator.pushReplacementNamed(context, '/login');
        },
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded,
              color: Color(0xFFC62828), size: 18),
        ),
        title: const Text('Sign Out',
            style: TextStyle(color: Color(0xFFC62828), fontSize: 13.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _aboutDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _maroon.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: _maroon, size: 20),
        ),
        const SizedBox(width: 12),
        const Text('Oral Ulcer AI',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aboutRow('Version', 'v3.0.0 — Production Edition'),
        _aboutRow('Institution', 'Saveetha Dental College & Hospital'),
        _aboutRow('Features', 'Cloud Sync, Multi-user support, Analytics'),
        _aboutRow('AI Engine', 'Advanced Enterprise Diagnostic Scoring'),
        const SizedBox(height: 12),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close',
              style: TextStyle(color: _maroon, fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  Widget _aboutRow(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90,
          child: Text(label, style: TextStyle(color: _muted, fontSize: 12))),
      Expanded(child: Text(val, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  void _disclaimerDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.gavel_rounded, color: _maroon, size: 22),
        SizedBox(width: 10),
        Text('Medical Disclaimer',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _dItem(Icons.info_outlined,
              'This application is a clinical decision-support tool intended to assist qualified dental clinicians.'),
          _dItem(Icons.not_interested_outlined,
              'It does NOT replace clinical judgment, histopathological examination, or biopsy results.'),
          _dItem(Icons.science_outlined,
              'AI risk scores are based on weighted clinical features. Accuracy is not guaranteed in all cases.'),
          _dItem(Icons.medical_services_outlined,
              'Treatment decisions must be made by a licensed healthcare professional after thorough clinical examination.'),
          _dItem(Icons.school_outlined,
              'Developed for academic use at Saveetha Dental College & Hospital, Chennai.'),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('I Understand',
              style: TextStyle(color: _maroon, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Widget _dItem(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: _maroon),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12.5, height: 1.5))),
    ]),
  );
}
