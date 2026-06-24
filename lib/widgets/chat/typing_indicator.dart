import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(context, 0),
          _buildDot(context, 150),
          _buildDot(context, 300),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int delay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(duration: 300.ms)
        .then(delay: delay.ms)
        .animate()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.5, 1.5),
          duration: 700.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.5, 1.5),
          end: const Offset(1, 1),
          duration: 1000.ms,
        );
  }
}