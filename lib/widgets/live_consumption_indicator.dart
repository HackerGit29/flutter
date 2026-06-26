import 'dart:async';
import 'package:flutter/material.dart';
import '../services/realtime_power_service.dart';

class LiveConsumptionIndicator extends StatefulWidget {
  final String userId;

  const LiveConsumptionIndicator({super.key, required this.userId});

  @override
  State<LiveConsumptionIndicator> createState() => _LiveConsumptionIndicatorState();
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

  bool _isLive(DateTime updatedAt) {
    return DateTime.now().difference(updatedAt).inSeconds < 30;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _readings.toList()
      ..sort((a, b) => b.powerKwh.compareTo(a.powerKwh));
    final top3 = sorted.take(3).toList();
    final total = _readings.fold<double>(0.0, (acc, r) => acc + r.powerKwh);
    final live = _readings.any((r) => _isLive(r.updatedAt));

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
                  'Conso live',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${total.toStringAsFixed(2)} kWh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (top3.isEmpty)
              Text(
                'En attente de télémétrie...',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ...top3.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _isLive(r.updatedAt)
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
                          '${r.powerKwh.toStringAsFixed(2)} kWh'
                          '${r.instantPowerW != null ? ' • ${r.instantPowerW!.toStringAsFixed(0)} W' : ''}',
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
