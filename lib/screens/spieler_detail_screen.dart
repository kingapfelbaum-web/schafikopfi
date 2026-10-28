import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../services/spiel_service.dart';
import 'tisch_detail_screen.dart';
import '../widgets/verlaufs_chart.dart';
import '../widgets/zeitraum_auswahl.dart';
import 'spielart_detail_screen.dart';

class SpielerDetailScreen extends StatefulWidget {
  final Spieler spieler;
  const SpielerDetailScreen({super.key, required this.spieler});

  @override
  State<SpielerDetailScreen> createState() => _SpielerDetailScreenState();
}

class _SpielerDetailScreenState extends State<SpielerDetailScreen> {
  int? _zeitraum; // null = alle Runden, sonst letzte N Runden

  Spieler get spieler => widget.spieler;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final stat = service.detailStatistikFuer(spieler);

    return Scaffold(
      appBar: AppBar(title: Text(spieler.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: stat.gesamtPunkte > 0.005
                ? Colors.green.shade300
                : stat.gesamtPunkte < -0.005
                ? Colors.red.shade300
                : Theme.of(context).colorScheme.outline,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${stat.gesamtPunkte > 0.005 ? '+' : ''}${stat.gesamtPunkte.toStringAsFixed(2)} €',
                    style: TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _kennzahl(context, '${stat.anzahlTische}', 'Tische'),
                      _kennzahl(context, '${stat.anzahlRunden}', 'Runden'),
                      _kennzahl(context,
                          '${(stat.gewinnquote * 100).toStringAsFixed(0)}%',
                          'Gewinnquote'),
                      if (stat.unentschiedenRunden > 0)
                        _kennzahl(context, '${stat.unentschiedenRunden}',
                            'Unentschieden'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Verlauf', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ZeitraumAuswahl(
            ausgewaehlt: _zeitraum,
            onChanged: (wert) => setState(() => _zeitraum = wert),
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final vollerVerlauf = service.verlaufFuerSpieler(spieler);
            final verlauf = _zeitraum == null || vollerVerlauf.length <= _zeitraum!
                ? vollerVerlauf
                : vollerVerlauf.sublist(vollerVerlauf.length - _zeitraum!);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo-Verlauf',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: VerlaufsChart(
                      punkte: verlauf,
                      wertSelector: (p) => p.kumulierterSaldo,
                      formatWert: (w) =>
                      '${w > 0.005 ? '+' : ''}${w.toStringAsFixed(2)} €',
                      linienFarbe:
                      stat.gesamtPunkte > 0.005 ? Colors.green : stat.gesamtPunkte < -0.005 ? Colors.red : Theme.of(context).colorScheme.outline,
                      nullLinieZeigen: true,
                      symmetrischeSkala: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Gewinnquote-Verlauf',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: VerlaufsChart(
                      punkte: verlauf,
                      wertSelector: (p) => p.kumulierteGewinnquote * 100,
                      formatWert: (w) => '${w.toStringAsFixed(0)}%',
                      linienFarbe: Colors.blue,
                      prozentSkala: true,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text('Nach Spielart', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stat.proSpielart.isEmpty)
            const Text('Noch keine Runden gespielt')
          else
            ...stat.proSpielart.map((s) => Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                        '${s.anzahlRunden} Runden · ${(s.gewinnquote * 100).toStringAsFixed(0)}% Gewinnquote'),
                    trailing: Text(
                      '${s.gesamtPunkte > 0.005 ? '+' : ''}${s.gesamtPunkte.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: s.gesamtPunkte > 0.005
                            ? Colors.green
                            : s.gesamtPunkte < -0.005
                                ? Colors.red
                                : null,
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpielartDetailScreen(
                          spielartName: s.name,
                          spieler: spieler,
                        ),
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 24),
          Text('Tische', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stat.tische.isEmpty)
            const Text('Noch an keinem Tisch dabei')
          else
            ...stat.tische.map((tisch) {
              final punkte = tisch.punktestand[spieler.id] ?? 0;
              final istAktiv = tisch.status.name == 'aktiv';
              return Card(
                child: ListTile(
                  leading: Icon(
                      istAktiv ? Icons.sports_esports : Icons.flag,
                      color: istAktiv ? Colors.green : Colors.grey),
                  title: Text(
                      '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year}'),
                  subtitle: Text(tisch.spieler
                      .where((s) => s.id != spieler.id)
                      .map((s) => s.name)
                      .join(', ')),
                  trailing: Text(
                    '${punkte > 0.005 ? '+' : ''}${punkte.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: punkte > 0.005
                          ? Colors.green
                          : punkte < -0.005
                              ? Colors.red
                              : null,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TischDetailScreen(tisch: tisch)),
                  ),
                ),
              );
            }),
          Divider(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _kennzahl(BuildContext context, String wert, String label) => Column(
        children: [
          Text(wert,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              )
          ),
          Text(label, style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onPrimary,
          ),),
        ],
      );
}
