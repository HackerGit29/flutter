import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/widgets/common_header.dart';
import 'package:aricie/screens/profile/profile_screen.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:dartz/dartz.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return Right(User(
      id: 'user-123',
      email: 'test@aricie.com',
      role: Role.user,
      status: UserStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ));
  }

  @override
  Future<Either<Failure, User>> login(String email, String password) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, User>> register(String email, String password) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, void>> logout() async => const Right(null);
  @override
  Future<Either<Failure, String>> refreshToken() async => const Right('');
  @override
  Future<Either<Failure, void>> resetPassword(String email) async => const Right(null);
  @override
  Future<Either<Failure, void>> confirmPasswordReset(String email, String token, String newPassword) async => const Right(null);
  @override
  Future<Either<Failure, void>> changePassword(String currentPassword, String newPassword) async => const Right(null);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
    sl.registerLazySingleton<AuthRepository>(() => FakeAuthRepository());
  });

  tearDownAll(() async {
    await sl.reset();
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<SubscriptionProvider>(
      create: (_) => SubscriptionProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('CommonHeader Widget', () {
    testWidgets('renders title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const CommonHeader(title: 'Test Header')));

      expect(find.text('Test Header'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('tapping profile icon navigates to ProfileScreen', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const CommonHeader(title: 'Test Header')));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
