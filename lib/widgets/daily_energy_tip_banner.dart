import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../services/tips_realtime_service.dart';

class DailyEnergyTipBanner extends StatefulWidget {
  const DailyEnergyTipBanner({super.key});

  @override
  State<DailyEnergyTipBanner> createState() => _DailyEnergyTipBannerState();
}

class _DailyEnergyTipBannerState extends State<DailyEnergyTipBanner> {
  Map<String, dynamic>? _tip;
  EnergyTipEvent? _liveOverride;
  StreamSubscription<EnergyTipEvent>? _sub;
  Timer? _autoClearTimer;

  @override
  void initState() {
    super.initState();
    TipsRealtimeService.instance.start();
    _loadDaily();
    _sub = TipsRealtimeService.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() => _liveOverride = e);
      _autoClearTimer?.cancel();
      _autoClearTimer = Timer(const Duration(hours: 24), () {
        if (mounted && _liveOverride?.id == e.id) {
          setState(() => _liveOverride = null);
        }
      });
    });
  }

  Future<void> _loadDaily() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final res = await Supabase.instance.client
        .from('daily_energy_tip')
        .select('title, body, icon, severity')
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted && res != null) setState(() => _tip = res);
  }

  IconData _iconFor(String name) => switch (name) {
        'bolt' => Icons.bolt,
        'water' => Icons.water_drop,
        'thermo' => Icons.thermostat,
        'warning' => Icons.warning_amber_rounded,
        _ => Icons.lightbulb_outline,
      };

  Color _colorFor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      'critical' => scheme.error,
      'warning' => Colors.orange,
      _ => scheme.primary,
    };
  }

  void _dismissLive() => setState(() => _liveOverride = null);

  void _onTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(
          initialMessage: 'Donne-moi plus de détails sur ce conseil.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tip == null && _liveOverride == null) return const SizedBox.shrink();

    final bool isLive = _liveOverride != null;
    final String title = isLive ? _liveOverride!.title : _tip!['title'] as String;
    final String body = isLive ? _liveOverride!.body : _tip!['body'] as String;
    final String icon = isLive ? _liveOverride!.icon : _tip!['icon'] as String;
    final String severity =
        isLive ? _liveOverride!.severity : _tip!['severity'] as String;
    final color = _colorFor(context, severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(_iconFor(icon), color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _dismissLive,
                    tooltip: 'Ignorer',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
