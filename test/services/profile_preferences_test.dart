import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/profile_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProfilePreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = ProfilePreferences();
  });

  test('renvoie null quand aucun nom n\'est défini', () async {
    expect(await prefs.getDisplayName(), isNull);
  });

  test('enregistre puis relit le nom (trim appliqué)', () async {
    await prefs.setDisplayName('  Lance N.  ');
    expect(await prefs.getDisplayName(), 'Lance N.');
  });

  test('un nom vide efface la valeur (renvoie null)', () async {
    await prefs.setDisplayName('Lance');
    await prefs.setDisplayName('   ');
    expect(await prefs.getDisplayName(), isNull);
  });
}
