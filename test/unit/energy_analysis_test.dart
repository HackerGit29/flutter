import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/utils/energy_analysis.dart';
import 'package:aricie/domain/entities/energy_data.dart';

EnergyData _energy({
  required String appliance,
  required DateTime date,
  required double kwh,
}) {
  return EnergyData(
    id: '$appliance-${date.toIso8601String()}',
    userId: 'u1',
    applianceId: appliance,
    date: date,
    kwh: kwh,
    week: 1,
    month: date.month,
    year: date.year,
    createdAt: date,
  );
}

void main() {
  group('aggregateByDay', () {
    test('somme les appareils d\'un même jour', () {
      final data = [
        _energy(appliance: 'a', date: DateTime(2026, 6, 10), kwh: 2),
        _energy(appliance: 'b', date: DateTime(2026, 6, 10), kwh: 3),
        _energy(appliance: 'a', date: DateTime(2026, 6, 11), kwh: 1.5),
      ];
      final series = aggregateByDay(data);
      expect(series.length, 2);
      expect(series[0].day, DateTime(2026, 6, 10));
      expect(series[0].kwh, 5);
      expect(series[1].kwh, 1.5);
    });

    test('ignore l\'heure et normalise au jour calendaire', () {
      final data = [
        _energy(appliance: 'a', date: DateTime(2026, 6, 10, 8, 30), kwh: 1),
        _energy(appliance: 'a', date: DateTime(2026, 6, 10, 20, 0), kwh: 2),
      ];
      final series = aggregateByDay(data);
      expect(series.length, 1);
      expect(series.first.day, DateTime(2026, 6, 10));
      expect(series.first.kwh, 3);
    });

    test('trie par date croissante', () {
      final data = [
        _energy(appliance: 'a', date: DateTime(2026, 6, 12), kwh: 1),
        _energy(appliance: 'a', date: DateTime(2026, 6, 10), kwh: 1),
        _energy(appliance: 'a', date: DateTime(2026, 6, 11), kwh: 1),
      ];
      final days = aggregateByDay(data).map((d) => d.day.day).toList();
      expect(days, [10, 11, 12]);
    });

    test('renvoie une liste vide si aucune donnée', () {
      expect(aggregateByDay([]), isEmpty);
    });
  });

  group('detectPeak', () {
    test('renvoie null pour une série vide', () {
      expect(detectPeak([]), isNull);
    });

    test('identifie le jour de consommation maximale', () {
      final series = [
        DailyConsumption(DateTime(2026, 6, 10), 4),
        DailyConsumption(DateTime(2026, 6, 11), 9),
        DailyConsumption(DateTime(2026, 6, 12), 2),
      ];
      final peak = detectPeak(series)!;
      expect(peak.peak.day, DateTime(2026, 6, 11));
      expect(peak.peak.kwh, 9);
      expect(peak.average, closeTo(5, 0.001));
    });

    test('calcule l\'écart du pic à la moyenne en %', () {
      final series = [
        DailyConsumption(DateTime(2026, 6, 10), 5),
        DailyConsumption(DateTime(2026, 6, 11), 15),
      ];
      final peak = detectPeak(series)!;
      // moyenne = 10, pic = 15 → +50 %
      expect(peak.average, 10);
      expect(peak.percentAboveAverage, closeTo(50, 0.001));
    });

    test('en cas d\'égalité, retient le jour le plus ancien', () {
      final series = [
        DailyConsumption(DateTime(2026, 6, 10), 7),
        DailyConsumption(DateTime(2026, 6, 11), 7),
      ];
      expect(detectPeak(series)!.peak.day, DateTime(2026, 6, 10));
    });

    test('percentAboveAverage vaut 0 si la moyenne est nulle', () {
      final series = [DailyConsumption(DateTime(2026, 6, 10), 0)];
      expect(detectPeak(series)!.percentAboveAverage, 0);
    });
  });
}
