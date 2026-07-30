import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';
import '../services/spiel_service.dart';
import '../widgets/tisch_karte.dart';
import '../models/tisch.dart';
import 'tisch_detail_screen.dart';

class AktiveSpieleScreen extends StatelessWidget {
  final UpdateInfo? updateInfo;
  final VoidCallback? onUpdateTap;

  const AktiveSpieleScreen({
    super.key,
    this.updateInfo,
    this.onUpdateTap,
  });

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
    final tische = service.aktiveTische;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Aktive Spiele'),
          actions: [
            if (updateInfo != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: onUpdateTap,
                  icon: const Icon(Icons.system_update,
                      color: Colors.orange, size: 18),
                  label: const Text('Update',
                      style: TextStyle(
                          color: Colors.orange, fontSize: 12)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              ),
          ],
      ),
      // Der "Neues Spiel"-Button ist jetzt Teil der bottomNavigationBar,
      // daher braucht der Inhalt kein zusätzliches Bottom-Padding mehr.
      body: tische.isEmpty
          ? const Center(child: Text('Noch kein aktives Spiel'))
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
