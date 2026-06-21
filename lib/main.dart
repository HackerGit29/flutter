import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'core/constants.dart';

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
    final supabaseUrl = AppConstants.supabaseUrl;
    final supabaseAnonKey = AppConstants.supabaseAnonKey;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw ArgumentError(
        'Supabase URL et clé anonyme requises. '
        'Lancez avec: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
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