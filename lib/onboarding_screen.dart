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
                
                // Button / Swipe-to-Unlock Slider
                if (_currentPage == _slides.length - 1)
                  _SwipeToUnlockSlider(onSwipeComplete: _finish)
                else
                  ElevatedButton(
                    onPressed: () {
                      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == 0 ? "Get Started" : "Continue",
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
          // Dynamic scanner overlay for slides 2 and 3, static icon for slide 1
          if (data.isFirst)
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
            )
          else
            _ClinicalScanAnimator(innerIcon: data.icon),
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

// ══════════════════════════════════════════════════════════════════════════════
//  CLINICAL SCAN ANIMATOR
//  Displays a target-locked circular diagnostic sweep representing AI scanning
// ══════════════════════════════════════════════════════════════════════════════

class _ClinicalScanAnimator extends StatefulWidget {
  final IconData innerIcon;
  const _ClinicalScanAnimator({required this.innerIcon});

  @override
  State<_ClinicalScanAnimator> createState() => _ClinicalScanAnimatorState();
}

class _ClinicalScanAnimatorState extends State<_ClinicalScanAnimator>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sweepController, _pulseController]),
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanPainter(
            sweepProgress: _sweepController.value,
            pulseProgress: _pulseController.value,
          ),
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Center(
              child: Icon(
                widget.innerIcon,
                color: Colors.white.withOpacity(0.85),
                size: 80,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double sweepProgress; // 0.0 -> 1.0
  final double pulseProgress; // 0.0 -> 1.0

  const _ScanPainter({required this.sweepProgress, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(clipPath);

    // 1. Draw thin Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;

    const int gridDivisions = 6;
    for (int i = 1; i < gridDivisions; i++) {
      final x = (size.width / gridDivisions) * i;
      final y = (size.height / gridDivisions) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw pulsing hot-zones (lesion hotspots simulator)
    final hotZonePaint = Paint()..style = PaintingStyle.fill;
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final List<Offset> hotZones = [
      Offset(size.width * 0.35, size.height * 0.45),
      Offset(size.width * 0.65, size.height * 0.35),
      Offset(size.width * 0.50, size.height * 0.70),
    ];

    for (var zone in hotZones) {
      hotZonePaint.color = Colors.red.withOpacity(0.4 + 0.4 * pulseProgress);
      canvas.drawCircle(zone, 4.0, hotZonePaint);

      pulsePaint.color = Colors.red.withOpacity(0.8 * (1.0 - pulseProgress));
      canvas.drawCircle(zone, 4.0 + 12.0 * pulseProgress, pulsePaint);
    }

    // 3. Draw sweeping laser scanner
    final double laserY = size.height * sweepProgress;
    final laserGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.green.withOpacity(0.0),
          Colors.green.withOpacity(0.15 * (1.0 - (sweepProgress - 0.5).abs())),
          Colors.green.withOpacity(0.35 * (1.0 - (sweepProgress - 0.5).abs())),
          Colors.green.withOpacity(0.0),
        ],
        stops: const [0.0, 0.45, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(0, laserY - 25, size.width, laserY + 25));

    canvas.drawRect(Rect.fromLTRB(0, laserY - 20, size.width, laserY + 20), laserGlowPaint);

    final laserCorePaint = Paint()
      ..color = const Color(0xFFC9A84C) // Gold scan line
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(0, laserY), Offset(size.width, laserY), laserCorePaint);

    canvas.restore();

    // 4. Target crosshairs (outside clipping)
    final hudPaint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius + 4, Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
    );

    final double offset = radius * 0.707;
    canvas.drawLine(Offset(center.dx - offset - 6, center.dy - offset), Offset(center.dx - offset, center.dy - offset), hudPaint);
    canvas.drawLine(Offset(center.dx - offset, center.dy - offset - 6), Offset(center.dx - offset, center.dy - offset), hudPaint);

    canvas.drawLine(Offset(center.dx + offset + 6, center.dy - offset), Offset(center.dx + offset, center.dy - offset), hudPaint);
    canvas.drawLine(Offset(center.dx + offset, center.dy - offset - 6), Offset(center.dx + offset, center.dy - offset), hudPaint);

    canvas.drawLine(Offset(center.dx - offset - 6, center.dy + offset), Offset(center.dx - offset, center.dy + offset), hudPaint);
    canvas.drawLine(Offset(center.dx - offset, center.dy + offset + 6), Offset(center.dx - offset, center.dy + offset), hudPaint);

    canvas.drawLine(Offset(center.dx + offset + 6, center.dy + offset), Offset(center.dx + offset, center.dy + offset), hudPaint);
    canvas.drawLine(Offset(center.dx + offset, center.dy + offset + 6), Offset(center.dx + offset, center.dy + offset), hudPaint);
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.sweepProgress != sweepProgress || old.pulseProgress != pulseProgress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  SWIPE-TO-UNLOCK ENTRANCE SLIDER
//  Premium gesture-tracked slider button requiring swipe to access dashboard
// ══════════════════════════════════════════════════════════════════════════════

class _SwipeToUnlockSlider extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  const _SwipeToUnlockSlider({required this.onSwipeComplete});

  @override
  State<_SwipeToUnlockSlider> createState() => _SwipeToUnlockSliderState();
}

class _SwipeToUnlockSliderState extends State<_SwipeToUnlockSlider>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _dragController;
  late Animation<double> _dragAnimation;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _dragAnimation = _dragController.drive(Tween<double>(begin: 0.0, end: 0.0));
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDragWidth) {
    setState(() {
      _dragPosition = (_dragPosition + details.primaryDelta!).clamp(0.0, maxDragWidth);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDragWidth) {
    if (_dragPosition >= maxDragWidth * 0.85) {
      setState(() {
        _dragPosition = maxDragWidth;
      });
      widget.onSwipeComplete();
    } else {
      _dragAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _dragController, curve: Curves.easeOut),
      )..addListener(() {
          setState(() {
            _dragPosition = _dragAnimation.value;
          });
        });
      _dragController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double trackHeight = 56.0;
    const double handleSize = 48.0;
    const double padding = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDragWidth = constraints.maxWidth - handleSize - (padding * 2);

        return Container(
          width: double.infinity,
          height: trackHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF5E1428), // Darker brand maroon
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Swipe suggestion/guide hint text
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFC9A84C), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      "SWIPE TO START CLINICAL APP",
                      style: TextStyle(
                        color: const Color(0xFFFAF7F4).withOpacity(0.65),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Sliding Gold Handle with Clinician/Hospital Cross
              Positioned(
                left: padding + _dragPosition,
                top: padding,
                bottom: padding,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxDragWidth),
                  onHorizontalDragEnd: (details) => _onDragEnd(details, maxDragWidth),
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFC9A84C), // Gold
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded, // Gold Cross
                      color: Color(0xFF7B1E3A),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
