import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state should be light mode if no preference saved', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      
      // Wait for theme preference to be loaded async
      await Future.delayed(Duration.zero);

      expect(provider.isDarkMode, false);
      expect(provider.themeMode, ThemeMode.light);
    });

    test('initial state should be dark mode if preference is true', () async {
      SharedPreferences.setMockInitialValues({'is_dark_mode': true});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);

      expect(provider.isDarkMode, true);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('toggleTheme should switch theme and save in shared preferences', () async {
      SharedPreferences.setMockInitialValues({'is_dark_mode': false});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.isDarkMode, false);

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.toggleTheme();

      expect(provider.isDarkMode, true);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_dark_mode'), true);
    });
  });
}
