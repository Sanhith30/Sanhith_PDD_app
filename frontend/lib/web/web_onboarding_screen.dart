import 'package:flutter/material.dart';
import '../db/local_db.dart';

class WebOnboardingScreen extends StatefulWidget {
  const WebOnboardingScreen({super.key});

  @override
  State<WebOnboardingScreen> createState() => _WebOnboardingScreenState();
}

class _WebOnboardingScreenState extends State<WebOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color _primary = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);

  final List<OnboardingData> _slides = [
    OnboardingData(
      title: "Welcome to Oral Ulcer AI",
      description: "AI-powered clinical decision support for oral ulcerative lesions",
      institution: "Saveetha Dental College & Hospital",
      icon: Icons.face_retouching_natural_rounded,
    ),
    OnboardingData(
      title: "Fill Clinical Data",
      description: "Complete 4 comprehensive sections for accurate AI assessment",
      icon: Icons.assignment_rounded,
      gridItems: [
        {"t": "Demographics", "s": "Patient information", "i": Icons.person_rounded},
        {"t": "Lesion History", "s": "Duration & symptoms", "i": Icons.description_rounded},
        {"t": "Clinical Exam", "s": "Physical findings", "i": Icons.medical_services_rounded},
        {"t": "Risk Factors", "s": "Associated findings", "i": Icons.timeline_rounded},
      ],
    ),
    OnboardingData(
      title: "Get AI Risk Score",
      description: "Instant AI-powered malignancy risk assessment with clinical recommendations",
      icon: Icons.psychology_rounded,
      listItems: [
        {"t": "Animated risk score gauge", "i": Icons.speed_rounded},
        {"t": "Explainable AI insights", "i": Icons.lightbulb_rounded},
        {"t": "Biopsy recommendations", "i": Icons.warning_amber_rounded},
        {"t": "Clinical decision support", "i": Icons.fact_check_rounded},
      ],
    ),
  ];

  void _finish() async {
    await LocalDb.instance.markOnboardingDone();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          // Left Branding Side
          Expanded(
            flex: 11,
            child: Container(
              color: _primary,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.04,
                      child: GridPaper(
                        color: _accent,
                        interval: 60,
                        subdivisions: 1,
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(color: _accent.withOpacity(0.5), width: 2),
                            ),
                            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 50),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Oral Ulcer AI',
                            style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w200, letterSpacing: 8.0),
                          ),
                          Container(width: 60, height: 1, color: _accent.withOpacity(0.5), margin: const EdgeInsets.symmetric(vertical: 20)),
                          const Text(
                            'Saveetha Dental College & Hospital',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Slider Side
          Expanded(
            flex: 12,
            child: Container(
              padding: const EdgeInsets.all(64),
              color: _bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Skip Onboarding', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      itemBuilder: (context, idx) => _buildSlideContent(_slides[idx]),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots Indicators
                      Row(
                        children: List.generate(_slides.length, (idx) {
                          final isSelected = _currentPage == idx;
                          return Container(
                            width: isSelected ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isSelected ? _primary : _muted.withOpacity(0.3),
                            ),
                          );
                        }),
                      ),
                      // Action buttons
                      Row(
                        children: [
                          if (_currentPage > 0)
                            TextButton(
                              onPressed: () {
                                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                              },
                              child: const Text('Back', style: TextStyle(color: _muted, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (_currentPage < _slides.length - 1) {
                                _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                              } else {
                                _finish();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            ),
                            child: Text(
                              _currentPage < _slides.length - 1 ? 'Next' : 'Get Started',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent(OnboardingData slide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(slide.icon, color: _primary, size: 54),
        const SizedBox(height: 24),
        Text(
          slide.title,
          style: const TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        if (slide.institution != null) ...[
          const SizedBox(height: 8),
          Text(slide.institution!, style: const TextStyle(color: _accent, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 16),
        Text(
          slide.description,
          style: const TextStyle(color: _muted, fontSize: 16, height: 1.5),
        ),
        if (slide.gridItems != null) ...[
          const SizedBox(height: 32),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: slide.gridItems!.map((item) => _buildGridCard(item)).toList(),
          ),
        ],
        if (slide.listItems != null) ...[
          const SizedBox(height: 32),
          Column(
            children: slide.listItems!.map((item) => _buildListRow(item)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGridCard(Map<String, dynamic> item) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item['i'] as IconData, color: _primary, size: 24),
          const SizedBox(height: 14),
          Text(item['t'] as String, style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 4),
          Text(item['s'] as String, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildListRow(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Icon(item['i'] as IconData, color: _accent, size: 20),
          const SizedBox(width: 14),
          Text(item['t'] as String, style: const TextStyle(color: _text, fontSize: 14.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String? institution;
  final IconData icon;
  final List<Map<String, dynamic>>? gridItems;
  final List<Map<String, dynamic>>? listItems;

  OnboardingData({
    required this.title,
    required this.description,
    this.institution,
    required this.icon,
    this.gridItems,
    this.listItems,
  });
}
