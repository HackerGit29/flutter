import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimePowerReading {
  final String applianceId;
  final String applianceName;
  final double powerKwh;
  final double? instantPowerW;
  final DateTime updatedAt;

  RealtimePowerReading({
    required this.applianceId,
    required this.applianceName,
    required this.powerKwh,
    required this.instantPowerW,
    required this.updatedAt,
  });

  factory RealtimePowerReading.fromJson(Map<String, dynamic> row) {
    final num kwh = row['power_kwh'] as num? ?? 0;
    final dynamic w = row['instant_power_w'];
    return RealtimePowerReading(
      applianceId: row['appliance_id'] as String,
      applianceName: (row['appliances'] as Map?)?['name'] as String? ?? '',
      powerKwh: kwh.toDouble(),
      instantPowerW: w is num ? w.toDouble() : null,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

class RealtimePowerService {
  RealtimePowerService._();

  static final RealtimePowerService instance = RealtimePowerService._();

  final StreamController<RealtimePowerReading> _controller =
      StreamController<RealtimePowerReading>.broadcast();

  RealtimeChannel? _channel;

  Stream<RealtimePowerReading> get stream => _controller.stream;

  void start(String userId) {
    _channel?.unsubscribe();

    final client = Supabase.instance.client;
    _channel = client
        .channel('realtime_power:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'realtime_power',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            try {
              _controller.add(RealtimePowerReading.fromJson(newRecord));
            } catch (_) {
              // payload malformé : on ignore silencieusement
            }
          },
        )
        .subscribe();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    await _controller.close();
  }
}
