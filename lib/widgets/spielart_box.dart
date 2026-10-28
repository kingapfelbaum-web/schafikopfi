import 'package:flutter/material.dart';

import '../models/spielart.dart';

/// Zeigt eine Spielart als antippbaren Kasten an (statt als volle Zeile/Balken).
/// Wird sowohl für Mehrfachauswahl (z.B. "Verfügbare Spiele") als auch für
/// Einfachauswahl (Spielart in der Runden-Erfassung) verwendet.
class SpielartBox extends StatelessWidget {
  final Spielart spielart;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const SpielartBox({
    super.key,
    required this.spielart,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final vordergrund =
        ausgewaehlt ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 128,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ausgewaehlt
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ausgewaehlt ? colorScheme.primary : colorScheme.outlineVariant,
            width: ausgewaehlt ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    spielart.name,
                    style: TextStyle(fontWeight: FontWeight.bold, color: vordergrund),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ausgewaehlt)
                  Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              spielart.einzelspieler ? 'Solo' : 'Sauspiel',
              style: TextStyle(
                fontSize: 12,
                color: ausgewaehlt
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
