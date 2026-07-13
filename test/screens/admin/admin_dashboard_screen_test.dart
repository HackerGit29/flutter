import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/admin/admin_box_detail_screen.dart';
import 'package:aricie/screens/admin/admin_dashboard_screen.dart';

import '../../domain/usecases/admin/admin_mocks.dart';
import '../../helpers/supabase_test_helper.dart';

Widget _dashboardRoute(BuildContext context) => const AdminDashboardScreen();
Widget _rootRoute(BuildContext context) => const _RootPlaceholder();

class _RootPlaceholder extends StatelessWidget {
  const _RootPlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Root'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminRepo adminRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) async => emptyOk(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  setUp(() {
    adminRepo = MockAdminRepo();
    sl.registerLazySingleton<AdminRepository>(() => adminRepo);
    sl.registerLazySingleton<AuthRepository>(() => MockAuthRepo());
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap() => const MaterialApp(
        initialRoute: '/dashboard',
        routes: {
          '/dashboard': _dashboardRoute,
          '/': _rootRoute,
        },
      );

  group('AdminDashboardScreen', () {
    testWidgets('redirects a non-admin user to the root route', (tester) async {
      sl.unregister<AuthRepository>();
      sl.registerLazySingleton<AuthRepository>(() => MockAuthRepo(user: kRegularUser));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(_RootPlaceholder), findsOneWidget);
    });

    testWidgets('shows tab counts once loaded for an admin user', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Boîtiers (1)'), findsOneWidget);
      expect(find.text('Utilisateurs (2)'), findsOneWidget);
      expect(find.text('Licences (1)'), findsOneWidget);
      expect(find.text(kBox.name), findsOneWidget);
    });

    testWidgets('tapping a box navigates to AdminBoxDetailScreen', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kBox.name));
      await tester.pumpAndSettle();

      expect(find.byType(AdminBoxDetailScreen), findsOneWidget);
    });

    testWidgets('switching to the users tab lists users with role and status',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Utilisateurs (2)'));
      await tester.pumpAndSettle();

      expect(find.text(kRegularUser.email), findsOneWidget);
      expect(find.text(kVipUser.email), findsOneWidget);
    });

    testWidgets('create box dialog validates required fields', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(find.text('L\'UID matériel doit faire plus de 8 caractères'), findsOneWidget);
    });

    testWidgets('create box dialog succeeds and shows a confirmation snackbar',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'UID matériel *'), 'ESP32-A1B2C3D4');
      await tester.enterText(
          find.widgetWithText(TextField, 'Nom *'), 'Boîtier cuisine');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Propriétaire *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kRegularUser.email).last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(find.text('Boîtier "Boîtier cuisine" créé avec 3 appareils'), findsOneWidget);
    });

    testWidgets('checking for updates with none available shows a snackbar',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.system_update_alt));
      await tester.pumpAndSettle();

      expect(find.text('Aucune mise à jour disponible'), findsOneWidget);
    });
  });
}
