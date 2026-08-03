import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/spieler.dart';
import '../services/spiel_service.dart';

/// Feste Farbpalette für die Spieler-Linien (reihum verwendet).
const List<Color> _linienFarben = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.brown,
];

class TischVerlaufsChart extends StatefulWidget {
  final List<Spieler> spieler;
  final List<TischVerlaufsPunkt> punkte;

  const TischVerlaufsChart({
    super.key,
    required this.spieler,
    required this.punkte,
  });

  @override
  State<TischVerlaufsChart> createState() => _TischVerlaufsChartState();
}

class _TischVerlaufsChartState extends State<TischVerlaufsChart> {
  int? _ausgewaehlterIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.punkte.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Noch zu wenige Runden für einen Verlauf')),
      );
    }

    // Min/Max über ALLE Spieler-Linien hinweg, damit alle in derselben
    // Skala dargestellt werden.
    double maxAbs = 0;
    for (final p in widget.punkte) {
      for (final s in widget.spieler) {
        final wert = (p.saldoProSpieler[s.id] ?? 0).abs();
        if (wert > maxAbs) maxAbs = wert;
      }
    }
    if (maxAbs == 0) maxAbs = 1;
    final minWert = -maxAbs;
    final maxWert = maxAbs;

    final ausgewaehlterPunkt = _ausgewaehlterIndex != null
        ? widget.punkte[_ausgewaehlterIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legende
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(widget.spieler.length, (i) {
            final farbe = _linienFarben[i % _linienFarben.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10, height: 10, color: farbe),
                const SizedBox(width: 4),
                Text(widget.spieler[i].name,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-Achse: Maximal-/Minimalwert
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${maxWert.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('${minWert.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => _beiBeruehrung(details.localPosition),
                  onPanUpdate: (details) => _beiBeruehrung(details.localPosition),
                  onPanEnd: (_) => setState(() => _ausgewaehlterIndex = null),
                  onTapDown: (details) => _beiBeruehrung(details.localPosition),
                  child: MouseRegion(
                    onHover: (event) => _beiBeruehrung(event.localPosition),
                    onExit: (_) => setState(() => _ausgewaehlterIndex = null),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _MehrlinienPainter(
                        punkte: widget.punkte,
                        spieler: widget.spieler,
                        minWert: minWert,
                        maxWert: maxWert,
                        ausgewaehlterIndex: _ausgewaehlterIndex,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tooltip-Bereich: zeigt die Runde am ausgewählten Punkt
        SizedBox(
          height: 80,
          child: ausgewaehlterPunkt == null
              ? null
              : Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Runde ${ausgewaehlterPunkt.rundenNummer}: ${ausgewaehlterPunkt.runde.spielartName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    maxLines: 2,
                    widget.spieler
                        .map((s) =>
                    '${s.name}: ${(ausgewaehlterPunkt.saldoProSpieler[s.id] ?? 0) >= 0 ? '+' : ''}${(ausgewaehlterPunkt.saldoProSpieler[s.id] ?? 0).toStringAsFixed(2)} €')
                        .join('  ·  '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _beiBeruehrung(Offset position) {
    final n = widget.punkte.length;
    if (n < 2) return;
    // Breite wird im Painter über LayoutBuilder nicht direkt bekannt; wir
    // schätzen über RenderBox der GestureDetector-Region zur Laufzeit.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Die nutzbare Breite entspricht der Chart-Fläche abzüglich Y-Achse (56+4px).
    final chartBreite = box.size.width - 60;
    if (chartBreite <= 0) return;
    final relativeX = position.dx.clamp(0.0, chartBreite);
    final index = ((relativeX / chartBreite) * (n - 1)).round().clamp(0, n - 1);
    setState(() => _ausgewaehlterIndex = index);
  }
}

class _MehrlinienPainter extends CustomPainter {
  final List<TischVerlaufsPunkt> punkte;
  final List<Spieler> spieler;
  final double minWert;
  final double maxWert;
  final int? ausgewaehlterIndex;

  _MehrlinienPainter({
    required this.punkte,
    required this.spieler,
    required this.minWert,
    required this.maxWert,
    required this.ausgewaehlterIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spanne = (maxWert - minWert).abs() < 0.0001 ? 1 : maxWert - minWert;
    double yFuer(double wert) =>
        size.height - ((wert - minWert) / spanne) * size.height;
    double xFuer(int index) =>
        punkte.length == 1 ? 0.0 : size.width * index / (punkte.length - 1);
    // Gitter zeichnen
    final gitterPaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontale Gitterlinien (5 Linien)
    canvas.drawRect(Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height-1.0), gitterPaint);

    for (var i = 0; i <= 9; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gitterPaint);
    }

    // Vertikale Gitterlinien (alle 5 Runden oder bei jeder Runde)
    for (var j = 0; j <= 9; j ++) {
      final x = size.width * j / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gitterPaint);
    }


    // Nulllinie, falls im sichtbaren Bereich
    if (minWert < 0 && maxWert > 0) {
      final nullY = yFuer(0);
      final nullPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, nullY), Offset(size.width, nullY), nullPaint);
    }

    for (var i = 0; i < spieler.length; i++) {
      final s = spieler[i];
      final farbe = _linienFarben[i % _linienFarben.length];
      final linienPaint = Paint()
        ..color = farbe
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (var j = 0; j < punkte.length; j++) {
        final x = xFuer(j);
        final y = yFuer(punkte[j].saldoProSpieler[s.id] ?? 0);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linienPaint);
    }

    // Ausgewählte Position: vertikale Linie + Punkte pro Spieler
    if (ausgewaehlterIndex != null) {
      final x = xFuer(ausgewaehlterIndex!);
      final markerLinie = Paint()
        ..color = Colors.grey.shade500
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markerLinie);

      for (var i = 0; i < spieler.length; i++) {
        final s = spieler[i];
        final farbe = _linienFarben[i % _linienFarben.length];
        final y = yFuer(punkte[ausgewaehlterIndex!].saldoProSpieler[s.id] ?? 0);
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = farbe);
        canvas.drawCircle(
            Offset(x, y), 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MehrlinienPainter oldDelegate) =>
      oldDelegate.punkte != punkte ||
          oldDelegate.ausgewaehlterIndex != ausgewaehlterIndex;
}