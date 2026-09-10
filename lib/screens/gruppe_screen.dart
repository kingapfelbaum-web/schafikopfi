import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import 'sync_auswahl_screen.dart';

class GruppeScreen extends StatefulWidget {
  const GruppeScreen({super.key});

  @override
  State<GruppeScreen> createState() => _GruppeScreenState();
}

class _GruppeScreenState extends State<GruppeScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _beitreten(SyncService sync) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    await sync.gruppeBeitreten(code, anzeigename: _nameController.text);
    _codeController.clear();
    _nameController.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _verlassenBestaetigen(SyncService sync, Gruppe gruppe) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gruppe verlassen?'),
        content: Text(
            'Du verlässt "${gruppe.anzeigename}". Deine lokalen Daten bleiben erhalten, '
                'werden aber nicht mehr mit dieser Gruppe synchronisiert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
    if (bestaetigt == true) {
      await sync.gruppeVerlassen(gruppe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppen-Synchronisierung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Tritt einer oder mehreren Gruppen bei, um Spieler und Spiele mit anderen Geräten zu teilen. '
                  'Ein neuer Code legt automatisch eine neue Gruppe an.'),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Gruppen-Code',
              hintText: 'z.B. familie-schafkopf-2026',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Anzeigename der Gruppe (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _beitreten(sync),
              child: const Text('Gruppe beitreten / erstellen'),
            ),
          ),
          const Divider(height: 40),
          Text('Meine Gruppen (${sync.gruppen.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (sync.gruppen.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keiner Gruppe beigetreten'),
            )
          else
            ...sync.gruppen.map((gruppe) => Card(
              child: ListTile(
                leading: const Icon(Icons.group_work),
                title: Text(gruppe.anzeigename),
                subtitle: gruppe.name != null
                    ? Text('Code: ${gruppe.id}')
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SyncAuswahlScreen(gruppe: gruppe),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Gruppe verlassen',
                  onPressed: () => _verlassenBestaetigen(sync, gruppe),
                ),
              ),
            )),
        ],
      ),
    );
  }
}