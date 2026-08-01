import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tisch.dart';
import '../services/spiel_service.dart';
import '../widgets/tisch_karte.dart';
import 'spieler_detail_screen.dart';
import 'tisch_detail_screen.dart';
import 'spielart_detail_screen.dart';

class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistik'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Spieler'),
            Tab(text: 'Beendete Spiele'),
            Tab(text: 'Spielarten'),
          ]),
        ),
        body: const TabBarView(
          children: [
            _SpielerStatistikTab(),
            _BeendeteSpieleTab(),
            _SpielartenStatistikTab(),
          ],
        ),
      ),
    );
  }
}

class _SpielerStatistikTab extends StatelessWidget {
  const _SpielerStatistikTab();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final stats = service.statistikProSpieler.values.toList()
      ..sort((a, b) => b.gesamtPunkte.compareTo(a.gesamtPunkte));

    if (stats.isEmpty) {
      return const Center(child: Text('Noch keine Daten'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(s.spieler.name),
            subtitle: Text(
                '${s.anzahlTische} Tische · ${s.anzahlRunden} Runden · '
                '${(s.gewinnquote * 100).toStringAsFixed(0)}% Gewinnquote'),
            trailing: Text(
              '${s.gesamtPunkte > 0 ? '+' : ''}${s.gesamtPunkte.toStringAsFixed(2)} €',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: s.gesamtPunkte > 0
                    ? Colors.green
                    : s.gesamtPunkte < 0
                        ? Colors.red
                        : null,
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => SpielerDetailScreen(spieler: s.spieler)),
            ),
          ),
        );
      },
    );
  }
}

class _BeendeteSpieleTab extends StatefulWidget {
  const _BeendeteSpieleTab();

  @override
  State<_BeendeteSpieleTab> createState() => _BeendeteSpieleTabState();
}

class _BeendeteSpieleTabState extends State<_BeendeteSpieleTab> {
  final _sucheController = TextEditingController();
  String _suche = '';

  @override
  void dispose() {
    _sucheController.dispose();
    super.dispose();
  }

  bool _passtZurSuche(Tisch tisch) {
    if (_suche.isEmpty) return true;
    final query = _suche.toLowerCase();
    final spielerNamen =
        tisch.spieler.map((s) => s.name.toLowerCase()).join(' ');
    final datum =
        '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year}';
    final spielarten =
        tisch.spielarten.map((s) => s.name.toLowerCase()).join(' ');
    return spielerNamen.contains(query) ||
        datum.contains(query) ||
        spielarten.contains(query);
  }

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Tisch tisch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spiel löschen?'),
        content: const Text(
            'Dieser Tisch inklusive aller Runden wird endgültig gelöscht. Das kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.tischLoeschen(tisch);
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final alle = service.beendeteTische;
    final gefiltert = alle.where(_passtZurSuche).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _sucheController,
            decoration: InputDecoration(
              hintText: 'Nach Spieler, Datum oder Spielart suchen',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              isDense: true,
              suffixIcon: _suche.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _sucheController.clear();
                        setState(() => _suche = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _suche = value),
          ),
        ),
        Expanded(
          child: alle.isEmpty
              ? const Center(child: Text('Noch keine beendeten Spiele'))
              : gefiltert.isEmpty
                  ? const Center(child: Text('Keine Treffer'))
                    : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: gefiltert.length,
                      itemBuilder: (context, index) {
                        final tisch = gefiltert[index];
                        return TischKarte(
                          tisch: tisch,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    TischDetailScreen(tisch: tisch)),
                          ),
                          onDelete: () => _loeschenBestaetigen(
                              context, service, tisch),
                        );
                      },
                ),
        ),
      ],
    );
  }
}

class _SpielartenStatistikTab extends StatelessWidget {
  const _SpielartenStatistikTab();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final stats = service.statistikProSpielart;

    if (stats.isEmpty) {
      return const Center(child: Text('Noch keine Daten'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return Card(
          child: ListTile(
            title: Text(s.name),
            subtitle: Text('${s.anzahlRunden} Runden'),
            trailing: Text(
              '${(s.gewinnquote * 100).toStringAsFixed(0)}% Siegquote',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SpielartDetailScreen(spielartName: s.name),
              ),
            ),
          ),
        );
      },
    );
  }
}
