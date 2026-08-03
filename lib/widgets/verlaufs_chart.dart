import 'package:flutter/material.dart';

import '../services/spiel_service.dart';

/// Zeigt eine Linie aus VerlaufsPunkt-Werten inkl. Y-Achsen-Beschriftung
/// (Minimal-/Maximalwert) am linken Rand.
class VerlaufsChart extends StatefulWidget {
  final List<VerlaufsPunkt> punkte;
  final double Function(VerlaufsPunkt) wertSelector;
  final String Function(double) formatWert;
  final Color linienFarbe;
  final bool nullLinieZeigen;
  final bool symmetrischeSkala;
  final bool prozentSkala;

  const VerlaufsChart({
    super.key,
    required this.punkte,
    required this.wertSelector,
    required this.formatWert,
    this.linienFarbe = Colors.green,
    this.nullLinieZeigen = false,
    this.symmetrischeSkala = false,
    this.prozentSkala = false,
  });

  @override
  State<VerlaufsChart> createState() => _VerlaufsChartState();
}

class _VerlaufsChartState extends State<VerlaufsChart> {
  int? _ausgewaehlterIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.punkte.length < 2) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Noch zu wenige Runden für einen Verlauf')),
      );
    }

    final werte = widget.punkte.map(widget.wertSelector).toList();
    double minWert, maxWert;

    if (widget.symmetrischeSkala) {
      double maxAbs = 0;
      for (final w in werte) {
        if (w.abs() > maxAbs) maxAbs = w.abs();
      }
      if (maxAbs == 0) maxAbs = 1;
      minWert = -maxAbs;
      maxWert = maxAbs;
    } else if (widget.prozentSkala) {
      minWert = 0;
      maxWert = 100;
    } else {
      minWert = werte.reduce((a, b) => a < b ? a : b);
      maxWert = werte.reduce((a, b) => a > b ? a : b);
      if (minWert == maxWert) {
        minWert -= 1;
        maxWert += 1;
      }
    }

    final ausgewaehlterPunkt = _ausgewaehlterIndex != null
        ? widget.punkte[_ausgewaehlterIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    Text(widget.formatWert(maxWert),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(widget.formatWert(minWert),
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
                      painter: _LinienPainter(
                        werte: werte,
                        minWert: minWert,
                        maxWert: maxWert,
                        farbe: widget.linienFarbe,
                        nullLinieZeigen: widget.nullLinieZeigen,
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
                    'Runde ${ausgewaehlterPunkt.rundenNummer}${ausgewaehlterPunkt.runde != null ? ': ${ausgewaehlterPunkt.runde!.spielartName}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.formatWert(widget.wertSelector(ausgewaehlterPunkt)),
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
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final chartBreite = box.size.width - 60;
    if (chartBreite <= 0) return;
    final relativeX = position.dx.clamp(0.0, chartBreite);
    final index = ((relativeX / chartBreite) * (n - 1)).round().clamp(0, n - 1);
    setState(() => _ausgewaehlterIndex = index);
  }
}

class _LinienPainter extends CustomPainter {
  final List<double> werte;
  final double minWert;
  final double maxWert;
  final Color farbe;
  final bool nullLinieZeigen;
  final int? ausgewaehlterIndex;

  _LinienPainter({
    required this.werte,
    required this.minWert,
    required this.maxWert,
    required this.farbe,
    required this.nullLinieZeigen,
    required this.ausgewaehlterIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spanne = (maxWert - minWert).abs() < 0.0001 ? 1 : maxWert - minWert;

    double yFuer(double wert) =>
        size.height - ((wert - minWert) / spanne) * size.height;
    double xFuer(int index) =>
        werte.length == 1 ? 0.0 : size.width * index / (werte.length - 1);

    // Gitter zeichnen
    final gitterPaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height-1.0), gitterPaint);

    for (var i = 1; i <= 9; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gitterPaint);
    }

    for (var j = 1; j <= 9; j ++) {
      final x = size.width * j / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gitterPaint);
    }

    if (nullLinieZeigen && minWert < 0 && maxWert > 0) {
      final nullY = yFuer(0);
      final nullLinie = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, nullY), Offset(size.width, nullY), nullLinie);
    }

    final linienPaint = Paint()
      ..color = farbe
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (var i = 0; i < werte.length; i++) {
      final x = xFuer(i);
      final y = yFuer(werte[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linienPaint);

    // Ausgewählte Position
    if (ausgewaehlterIndex != null) {
      final x = xFuer(ausgewaehlterIndex!);
      final markerLinie = Paint()
        ..color = Colors.grey.shade500
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markerLinie);

      final y = yFuer(werte[ausgewaehlterIndex!]);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = farbe);
      canvas.drawCircle(
          Offset(x, y), 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _LinienPainter oldDelegate) =>
      oldDelegate.werte != werte || oldDelegate.ausgewaehlterIndex != ausgewaehlterIndex;
}