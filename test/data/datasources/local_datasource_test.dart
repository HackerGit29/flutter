import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aricie/data/datasources/local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDataSource dataSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dataSource = LocalDataSource();
  });

  group('LocalDataSource', () {
    test('cacheSession caches session properly and getCachedUserId reads it', () async {
      await dataSource.cacheSession('user-123', 'test@test.com');

      final cachedId = await dataSource.getCachedUserId();
      expect(cachedId, 'user-123');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_session'), true);
      expect(prefs.getString('user_id'), 'user-123');
      expect(prefs.getString('user_email'), 'test@test.com');
    });

    test('getCachedUserId returns null if no session', () async {
      final cachedId = await dataSource.getCachedUserId();
      expect(cachedId, null);
    });

    test('clearSession removes all session data', () async {
      await dataSource.cacheSession('user-123', 'test@test.com');
      await dataSource.clearSession();

      final cachedId = await dataSource.getCachedUserId();
      expect(cachedId, null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_session'), null);
      expect(prefs.getString('user_id'), null);
      expect(prefs.getString('user_email'), null);
    });
  });
}
