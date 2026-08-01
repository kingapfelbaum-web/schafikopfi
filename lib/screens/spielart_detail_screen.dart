import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../models/runde.dart';
import '../models/tisch.dart';
import '../services/spiel_service.dart';
import 'tisch_detail_screen.dart';

class SpielartDetailScreen extends StatelessWidget {
  final String spielartName;

  /// Falls gesetzt, werden nur Runden angezeigt, an denen dieser Spieler
  /// beteiligt war (Aufruf von der Spieler-Detailseite aus); sonst alle
  /// Runden dieser Spielart über alle Tische hinweg.
  final Spieler? spieler;

  const SpielartDetailScreen({
    super.key,
    required this.spielartName,
    this.spieler,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();

    // Alle passenden Runden einsammeln, zusammen mit ihrem Tisch (für Navigation
    // und Anzeige der beteiligten Spieler), chronologisch neueste zuerst.
    final eintraege = <_RundenEintrag>[];
    for (final tisch in service.alleTische) {
      for (final runde in tisch.runden) {
        if (runde.spielartName != spielartName) continue;
        if (spieler != null && !runde.punkteProSpieler.containsKey(spieler!.id)) {
          continue;
        }
        eintraege.add(_RundenEintrag(tisch: tisch, runde: runde));
      }
    }
    eintraege.sort((a, b) => b.runde.zeitpunkt.compareTo(a.runde.zeitpunkt));

    // Aggregierte Kennzahlen für die Kopfzeile.
    var gewonneneRunden = 0;
    var gesamtSaldo = 0.0;
    for (final e in eintraege) {
      if (spieler != null) {
        final punkte = e.runde.punkteProSpieler[spieler!.id] ?? 0;
        gesamtSaldo += punkte;
        if (!e.runde.unentschieden && punkte > 0) gewonneneRunden += 1;
      } else {
        if (!e.runde.unentschieden && e.runde.gewonnen) gewonneneRunden += 1;
      }
    }
    final gewinnquote =
    eintraege.isEmpty ? 0 : gewonneneRunden / eintraege.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(spieler == null
            ? spielartName
            : '$spielartName · ${spieler!.name}'),
      ),
      body: eintraege.isEmpty
          ? const Center(child: Text('Noch keine passenden Runden'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: eintraege.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _kennzahl(context, '${eintraege.length}', 'Runden'),
                      _kennzahl(
                          context,
                          '${(gewinnquote * 100).toStringAsFixed(0)}%',
                          'Gewinnquote'),
                      if (spieler != null)
                        _kennzahl(
                          context,
                          '${gesamtSaldo >= 0 ? '+' : ''}${gesamtSaldo.toStringAsFixed(2)} €',
                          'Saldo',
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (index == eintraege.length + 1) return Divider(height: MediaQuery.of(context).padding.bottom);

          final eintrag = eintraege[index - 1];
          final runde = eintrag.runde;
          final tisch = eintrag.tisch;

          final beteiligte = runde.spielerParteiIds
              .map((id) =>
          tisch.spieler.firstWhere((s) => s.id == id).name)
              .join(' & ');
          final details = [
            if (runde.anzahlLaufende > 0) '${runde.anzahlLaufende} Laufende',
            if (runde.schneider) 'Schneider',
            if (runde.schwarz) 'Schwarz',
            if (runde.multiplikator > 1) '${runde.multiplikator}x',
          ].join(' · ');
          final datum =
              '${runde.zeitpunkt.day.toString().padLeft(2, '0')}.${runde.zeitpunkt.month.toString().padLeft(2, '0')}.${runde.zeitpunkt.year}';

          final persoenlichePunkte =
          spieler != null ? runde.punkteProSpieler[spieler!.id] : null;

          return Card(
            child: ListTile(
              leading: Icon(
                runde.unentschieden
                    ? Icons.remove_circle_outline
                    : runde.gewonnen
                    ? Icons.check_circle
                    : Icons.cancel,
                color: runde.unentschieden
                    ? Colors.grey
                    : runde.gewonnen
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(
                  beteiligte.isEmpty ? datum : '$datum · $beteiligte'),
              subtitle: Text(details.isEmpty
                  ? '${runde.spielwert.toStringAsFixed(2)} € je Verlierer'
                  : '$details · ${runde.spielwert.toStringAsFixed(2)} € je Verlierer'),
              trailing: Text(
                persoenlichePunkte != null
                    ? '${persoenlichePunkte >= 0 ? '+' : ''}${persoenlichePunkte.toStringAsFixed(2)} €'
                    : (runde.unentschieden
                    ? 'unentschieden'
                    : runde.gewonnen
                    ? 'gewonnen'
                    : 'verloren'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: persoenlichePunkte != null
                      ? (persoenlichePunkte > 0
                      ? Colors.green
                      : persoenlichePunkte < 0
                      ? Colors.red
                      : null)
                      : (runde.unentschieden
                      ? Colors.grey
                      : runde.gewonnen
                      ? Colors.green
                      : Colors.red),
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TischDetailScreen(tisch: tisch)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kennzahl(BuildContext context, String wert, String label) => Column(
    children: [
      Text(wert,
          style:
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _RundenEintrag {
  final Tisch tisch;
  final Runde runde;
  _RundenEintrag({required this.tisch, required this.runde});
}