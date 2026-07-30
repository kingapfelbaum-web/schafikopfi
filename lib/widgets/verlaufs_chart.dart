import 'package:flutter/material.dart';

import '../services/spiel_service.dart';

/// Zeigt eine Linie aus VerlaufsPunkt-Werten inkl. Y-Achsen-Beschriftung
/// (Minimal-/Maximalwert) am linken Rand.
class VerlaufsChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (punkte.length < 2) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Noch zu wenige Runden für einen Verlauf')),
      );
    }

    final werte = punkte.map(wertSelector).toList();
    double minWert, maxWert;

    if (symmetrischeSkala) {
      double maxAbs = 0;
      for (final w in werte) {
        if (w.abs() > maxAbs) maxAbs = w.abs();
      }
      if (maxAbs == 0) maxAbs = 1;
      minWert = -maxAbs;
      maxWert = maxAbs;
    } else if (prozentSkala) {
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

    return SizedBox(
      height: 200,
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
                Text(formatWert(maxWert),
                    style: Theme.of(context).textTheme.bodySmall),
                Text(formatWert(minWert),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinienPainter(
                werte: werte,
                minWert: minWert,
                maxWert: maxWert,
                farbe: linienFarbe,
                nullLinieZeigen: nullLinieZeigen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinienPainter extends CustomPainter {
  final List<double> werte;
  final double minWert;
  final double maxWert;
  final Color farbe;
  final bool nullLinieZeigen;

  _LinienPainter({
    required this.werte,
    required this.minWert,
    required this.maxWert,
    required this.farbe,
    required this.nullLinieZeigen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spanne = (maxWert - minWert).abs() < 0.0001 ? 1 : maxWert - minWert;

    double yFuer(double wert) =>
        size.height - ((wert - minWert) / spanne) * size.height;

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
      final x = werte.length == 1
          ? 0.0
          : size.width * i / (werte.length - 1);
      final y = yFuer(werte[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linienPaint);
  }

  @override
  bool shouldRepaint(covariant _LinienPainter oldDelegate) =>
      oldDelegate.werte != werte;
}