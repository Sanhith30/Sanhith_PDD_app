import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oral_ulcer_ai/splash_screen.dart';
import 'package:oral_ulcer_ai/onboarding_screen.dart';
import 'package:oral_ulcer_ai/login_page.dart';

void main() {
  setUp(() {
    // Mock SharedPreferences values for local test environment
    SharedPreferences.setMockInitialValues({});
  });

  group('Splash Screen Widget Tests', () {
    testWidgets('SplashScreen displays brand elements and institution text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(showOnboarding: true),
            '/onboarding': (_) => const Scaffold(body: Text('Onboarding')),
            '/login': (_) => const Scaffold(body: Text('Login')),
            '/dashboard': (_) => const Scaffold(body: Text('Dashboard')),
          },
        ),
      );

      // Verify the title is present
      expect(find.text('Oral Ulcer AI'), findsOneWidget);

      // Verify the institution subtitle is present
      expect(find.text('Saveetha Dental College & Hospital'), findsOneWidget);

      // Verify version mark is present
      expect(find.text('v2.0'), findsOneWidget);

      // Verify bottom helper tag is present
      expect(find.text('CLINICAL DECISION SUPPORT'), findsOneWidget);

      // Pump and settle to let all transition timers exhaust
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('Onboarding Screen Widget Tests', () {
    testWidgets('OnboardingScreen displays slides and handles skip button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/onboarding',
          routes: {
            '/onboarding': (_) => const OnboardingScreen(),
            '/login': (_) => const Scaffold(body: Text('Login Page')),
          },
        ),
      );

      // Verify welcome slide elements are present
      expect(find.text('Welcome to\nOral Ulcer AI'), findsOneWidget);
      expect(find.text('AI-powered clinical decision support for oral ulcerative lesions'), findsOneWidget);

      // Verify "Skip" button exists
      final skipButton = find.text('Skip');
      expect(skipButton, findsOneWidget);

      // Verify "Get Started" button exists on the first slide
      expect(find.text('Get Started'), findsOneWidget);

      // Tap skip to finish onboarding
      await tester.tap(skipButton);
      await tester.pumpAndSettle();
      
      // Verify it successfully navigated to login
      expect(find.text('Login Page'), findsOneWidget);
    });
  });

  group('Login Screen Widget Tests', () {
    testWidgets('LoginPage renders input fields and switches between sign-in and sign-up',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginPage(),
            '/dashboard': (_) => const Scaffold(body: Text('Dashboard Page')),
          },
        ),
      );

      // Verify initial sign-in mode fields
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to your clinician account'), findsOneWidget);
      
      // Fields
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);

      // Check text entering on Email field
      await tester.enterText(find.byType(TextField).first, 'doctor@saveetha.ac.in');
      expect(find.text('doctor@saveetha.ac.in'), findsOneWidget);

      // Switch to sign-up mode
      final signUpToggle = find.text('Sign up');
      expect(signUpToggle, findsOneWidget);
      await tester.tap(signUpToggle);
      await tester.pumpAndSettle();

      // Verify fields in sign-up mode
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Register as a clinician'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget); // Full Name field
    });
  });
}
