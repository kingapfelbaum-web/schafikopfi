import 'package:flutter/material.dart';

/// Optionen für die Zeitraum-Einschränkung eines Verlaufs-Charts.
/// null = alle Runden, sonst die letzten N Runden.
class ZeitraumAuswahl extends StatelessWidget {
  final int? ausgewaehlt;
  final ValueChanged<int?> onChanged;

  const ZeitraumAuswahl({
    super.key,
    required this.ausgewaehlt,
    required this.onChanged,
  });

  static const _optionen = <int?>[10, 25, 50, null];

  String _label(int? wert) => wert == null ? 'Alle' : 'Letzte $wert';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _optionen.map((wert) {
          final aktiv = wert == ausgewaehlt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(wert)),
              selected: aktiv,
              onSelected: (_) => onChanged(wert),
            ),
          );
        }).toList(),
      ),
    );
  }
}