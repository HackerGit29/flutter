import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Lancer l'application immédiatement
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
  
  // Initialiser Supabase et les notifications en arrière-plan
  Future.microtask(() async {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://csawyexvpblmvahftjuo.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzYXd5ZXh2cGJsbXZhaGZ0anVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYwNzI5NjIsImV4cCI6MjA1MTY0ODk2Mn0.qM2kNcXuXD5BcLhUjS0tNsLwHOGtYmxlJGXiSIYg5o4',
    );

    // Initialiser le service de notification
    final notificationService = NotificationService();
    
    // Demander les permissions de notification (Android 13+)
    await notificationService.requestPermissions();
    
    // Configurer une notification quotidienne
    await notificationService.showPeriodicNotification(
      id: 1,
      title: 'Rappel quotidien',
      body: 'N\'oubliez pas de vérifier votre consommation d\'énergie',
      repeatInterval: RepeatInterval.daily,
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Aricie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}