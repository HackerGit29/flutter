import 'dart:async';
import 'package:flutter/material.dart';
import '../services/realtime_power_service.dart';

/// Durée au-delà de laquelle une lecture n'est plus considérée « live ».
const Duration kLiveThreshold = Duration(seconds: 30);

/// Une lecture est « live » si sa dernière mise à jour est plus récente que
/// [kLiveThreshold]. `now` est injectable pour les tests.
bool isReadingLive(DateTime updatedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return reference.difference(updatedAt) < kLiveThreshold;
}

/// Somme des puissances instantanées (W) des lectures (les valeurs nulles
/// comptent pour 0). Représente l'impact immédiat des usages en cours.
double totalInstantWatts(List<RealtimePowerReading> readings) {
  return readings.fold<double>(0.0, (acc, r) => acc + (r.instantPowerW ?? 0));
}

/// Somme des énergies cumulées (kWh) des lectures.
double totalKwh(List<RealtimePowerReading> readings) {
  return readings.fold<double>(0.0, (acc, r) => acc + r.powerKwh);
}

/// Trie les lectures par puissance instantanée décroissante (les lectures sans
/// puissance instantanée passent après), départage par énergie cumulée.
List<RealtimePowerReading> sortedByInstantPower(
  List<RealtimePowerReading> readings,
) {
  final sorted = readings.toList();
  sorted.sort((a, b) {
    final byWatts = (b.instantPowerW ?? -1).compareTo(a.instantPowerW ?? -1);
    if (byWatts != 0) return byWatts;
    return b.powerKwh.compareTo(a.powerKwh);
  });
  return sorted;
}

/// Formate une puissance en watts avec séparateur de milliers (ex. `1 250 W`).
String formatWatts(double watts) {
  final rounded = watts.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer W';
}

/// Carte « conso temps réel » : met en avant la puissance instantanée (W)
/// consommée à l'instant T, avec le détail par appareil (tous les appareils,
/// triés par impact décroissant). Alimentée par [RealtimePowerService].
class LiveConsumptionIndicator extends StatefulWidget {
  final String userId;

  const LiveConsumptionIndicator({super.key, required this.userId});

  @override
  State<LiveConsumptionIndicator> createState() =>
      _LiveConsumptionIndicatorState();
}

class _LiveConsumptionIndicatorState extends State<LiveConsumptionIndicator> {
  StreamSubscription<RealtimePowerReading>? _sub;
  final List<RealtimePowerReading> _readings = [];

  @override
  void initState() {
    super.initState();
    RealtimePowerService.instance.start(widget.userId);
    _sub = RealtimePowerService.instance.stream.listen((r) {
      if (!mounted) return;
      setState(() {
        _readings.removeWhere((x) => x.applianceId == r.applianceId);
        _readings.add(r);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = sortedByInstantPower(_readings);
    final totalWatts = totalInstantWatts(_readings);
    final totalEnergy = totalKwh(_readings);
    final live = _readings.any((r) => isReadingLive(r.updatedAt));

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: live ? scheme.primary : scheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Conso temps réel',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  live ? 'en direct' : 'hors ligne',
                  style: TextStyle(
                    fontSize: 11,
                    color: live ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Puissance instantanée totale : l'impact immédiat des usages.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatWatts(totalWatts),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${totalEnergy.toStringAsFixed(2)} kWh cumulé',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Text(
                'En attente de télémétrie...',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ...sorted.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: isReadingLive(r.updatedAt)
                              ? scheme.primary
                              : scheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.applianceName.isEmpty
                                ? r.applianceId.substring(0, 8)
                                : r.applianceName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          r.instantPowerW != null
                              ? formatWatts(r.instantPowerW!)
                              : '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${r.powerKwh.toStringAsFixed(2)} kWh',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
