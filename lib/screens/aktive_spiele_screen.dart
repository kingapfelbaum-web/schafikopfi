import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/spiel_service.dart';
import '../widgets/tisch_karte.dart';
import '../models/tisch.dart';
import 'tisch_detail_screen.dart';

class AktiveSpieleScreen extends StatelessWidget {

  const AktiveSpieleScreen({
    super.key,
  });

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Tisch tisch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tisch löschen?'),
        content: const Text(
            'Dieser Tisch inklusive aller Spiele wird endgültig gelöscht. Das kann nicht rückgängig gemacht werden.'),
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
    final tische = service.aktiveTische;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Aktive Tische'),
      ),
      // Der "Neues Spiel"-Button ist jetzt Teil der bottomNavigationBar,
      // daher braucht der Inhalt kein zusätzliches Bottom-Padding mehr.
      body: tische.isEmpty
          ? const Center(child: Text('Noch kein aktiver Tisch'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: tische.length,
              itemBuilder: (context, index) {
                final tisch = tische[index];
                return TischKarte(
                  tisch: tisch,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TischDetailScreen(tisch: tisch),
                    ),
                  ),
                  onDelete: () => _loeschenBestaetigen(
                      context, service, tisch),
                );
              },
            ),
    );
  }
}
