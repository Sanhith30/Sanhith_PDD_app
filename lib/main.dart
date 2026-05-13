import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'login_page.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'dashboard.dart';
import 'navigation_container.dart';
import 'new_case_page.dart';
import 'image_upload_page.dart';
import 'ai_result_screen.dart';
import 'history_screen.dart';
import 'case_detail_page.dart';
import 'analytics_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'change_password_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No longer using sqflite on Windows/Linux

  // Initialise local SQLite database (creates tables + seeds default account)
  await LocalDb.instance.db;

  // Check first-launch flag for onboarding
  final bool onboardingDone = await LocalDb.instance.isOnboardingDone();

  runApp(SaveethaOralSentry(showOnboarding: !onboardingDone));
}

class SaveethaOralSentry extends StatelessWidget {
  final bool showOnboarding;
  const SaveethaOralSentry({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saveetha Oral Sentry',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B1E3A),
          surface: const Color(0xFFFFFFFF),
          background: const Color(0xFFFAF7F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F4),
        primaryColor: const Color(0xFF7B1E3A),
        useMaterial3: true,
        fontFamily: 'Roboto', // Standard medical/clean font
      ),
      // Splash always shows first; it then routes to onboarding or login
      initialRoute: '/',
      routes: {
        '/':              (_) => SplashScreen(showOnboarding: showOnboarding),
        '/onboarding':    (_) => const OnboardingScreen(),
        '/login':         (_) => const LoginPage(),
        '/sign_up':       (_) => const SignUpPage(),
        '/forgot_password': (_) => const ForgotPasswordPage(),
        '/dashboard':     (_) => const MainScaffold(),
        '/new_case':      (_) => const NewCasePage(),
        '/image_upload':  (_) => const ImageUploadPage(),
        '/ai_result':     (_) => const AiResultScreen(),
        '/history':       (_) => const HistoryScreen(),
        '/case_detail':   (_) => const CaseDetailPage(),
        '/analytics':     (_) => const AnalyticsPage(),
        '/profile':       (_) => const ProfilePage(),
        '/settings':      (_) => const SettingsPage(),
        '/change_password': (_) => const ChangePasswordPage(),
      },
    );
  }
}