import 'package:flutter/material.dart';

import '../models/tisch.dart';

/// Zeigt einen Tisch als quadratische Karte (Kasten) statt als Zeile/Balken.
/// Wird sowohl für aktive als auch für beendete Tische verwendet.
class TischKarte extends StatelessWidget {
  final Tisch tisch;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const TischKarte({
    super.key,
    required this.tisch,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final istAktiv = tisch.status == TischStatus.aktiv;
    final datum = istAktiv ? tisch.erstelltAm : (tisch.beendetAm ?? tisch.erstelltAm);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        istAktiv ? Icons.play_arrow : Icons.flag,
                        size: 18,
                        color: istAktiv
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${datum.day.toString().padLeft(2, '0')}.${datum.month.toString().padLeft(2, '0')}.${datum.year}',
                          style: Theme.of(context).textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onDelete != null) const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      tisch.spieler.map((s) => s.name).join(', '),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tisch.runden.length} Runden',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey.shade600,
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}