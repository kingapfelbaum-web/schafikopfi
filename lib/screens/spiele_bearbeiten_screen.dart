import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spielart.dart';
import '../services/spiel_service.dart';

class SpieleBearbeitenScreen extends StatelessWidget {
  const SpieleBearbeitenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Spiele bearbeiten')),
      body: service.spielarten.isEmpty
          ? const Center(child: Text('Noch keine Spielarten angelegt'))
          : ListView.builder(
              padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom+80),
              itemCount: service.spielarten.length,
              itemBuilder: (context, index) {
                final s = service.spielarten[index];
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(_untertitel(s)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _bearbeitenDialog(context, service, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _loeschenBestaetigen(context, service, s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Spielart hinzufügen'),
        onPressed: () => _bearbeitenDialog(context, service, null),
      ),
    );
  }

  String _untertitel(Spielart s) {
    final tarif = s.einzelspieler
        ? 'Solo-Tarif (Grundpreis: Solo)'
        : 'Sauspiel-Tarif (Grundpreis: Sauspiel)';
    final modus = s.individuelleGewinner
        ? 'individuelle Gewinner, Unentschieden möglich'
        : 'feste Partei (${s.anzahlSpielerpartei} gegen ${4 - s.anzahlSpielerpartei})';
    return '$tarif · $modus';
  }

  void _bearbeitenDialog(
      BuildContext context, SpielService service, Spielart? bestehende) {
    final nameController = TextEditingController(text: bestehende?.name ?? '');
    bool einzelspieler = bestehende?.einzelspieler ?? true;
    bool individuelleGewinner = bestehende?.individuelleGewinner ?? false;
    int individuelleAnzahl = bestehende?.individuelleAnzahl ?? 0;
    bool eigeneBetraege = bestehende?.eigeneBetraege ?? false;
    bool hatSpieler = bestehende?.hatSpieler ?? true;
    final siegController = TextEditingController(
      text: (bestehende?.siegBetrag ?? (einzelspieler ? standardTarif.sauspielPreis : standardTarif.soloPreis)).toStringAsFixed(2));
    final verlustController = TextEditingController(
      text: (bestehende?.verlustBetrag ?? (einzelspieler ? standardTarif.sauspielPreis : standardTarif.soloPreis)).toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(bestehende == null
              ? 'Neue Spielart'
              : 'Spielart bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Grundpreis'),
                const SizedBox(height: 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sauspiel')),
                    ButtonSegment(value: true, label: Text('Solo')),
                  ],
                  selected: {einzelspieler},
                  onSelectionChanged: (selection) =>
                      setState(() => einzelspieler = selection.first),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hat Spieler'),
                  subtitle: const Text(
                      'Der als erstes ausgewählte Spieler der Partei gilt als Ansager des Spiels (z.B. Rufer beim Sauspiel).'),
                  value: hatSpieler,
                  onChanged: (v) => setState(() => hatSpieler = v),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Individuelle Gewinner'),
                  subtitle: const Text(
                      'Statt fester Partei werden Gewinner pro Runde einzeln gewählt (0, 1 oder 2). Ermöglicht Unentschieden, z.B. für Ramsch.'),
                  value: individuelleGewinner,
                  onChanged: (v) =>
                      setState(() => individuelleGewinner = v),
                ),
                const SizedBox(height: 16),
                if (individuelleGewinner) ...[
                  const SizedBox(height: 8),
                  const Text('Anzahl beteiligter Spieler'),
                  const SizedBox(height: 4),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Flexibel (0-2)')),
                      ButtonSegment(value: 1, label: Text('Immer 1')),
                      ButtonSegment(value: 2, label: Text('Immer 2')),
                    ],
                    selected: {individuelleAnzahl},
                    onSelectionChanged: (selection) =>
                        setState(() => individuelleAnzahl = selection.first),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Eigene feste Beträge'),
                    subtitle: const Text(
                        'Statt der normalen Tarif-Berechnung werden feste Beträge für Sieg/Niederlage verwendet (z.B. für Ramsch).'),
                    value: eigeneBetraege,
                    onChanged: (v) => setState(() => eigeneBetraege = v),
                  ),
                  if (eigeneBetraege) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: siegController,
                            decoration: const InputDecoration(
                                labelText: 'Betrag bei Sieg (€)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: verlustController,
                            decoration: const InputDecoration(
                                labelText: 'Betrag bei Niederlage (€)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (bestehende == null) {
                  if (individuelleGewinner) {
                  service.spielartHinzufuegen(name, einzelspieler,
                      individuelleGewinner: individuelleGewinner, individuelleAnzahl: individuelleAnzahl, eigeneBetraege: eigeneBetraege, siegBetrag: double.parse(siegController.text), verlustBetrag: double.parse(verlustController.text), hatSpieler: hatSpieler);
                  } else {
                    service.spielartHinzufuegen(name, einzelspieler, hatSpieler: hatSpieler);
                  }
                } else {
                  if (individuelleGewinner) {
                    service.spielartAktualisieren(
                        bestehende, name, einzelspieler,
                        individuelleGewinner: individuelleGewinner, individuelleAnzahl: individuelleAnzahl, eigeneBetraege: eigeneBetraege, siegBetrag: double.parse(siegController.text), verlustBetrag: double.parse(verlustController.text), hatSpieler: hatSpieler);
                  } else {
                    service.spielartAktualisieren(bestehende, name, einzelspieler, hatSpieler: hatSpieler);
                  }
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Spielart s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spielart löschen?'),
        content: Text(
            '"${s.name}" wird aus dem Katalog entfernt. Bereits gespielte Runden bleiben unverändert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.spielartLoeschen(s);
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
