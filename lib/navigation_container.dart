import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'analytics_page.dart';
import 'history_screen.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'new_case_page.dart';
import 'db/local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  bool _showTour = false;
  int _tourStep = 0;

  @override
  void initState() {
    super.initState();
    _checkTour();
  }

  Future<void> _checkTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldShow = prefs.getBool('show_tour_next') ?? false;
      
      if (shouldShow && mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showTour = true);
        });
        // Clear flag immediately so it never shows again
        await prefs.setBool('show_tour_next', false);
      }
    } catch (_) {}
  }

  // ... (Palette same as before)
  static const Color _primary   = Color(0xFF7B1E3A);
  static const Color _accent    = Color(0xFFC9A84C);
  static const Color _bg        = Color(0xFFFAF7F4);
  static const Color _surface   = Color(0xFFFFFFFF);
  static const Color _muted     = Color(0xFF9E8A8F);
  static const Color _teal      = Color(0xFF008080);
  static const Color _text      = Color(0xFF1E0A10);

  final List<Widget> _pages = [
    const DashboardPage(),
    const AnalyticsPage(),
    const HistoryScreen(),
    const SettingsPage(),
    const ProfilePage(),
  ];

  final List<Map<String, dynamic>> _tourData = [
    {
      't': 'Clinical Dashboard',
      'd': 'Overview of all your recent AI assessments and clinical stats.',
      'index': 0,
      'align': Alignment.center,
    },
    {
      't': 'Advanced Analytics',
      'd': 'Visualize risk trends and diagnostic distributions over time.',
      'index': 1,
      'align': const Alignment(0, 0.6), // Points to Progress tab
    },
    {
      't': 'Case History',
      'd': 'Access and search your full database of previous patient evaluations.',
      'index': 2,
      'align': const Alignment(0, 0.6), // Points to Insights tab
    },
    {
      't': 'System Reports',
      'd': 'Configure application settings and generate clinical reports.',
      'index': 3,
      'align': const Alignment(0, 0.6), // Points to Reports tab
    },
    {
      't': 'Clinician Profile',
      'd': 'Manage your professional details and security credentials.',
      'index': 4,
      'align': const Alignment(0, 0.6), // Points to Profile tab
    },
  ];

  void _nextStep() async {
    if (_tourStep < _tourData.length - 1) {
      setState(() {
        _tourStep++;
        _currentIndex = _tourData[_tourStep]['index'] as int;
      });
    } else {
      await LocalDb.instance.markTourDone();
      if (mounted) {
        setState(() {
          _showTour = false;
          _currentIndex = 0; // Return to home
        });
      }
    }
  }

  void _prevStep() {
    if (_tourStep > 0) {
      setState(() {
        _tourStep--;
        _currentIndex = _tourData[_tourStep]['index'] as int;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewCasePage()),
            ),
            backgroundColor: _primary,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
          bottomNavigationBar: _buildBottomNav(),
        ),
        if (_showTour) _buildTourOverlay(),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, "Dashboard"),
              _buildNavItem(1, Icons.trending_up_outlined, Icons.trending_up_rounded, "Analytics"),
              _buildNavItem(2, Icons.history_rounded, Icons.history_rounded, "History"),
              _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, "Settings"),
              _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourOverlay() {
    final step = _tourData[_tourStep];
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.75)),
          Align(
            alignment: step['align'] as Alignment,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF90CAF9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (step['t'] as String).toUpperCase(),
                          style: const TextStyle(color: Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step['d'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _text, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (_tourStep > 0)
                              TextButton(onPressed: _prevStep, child: const Text("PREV", style: TextStyle(color: _muted, fontSize: 11))),
                            const Spacer(),
                            Text("${_tourStep + 1}/${_tourData.length}", style: const TextStyle(color: _muted, fontSize: 11)),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2), 
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_tourStep < _tourData.length - 1 ? "NEXT" : "FINISH", style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    // ... (rest of the _buildNavItem remains same)
    final bool isSelected = _currentIndex == index;
    final Color color = isSelected ? _teal : _muted.withOpacity(0.7);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? _teal.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
