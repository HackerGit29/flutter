import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:aricie/screens/profile/edit_profile_screen.dart';
import 'package:aricie/screens/profile/profile_screen.dart';
import 'package:dartz/dartz.dart';

import '../../helpers/screen_test_helper.dart';
import '../../helpers/supabase_test_helper.dart';

Widget _profileRoute(BuildContext context) => const ProfileScreen();
Widget _rootRoute(BuildContext context) => const _RootPlaceholder();

class _FailingGetCurrentUserAuthRepository extends FakeAuthRepository {
  @override
  Future<Either<Failure, User?>> getCurrentUser() async =>
      Left(const ServerFailure('Impossible de charger le profil'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository authRepo;

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
    authRepo = FakeAuthRepository(currentUser: kScreenUser);
    sl.registerLazySingleton<AuthRepository>(() => authRepo);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap() => ChangeNotifierProvider(
        create: (_) => SubscriptionProvider(),
        child: const MaterialApp(
          initialRoute: '/profile',
          routes: {
            '/profile': _profileRoute,
            '/': _rootRoute,
          },
        ),
      );

  group('ProfileScreen', () {
    testWidgets('shows a loading indicator first', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the user email once loaded', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text(kScreenUser.email), findsOneWidget);
      expect(find.text('Administration'), findsNothing);
    });

    testWidgets('shows the admin entry for an admin user', (tester) async {
      authRepo.currentUser = kScreenUser.copyWith(role: Role.admin);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Administration'), findsOneWidget);
    });

    testWidgets('shows an error state with a retry button on failure',
        (tester) async {
      sl.unregister<AuthRepository>();
      sl.registerLazySingleton<AuthRepository>(
          () => _FailingGetCurrentUserAuthRepository());

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Impossible de charger le profil'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Réessayer'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Impossible de charger le profil'), findsOneWidget);
    });

    testWidgets('navigating to edit profile and back refreshes the display name',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('tapping logout signs out and navigates to the root route',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Déconnexion'));
      await tester.pumpAndSettle();

      expect(find.byType(_RootPlaceholder), findsOneWidget);
    });
  });
}

class _RootPlaceholder extends StatelessWidget {
  const _RootPlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Root'));
}
