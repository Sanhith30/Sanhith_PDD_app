import 'package:flutter/material.dart';
import 'db/local_db.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color _primary = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _bg      = Color(0xFFFAF7F4);

  final List<OnboardingData> _slides = [
    OnboardingData(
      title: "Welcome to\nOral Ulcer AI",
      description: "AI-powered clinical decision support for oral ulcerative lesions",
      institution: "Saveetha Dental College & Hospital",
      icon: Icons.face_retouching_natural_rounded,
      isFirst: true,
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
      isLast: true,
    ),
  ];

  void _finish() async {
    await LocalDb.instance.markOnboardingDone();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8B2E4A), Color(0xFF4A0E1F)],
              ),
            ),
          ),
          
          // Page View
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemBuilder: (context, idx) => _buildSlide(_slides[idx]),
          ),

          // Top Skip Button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text("Skip", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (idx) => _buildIndicator(idx)),
                ),
                const SizedBox(height: 32),
                
                // Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == 0 ? "Get Started" : (_currentPage == _slides.length - 1 ? "Start Using Oral Ulcer AI" : "Continue"),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Circle
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 40)],
            ),
            child: Center(
              child: Icon(data.icon, color: Colors.white, size: 80),
            ),
          ),
          const SizedBox(height: 50),
          
          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Container(width: 60, height: 3, color: Colors.white38),
          const SizedBox(height: 30),
          
          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
          ),
          
          if (data.institution != null) ...[
            const SizedBox(height: 12),
            Text(data.institution!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],

          if (data.gridItems != null) ...[
            const SizedBox(height: 30),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: data.gridItems!.map((item) => _buildGridItem(item)).toList(),
            ),
          ],

          if (data.listItems != null) ...[
            const SizedBox(height: 30),
            Column(
              children: data.listItems!.map((item) => _buildListItem(item)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item['i'] as IconData, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(item['t'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(item['s'] as String, style: TextStyle(color: Colors.white60, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(item['i'] as IconData, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(item['t'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    bool active = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: active ? 24 : 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white38,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String? institution;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final List<Map<String, dynamic>>? gridItems;
  final List<Map<String, dynamic>>? listItems;

  OnboardingData({
    required this.title,
    required this.description,
    this.institution,
    required this.icon,
    this.isFirst = false,
    this.isLast = false,
    this.gridItems,
    this.listItems,
  });
}
