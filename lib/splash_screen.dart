import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
//  Oral Ulcer AI — Splash Screen
//  Design: "Surgical Luxury" — dark maroon · warm gold · ivory
//  Logo: SDC monogram painted locally — 100% offline, no network required
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  final bool showOnboarding;
  const SplashScreen({super.key, this.showOnboarding = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Arc that sweeps around the logo
  late AnimationController _arcController;
  late Animation<double>   _arcSweep;
  late Animation<double>   _arcFade;

  // Logo fade + scale
  late AnimationController _logoController;
  late Animation<double>   _logoFade;
  late Animation<double>   _logoScale;

  // Staggered text reveal
  late AnimationController _textController;
  late Animation<double>   _titleFade;
  late Animation<Offset>   _titleSlide;
  late Animation<double>   _subtitleFade;
  late Animation<double>   _tagFade;

  // Arc breathing after it completes
  late AnimationController _breatheController;
  late Animation<double>   _breatheOpacity;

  // Thin gold progress line at bottom
  late AnimationController _lineController;
  late Animation<double>   _lineProgress;

  @override
  void initState() {
    super.initState();

    // 1 ── Arc sweeps 0→100% in 1800 ms
    _arcController = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this);
    _arcSweep = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _arcController, curve: Curves.easeInOutCubic));
    _arcFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _arcController,
            curve: const Interval(0.0, 0.18, curve: Curves.easeIn)));

    // 2 ── Logo appears at 900 ms
    _logoController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));

    // 3 ── Text stagger starts at 1500 ms
    _textController = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this);
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textController,
            curve: const Interval(0.00, 0.55, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero).animate(
        CurvedAnimation(parent: _textController,
            curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic)));
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textController,
            curve: const Interval(0.35, 0.80, curve: Curves.easeOut)));
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textController,
            curve: const Interval(0.65, 1.00, curve: Curves.easeOut)));

    // 4 ── Arc gently breathes after 1900 ms
    _breatheController = AnimationController(
        duration: const Duration(milliseconds: 2800), vsync: this);
    _breatheOpacity = Tween<double>(begin: 0.60, end: 1.0).animate(
        CurvedAnimation(parent: _breatheController,
            curve: Curves.easeInOutSine));

    // 5 ── Progress line fills over 3000 ms
    _lineController = AnimationController(
        duration: const Duration(milliseconds: 3000), vsync: this);
    _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _lineController, curve: Curves.easeInOut));

    // ── Orchestration ──────────────────────────────────────────────────────
    _arcController.forward();
    _lineController.forward();

    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) _logoController.forward(); });

    Future.delayed(const Duration(milliseconds: 1500),
        () { if (mounted) _textController.forward(); });

    Future.delayed(const Duration(milliseconds: 1900),
        () { if (mounted) _breatheController.repeat(reverse: true); });

    // Navigate to onboarding (first launch) or login
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          widget.showOnboarding ? '/onboarding' : '/login',
        );
      }
    });
  }

  @override
  void dispose() {
    _arcController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _breatheController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFF120508); // near-black maroon
  static const Color _surface = Color(0xFF1E0A10); // lifted card surface
  static const Color _maroon  = Color(0xFF7B1E3A); // brand maroon
  static const Color _gold    = Color(0xFFC9A84C); // warm gold
  static const Color _ivory   = Color(0xFFF5EDE0); // warm white
  static const Color _muted   = Color(0xFF8A6570); // muted text

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _arcController,
          _logoController,
          _textController,
          _breatheController,
          _lineController,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),
              _buildMainContent(),
              _buildProgressLine(),
              _buildVersionMark(),
            ],
          );
        },
      ),
    );
  }

  // ── Subtle radial background ───────────────────────────────────────────────
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: [Color(0xFF2B0D18), _bg],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }

  // ── Centre column ──────────────────────────────────────────────────────────
  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),

          // Logo + precision arc
          _buildLogoWithArc(),

          const SizedBox(height: 52),

          // App name
          FadeTransition(
            opacity: _titleFade,
            child: SlideTransition(
              position: _titleSlide,
              child: const Text(
                "Oral Ulcer AI",
                style: TextStyle(
                  color: _ivory,
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 5.0,
                  height: 1.0,
                ),
              ),
            ),
          ),

          // Gold divider rule
          FadeTransition(
            opacity: _subtitleFade,
            child: Container(
              width: 32,
              height: 1,
              color: _gold.withOpacity(0.7),
              margin: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          // Institution name
          FadeTransition(
            opacity: _subtitleFade,
            child: const Text(
              "Saveetha Dental College & Hospital",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.8,
                height: 1.6,
              ),
            ),
          ),

          const Spacer(flex: 3),

          // Bottom tag line
          FadeTransition(
            opacity: _tagFade,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 18, height: 0.6,
                    color: _gold.withOpacity(0.5)),
                const SizedBox(width: 10),
                Text(
                  "CLINICAL DECISION SUPPORT",
                  style: TextStyle(
                    color: _gold.withOpacity(0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.4,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                    width: 18, height: 0.6,
                    color: _gold.withOpacity(0.5)),
              ],
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── Logo circle + sweeping arc ─────────────────────────────────────────────
  Widget _buildLogoWithArc() {
    const double sz = 180;

    return SizedBox(
      width: sz + 36,
      height: sz + 36,
      child: Stack(
        alignment: Alignment.center,
        children: [

          // Precision sweeping arc (the signature animation)
          Opacity(
            opacity: (_arcFade.value * _breatheOpacity.value).clamp(0.0, 1.0),
            child: CustomPaint(
              size: const Size(sz + 36, sz + 36),
              painter: _PrecisionArcPainter(
                sweep: _arcSweep.value,
                color: _gold,
              ),
            ),
          ),

          // Thin inner ring (static, appears with logo)
          FadeTransition(
            opacity: _logoFade,
            child: Container(
              width: sz + 2,
              height: sz + 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _maroon.withOpacity(0.4),
                  width: 0.8,
                ),
              ),
            ),
          ),

          // Logo card
          FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surface,
                  boxShadow: [
                    BoxShadow(
                      color: _maroon.withOpacity(0.35),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                // ── LOGO — Premium Image Asset ────
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/premium_medical_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Thin gold progress line ────────────────────────────────────────────────
  Widget _buildProgressLine() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SizedBox(
        height: 2,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _lineProgress.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gold.withOpacity(0.0),
                  _gold.withOpacity(0.85),
                  _gold,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top-right version label ────────────────────────────────────────────────
  Widget _buildVersionMark() {
    return Positioned(
      top: 54, right: 28,
      child: FadeTransition(
        opacity: _tagFade,
        child: Text(
          "v2.0",
          style: TextStyle(
            color: _muted.withOpacity(0.45),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  PRECISION ARC PAINTER
//  Draws a sweeping arc with:
//   • fading tail that brightens toward the head
//   • glowing leading-edge dot
//   • cardinal tick marks + 45° dot markers for a clinical instrument feel
// ══════════════════════════════════════════════════════════════════════════════

class _PrecisionArcPainter extends CustomPainter {
  final double sweep; // 0.0 → 1.0
  final Color  color;

  const _PrecisionArcPainter({required this.sweep, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // ── Cardinal tick marks (12, 3, 6, 9 o'clock) ────────────────────────
    final tickPaint = Paint()
      ..color = color.withOpacity(0.20)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi - math.pi / 2;
      final inner = Offset(
          center.dx + math.cos(angle) * (radius - 8),
          center.dy + math.sin(angle) * (radius - 8));
      final outer = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // ── Small dots at 45° positions ───────────────────────────────────────
    final dotPaint = Paint()..color = color.withOpacity(0.13);
    for (int i = 0; i < 8; i++) {
      if (i % 2 == 0) continue; // skip cardinal positions
      final angle = (i / 8) * 2 * math.pi - math.pi / 2;
      canvas.drawCircle(
        Offset(center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius),
        1.2, dotPaint,
      );
    }

    if (sweep <= 0) return;

    // ── Sweeping arc with gradient fade tail ──────────────────────────────
    const startAngle = -math.pi / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    const segments = 64;

    for (int i = 0; i < segments; i++) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      if (t1 > sweep) break;

      // Opacity: near-zero at tail, full at head
      final relPos = t0 / sweep;
      final opacity = relPos < 0.30
          ? (relPos / 0.30) * 0.55
          : 0.55 + ((relPos - 0.30) / 0.70) * 0.45;

      canvas.drawArc(
        arcRect,
        startAngle + t0 * 2 * math.pi,
        (t1 - t0) * 2 * math.pi + 0.003,
        false,
        Paint()
          ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── Leading-edge glow + bright dot ────────────────────────────────────
    final headAngle = startAngle + sweep * 2 * math.pi;
    final headPos = Offset(
      center.dx + math.cos(headAngle) * radius,
      center.dy + math.sin(headAngle) * radius,
    );

    // Outer soft glow
    canvas.drawCircle(headPos, 8,
        Paint()..color = color.withOpacity(0.10));
    // Mid glow
    canvas.drawCircle(headPos, 4.5,
        Paint()..color = color.withOpacity(0.22));
    // Bright core dot
    canvas.drawCircle(headPos, 2.6,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PrecisionArcPainter old) =>
      old.sweep != sweep || old.color != color;
}


// ══════════════════════════════════════════════════════════════════════════════
//  SDC MONOGRAM PAINTER  (fallback if image fails to load)
//  Renders "SDC" in a clean gold typographic style inside the circle
// ══════════════════════════════════════════════════════════════════════════════

class _SDCMonogramPainter extends CustomPainter {
  final Color gold;
  final Color ivory;

  const _SDCMonogramPainter({required this.gold, required this.ivory});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring
    canvas.drawCircle(
      center, size.width / 2 - 4,
      Paint()
        ..color = gold.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // "SDC" text
    final tp = TextPainter(
      text: TextSpan(
        text: "SDC",
        style: TextStyle(
          color: gold,
          fontSize: size.width * 0.28,
          fontWeight: FontWeight.w300,
          letterSpacing: size.width * 0.04,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    // Small subtitle text
    final sub = TextPainter(
      text: TextSpan(
        text: "SAVEETHA",
        style: TextStyle(
          color: ivory.withOpacity(0.35),
          fontSize: size.width * 0.09,
          fontWeight: FontWeight.w400,
          letterSpacing: size.width * 0.018,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    sub.paint(
      canvas,
      Offset(center.dx - sub.width / 2,
          center.dy + tp.height / 2 + size.width * 0.04),
    );
  }

  @override
  bool shouldRepaint(_SDCMonogramPainter old) => false;
}