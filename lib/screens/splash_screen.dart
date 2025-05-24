import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to onboarding screen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(delay: 200.ms)
                .then()
                .shimmer(duration: 1200.ms),
            const SizedBox(height: 24),
            Text(
              'Aricie',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 800.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              'Gérez votre énergie intelligemment',
              style: Theme.of(context).textTheme.bodyLarge,
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 800.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}