import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class EnergyTipEvent {
  final String id;
  final String title;
  final String body;
  final String icon;     // 'lightbulb' | 'bolt' | 'water' | 'thermo' | 'warning'
  final String severity; // 'info' | 'warning' | 'critical'
  final String source;   // 'live_spike' | 'agent'

  EnergyTipEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.severity,
    required this.source,
  });

  factory EnergyTipEvent.fromJson(Map<String, dynamic> row) => EnergyTipEvent(
        id: row['id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        icon: row['icon'] as String,
        severity: row['severity'] as String,
        source: row['source'] as String,
      );
}

class TipsRealtimeService {
  TipsRealtimeService._();
  static final TipsRealtimeService instance = TipsRealtimeService._();

  final StreamController<EnergyTipEvent> _controller =
      StreamController<EnergyTipEvent>.broadcast();
  RealtimeChannel? _channel;
  bool _started = false;

  Stream<EnergyTipEvent> get stream => _controller.stream;

  /// Démarre l'écoute après login. Idempotent : no-op si déjà démarré.
  void start() {
    if (_started) return;
    _started = true;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _started = false; // autorise un retry plus tard
      return;
    }

    _channel = Supabase.instance.client
        .channel('energy_tips_realtime:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'energy_tips_realtime',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            try {
              final event = EnergyTipEvent.fromJson(newRecord);
              _controller.add(event);
              // Notification locale + acknowledge (asynchrones, non bloquants)
              unawaited(_fireLocalNotification(event));
              unawaited(_markAcknowledged(event.id));
            } catch (_) {
              // payload malformé : ignore silencieusement
            }
          },
        )
        .subscribe();
  }

  Future<void> _fireLocalNotification(EnergyTipEvent event) async {
    final notifId = 9000 + (event.id.hashCode & 0x7FFFFFFF) % 1000;
    await NotificationService().showNotification(
      id: notifId,
      title: event.title,
      body: event.body,
      payload: 'energy_tip:${event.id}',
    );
  }

  Future<void> _markAcknowledged(String id) async {
    try {
      await Supabase.instance.client
          .from('energy_tips_realtime')
          .update({'acknowledged': true})
          .eq('id', id);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    _started = false;
    await _controller.close();
  }
}
