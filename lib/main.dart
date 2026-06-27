import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart';
import 'screens/update/update_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'services/tips_realtime_service.dart';
import 'core/constants.dart';
import 'core/di/injection_container.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

  final notificationService = NotificationService();
  notificationService.onNotificationTap = (payload) {
    if (payload == 'update') {
      // L'user a tapé la notification — vérifier et ouvrir UpdateScreen
      UpdateService.instance.checkForUpdate().then((info) {
        if (info.updateAvailable) {
          navigateToUpdate(info);
        }
      });
    }
  };
  await notificationService.init();
  await notificationService.requestPermissions();

  TipsRealtimeService.instance.start();

  await notificationService.showPeriodicNotification(
    id: 1,
    title: 'Rappel quotidien',
    body: 'N\'oubliez pas de vérifier votre consommation d\'énergie',
    repeatInterval: RepeatInterval.daily,
  );

  await initDependencies();
  await UpdateService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: const MyApp(),
    ),
  );
  // Le check de MAJ se fait dans HomeScreen.initState, après authentification.
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Aricie',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}

Future<void> navigateToUpdate(UpdateInfo info) async {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => UpdateScreen(updateInfo: info),
    ),
  );
}