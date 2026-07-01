import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/realtime_power_service.dart';
import 'package:aricie/widgets/live_consumption_indicator.dart';

RealtimePowerReading _reading({
  String id = 'a',
  String name = 'Appareil',
  double kwh = 0,
  double? watts,
  DateTime? updatedAt,
}) {
  return RealtimePowerReading(
    applianceId: id,
    applianceName: name,
    powerKwh: kwh,
    instantPowerW: watts,
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('isReadingLive', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('vrai si mise à jour il y a moins de 30 s', () {
      expect(
        isReadingLive(now.subtract(const Duration(seconds: 10)), now: now),
        isTrue,
      );
    });

    test('faux si mise à jour il y a 30 s ou plus', () {
      expect(
        isReadingLive(now.subtract(const Duration(seconds: 30)), now: now),
        isFalse,
      );
      expect(
        isReadingLive(now.subtract(const Duration(minutes: 5)), now: now),
        isFalse,
      );
    });
  });

  group('totalInstantWatts', () {
    test('somme les puissances instantanées, les nulls comptent pour 0', () {
      final readings = [
        _reading(id: 'a', watts: 100),
        _reading(id: 'b', watts: 250),
        _reading(id: 'c', watts: null),
      ];
      expect(totalInstantWatts(readings), 350);
    });

    test('renvoie 0 pour une liste vide', () {
      expect(totalInstantWatts([]), 0);
    });
  });

  group('totalKwh', () {
    test('somme les énergies cumulées', () {
      final readings = [
        _reading(id: 'a', kwh: 1.5),
        _reading(id: 'b', kwh: 2.25),
      ];
      expect(totalKwh(readings), 3.75);
    });
  });

  group('sortedByInstantPower', () {
    test('trie par puissance instantanée décroissante', () {
      final readings = [
        _reading(id: 'a', watts: 100),
        _reading(id: 'b', watts: 500),
        _reading(id: 'c', watts: 300),
      ];
      final sorted = sortedByInstantPower(readings);
      expect(sorted.map((r) => r.applianceId), ['b', 'c', 'a']);
    });

    test('place les lectures sans puissance instantanée en dernier', () {
      final readings = [
        _reading(id: 'a', watts: null, kwh: 9),
        _reading(id: 'b', watts: 10),
      ];
      final sorted = sortedByInstantPower(readings);
      expect(sorted.first.applianceId, 'b');
      expect(sorted.last.applianceId, 'a');
    });

    test('ne mute pas la liste source', () {
      final readings = [
        _reading(id: 'a', watts: 1),
        _reading(id: 'b', watts: 2),
      ];
      sortedByInstantPower(readings);
      expect(readings.map((r) => r.applianceId), ['a', 'b']);
    });
  });

  group('formatWatts', () {
    test('ajoute un séparateur de milliers', () {
      expect(formatWatts(1250), '1 250 W');
      expect(formatWatts(999), '999 W');
      expect(formatWatts(1000000), '1 000 000 W');
    });

    test('arrondit à l\'entier', () {
      expect(formatWatts(120.7), '121 W');
      expect(formatWatts(0), '0 W');
    });
  });
}
