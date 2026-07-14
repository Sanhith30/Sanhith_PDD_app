import 'package:flutter/material.dart';
import 'web_dashboard.dart';
import 'web_analytics_page.dart';
import 'web_history_screen.dart';
import 'web_settings_page.dart';
import 'web_profile_page.dart';
import 'web_new_case_page.dart';
import '../db/local_db.dart';

class WebMainScaffold extends StatefulWidget {
  const WebMainScaffold({super.key});

  @override
  State<WebMainScaffold> createState() => _WebMainScaffoldState();
}

class _WebMainScaffoldState extends State<WebMainScaffold> {
  int _currentIndex = 0;

  static const Color _primary   = Color(0xFF7B1E3A);
  static const Color _accent    = Color(0xFFC9A84C);
  static const Color _bg        = Color(0xFFFAF7F4);
  static const Color _surface   = Color(0xFFFFFFFF);
  static const Color _muted     = Color(0xFF9E8A8F);
  static const Color _text      = Color(0xFF1E0A10);
  static const Color _border    = Color(0xFFE8DDD8);

  final List<Widget> _pages = [
    const WebDashboardPage(),
    const WebAnalyticsPage(),
    const WebHistoryScreen(),
    const WebSettingsPage(),
    const WebProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          // Left Sidebar navigation panel
          _buildSidebar(),
          // Vertical divider line
          const VerticalDivider(width: 1, color: _border, thickness: 1),
          // Active main page body content
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: _primary,
      child: Column(
        children: [
          // Sidebar Monogram Header
          _buildSidebarHeader(),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 24),
          
          // Action button: Add New Case
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/new_case');
              },
              icon: const Icon(Icons.add_rounded, size: 20, color: _primary),
              label: const Text(
                'NEW CASE',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Sidebar menu items
          Expanded(
            child: Column(
              children: [
                _buildSidebarItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
                _buildSidebarItem(1, Icons.trending_up_outlined, Icons.trending_up_rounded, 'Analytics'),
                _buildSidebarItem(2, Icons.history_rounded, Icons.history_rounded, 'Case History'),
                _buildSidebarItem(3, Icons.settings_outlined, Icons.settings_rounded, 'System Settings'),
                _buildSidebarItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'My Profile'),
              ],
            ),
          ),

          // Sidebar Footer branding
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: _accent.withOpacity(0.7), width: 1.5),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Oral Sentry',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                ),
                SizedBox(height: 3),
                Text(
                  'Clinical Support AI',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final bool isSelected = _currentIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(color: _accent.withOpacity(0.3), width: 1) 
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? filledIcon : outlineIcon,
                  color: isSelected ? _accent : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 0.6, color: _accent.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text(
                'SAVEETHA SDC',
                style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Clinical Decision Portal v2.0',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
