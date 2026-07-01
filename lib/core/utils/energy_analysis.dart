import '../../domain/entities/energy_data.dart';

/// Consommation totale (kWh) agrégée pour un jour calendaire.
class DailyConsumption {
  final DateTime day;
  final double kwh;

  const DailyConsumption(this.day, this.kwh);
}

/// Agrège une liste d'[EnergyData] (potentiellement plusieurs appareils par
/// jour) en un total kWh par jour calendaire, trié par date croissante.
///
/// C'est la base de la vue « jour par jour » : chaque point = un jour.
List<DailyConsumption> aggregateByDay(List<EnergyData> data) {
  final Map<DateTime, double> byDay = {};
  for (final e in data) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    byDay[day] = (byDay[day] ?? 0) + e.kwh;
  }
  final days = byDay.keys.toList()..sort();
  return [for (final d in days) DailyConsumption(d, byDay[d]!)];
}

/// Jour de pic de consommation d'une période et repères de comparaison.
class PeakInfo {
  /// Jour dont la consommation est la plus élevée.
  final DailyConsumption peak;

  /// Consommation journalière moyenne sur la période.
  final double average;

  const PeakInfo({required this.peak, required this.average});

  /// Écart du pic par rapport à la moyenne, en pourcentage.
  /// Renvoie 0 si la moyenne est nulle (pas de division par zéro).
  double get percentAboveAverage =>
      average <= 0 ? 0 : (peak.kwh - average) / average * 100;
}

/// Détecte le jour de pic (consommation maximale) et la moyenne journalière
/// d'une série jour par jour. Renvoie `null` si la série est vide.
///
/// En cas d'égalité, le premier jour atteint (le plus ancien) est retenu.
PeakInfo? detectPeak(List<DailyConsumption> series) {
  if (series.isEmpty) return null;
  var peak = series.first;
  double sum = 0;
  for (final d in series) {
    sum += d.kwh;
    if (d.kwh > peak.kwh) peak = d;
  }
  return PeakInfo(peak: peak, average: sum / series.length);
}
