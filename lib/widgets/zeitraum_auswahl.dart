import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optionen für die Zeitraum-Einschränkung eines Verlaufs-Charts.
/// null = alle Runden, sonst die letzten N Runden.
class ZeitraumAuswahl extends StatefulWidget {
  final int? ausgewaehlt;
  final ValueChanged<int?> onChanged;

  const ZeitraumAuswahl({
    super.key,
    required this.ausgewaehlt,
    required this.onChanged,
  });

  @override
  State<ZeitraumAuswahl> createState() => _ZeitraumAuswahlState();
}

class _ZeitraumAuswahlState extends State<ZeitraumAuswahl> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.ausgewaehlt?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(ZeitraumAuswahl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ausgewaehlt != oldWidget.ausgewaehlt) {
      final newText = widget.ausgewaehlt?.toString() ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final istAlle = widget.ausgewaehlt == null;

    return Row(
      children: [
        ChoiceChip(
          label: const Text('Alle'),
          selected: istAlle,
          onSelected: (selected) {
            if (selected) {
              _controller.clear();
              widget.onChanged(null);
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Letzte Runden',
              hintText: 'Anzahl...',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged(null);
                },
              )
                  : null,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              final n = int.tryParse(val);
              if (n != null && n > 0) {
                widget.onChanged(n);
              } else if (val.isEmpty) {
                widget.onChanged(null);
              }
            },
          ),
        ),
      ],
    );
  }
}