import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../services/spiel_service.dart';

class SpielerVerwaltenScreen extends StatelessWidget {
  const SpielerVerwaltenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final spieler = service.allePlayerinnen;

    return Scaffold(
      appBar: AppBar(title: const Text('Spieler verwalten')),
      body: spieler.isEmpty
          ? const Center(child: Text('Noch keine Spieler angelegt'))
          : ListView.builder(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        itemCount: spieler.length,
        itemBuilder: (context, index) {
          final s = spieler[index];
          final kannGeloeschtWerden =
           service.spielerKannGeloeschtWerden(s);
          return Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: kannGeloeschtWerden
                  ? null
                  : Text(
                'Nimmt an einem aktiven Spiel teil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: kannGeloeschtWerden
                    ? () => _loeschenBestaetigen(context, service, s)
                    : null,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          onPressed: () => spielerHinzufuegenDialog(context, service),
          label: const Text('Spieler hinzufügen')
      ),
    );
  }

  void spielerHinzufuegenDialog(
      BuildContext context, SpielService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Neuer Spieler'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLength: 20,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (controller.text.length >= 20)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text( 'Maximale Länge von 20 Zeichen erreicht',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () {
                final name = controller.text.trim();
                service.spielerAnlegen(name);
                Navigator.of(ctx).pop();
                },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Spieler spieler) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spieler löschen?'),
        content: Text(
            '"${spieler.name}" wird aus der Liste entfernt. Bereits gespielte Runden bleiben unverändert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.spielerLoeschen(spieler);
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}