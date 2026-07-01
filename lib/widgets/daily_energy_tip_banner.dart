import 'dart:async';
import 'package:aricie/screens/chatbot/chatbot_screen.dart';
import 'package:aricie/services/tips_realtime_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Icône Material correspondant au code d'icône d'un conseil énergie.
/// Fonction pure (testable). Fallback `lightbulb` pour les codes inconnus.
IconData tipIconFor(String icon) {
  switch (icon) {
    case 'bolt':
      return Icons.bolt;
    case 'water':
      return Icons.water_drop_outlined;
    case 'thermo':
      return Icons.thermostat;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'lightbulb':
    default:
      return Icons.lightbulb_outline;
  }
}

/// Couleur d'accent selon la sévérité d'un conseil. Fonction pure (testable).
Color tipColorFor(String severity) {
  switch (severity) {
    case 'critical':
      return AppColors.accentDot;
    case 'warning':
      return AppColors.accentGold;
    case 'info':
    default:
      return AppColors.accentMint;
  }
}

class _TipView {
  final String title;
  final String body;
  final String icon;
  final String severity;
  final bool isLive;

  const _TipView({
    required this.title,
    required this.body,
    required this.icon,
    required this.severity,
    required this.isLive,
  });
}

/// Bannière de conseil d'économie d'énergie sur le dashboard.
///
/// - Charge au boot le conseil du jour (`daily_energy_tip`, scopé user via RLS).
/// - Écoute [TipsRealtimeService] : un push live (pic anormal ou agent VIP)
///   prend le dessus avec un badge "LIVE" et peut être rejeté (X) pour revenir
///   au conseil du jour.
/// - Tap → ouvre le chatbot avec un message pré-rempli.
///
/// Le service realtime + le backend (edge function `tips-generator`, tables)
/// sont fournis par l'équipe AI/MQTT ; ce widget ne fait que les consommer.
class DailyEnergyTipBanner extends StatefulWidget {
  const DailyEnergyTipBanner({super.key});

  @override
  State<DailyEnergyTipBanner> createState() => _DailyEnergyTipBannerState();
}

class _DailyEnergyTipBannerState extends State<DailyEnergyTipBanner> {
  _TipView? _daily;
  _TipView? _live;
  StreamSubscription<EnergyTipEvent>? _sub;

  _TipView? get _current => _live ?? _daily;

  @override
  void initState() {
    super.initState();
    _loadDaily();
    _sub = TipsRealtimeService.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _live = _TipView(
          title: e.title,
          body: e.body,
          icon: e.icon,
          severity: e.severity,
          isLive: true,
        );
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadDaily() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await Supabase.instance.client
          .from('daily_energy_tip')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _daily = _TipView(
          title: (row['title'] as String?) ?? 'Conseil d\'économie',
          body: (row['body'] as String?) ?? '',
          icon: (row['icon'] as String?) ?? 'lightbulb',
          severity: (row['severity'] as String?) ?? 'info',
          isLive: false,
        );
      });
    } catch (_) {
      // Pas de conseil disponible / erreur réseau : la bannière reste masquée.
    }
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(
          initialMessage: 'Donne-moi plus de détails sur ce conseil',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tip = _current;
    if (tip == null) return const SizedBox.shrink();

    final color = tipColorFor(tip.severity);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: _openChatbot,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.sm],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(tipIconFor(tip.icon), color: color),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tip.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (tip.isLive) _liveBadge(context),
                    ],
                  ),
                  if (tip.body.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s1),
                    Text(tip.body, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            if (_live != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Masquer',
                onPressed: () => setState(() => _live = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveBadge(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.s2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentDot,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
