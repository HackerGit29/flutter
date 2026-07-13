import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/screens/profile/edit_profile_screen.dart';

import '../../helpers/supabase_test_helper.dart';

Map<String, dynamic> _authJson({Map<String, dynamic>? userMetadata}) => {
      'access_token': 'access-token-1',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh-token-1',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'email': 'test@test.com',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': userMetadata ?? <String, dynamic>{},
      },
    };

late Future<http.Response> Function(http.Request) _handler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _handler = (request) async => emptyOk(request);
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) => _handler(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  tearDown(() async {
    _handler = (request) async => emptyOk(request);
    await Supabase.instance.client.auth.signOut();
  });

  Widget wrap() => const MaterialApp(home: EditProfileScreen(email: 'user@test.com'));

  group('EditProfileScreen', () {
    testWidgets('shows the read-only email and an empty name when signed out',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('user@test.com'), findsOneWidget);
      final nameField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Nom d\'affichage'));
      expect(nameField.controller?.text, '');
    });

    testWidgets('prefills the display name from the account metadata',
        (tester) async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson(userMetadata: {'display_name': 'Tony'}));
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Tony'), findsOneWidget);
    });

    testWidgets('rejects a name longer than 40 characters', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom d\'affichage'), 'a' * 41);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
      await tester.pump();

      expect(find.text('40 caractères maximum'), findsOneWidget);
    });

    testWidgets('saving pops with true and shows a confirmation', (tester) async {
      late http.Request captured;
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/auth/v1/user') {
          captured = request;
          return jsonOk(request, {
            'id': 'user-1',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          });
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');

      final navigatorKey = GlobalKey<NavigatorState>();
      bool? poppedValue = false;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(email: 'user@test.com'),
                ),
              );
            },
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom d\'affichage'), 'Tony Az');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
      // Navigator.pop() alongside the snackbar triggers a page transition, so
      // pumpAndSettle would keep pumping until the SnackBar's own 4s display
      // timer also elapses and dismisses it. Use plain pumps instead.
      await tester.pump();
      await tester.pump();

      expect(find.text('Profil mis à jour.'), findsOneWidget);
      expect(poppedValue, true);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['data']['display_name'], 'Tony Az');
    });
  });
}
