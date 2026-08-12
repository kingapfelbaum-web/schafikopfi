import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../models/tarif.dart';
import '../services/spiel_service.dart';
import 'spiele_bearbeiten_screen.dart';
import 'tisch_detail_screen.dart';

class NeuesSpielScreen extends StatefulWidget {
  const NeuesSpielScreen({super.key});

  @override
  State<NeuesSpielScreen> createState() => _NeuesSpielScreenState();
}

class _NeuesSpielScreenState extends State<NeuesSpielScreen> {
  final List<Spieler> _ausgewaehlt = [];
  final _neuerNameController = TextEditingController();

  late TextEditingController _sauspielController;
  late TextEditingController _soloController;
  late TextEditingController _aufpreisController;
  Set<String>? _ausgewaehlteSpielartenIds; // null = noch nicht initialisiert

  @override
  void dispose() {
    _neuerNameController.dispose();
    _sauspielController.dispose();
    _soloController.dispose();
    _aufpreisController.dispose();
    super.dispose();
  }

  void _spielerHinzufuegen(Spieler s) {
    if (_ausgewaehlt.length >= 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximal 14 Spieler pro Tisch möglich')),
      );
      return;
    }
    setState(() {
      if (!_ausgewaehlt.contains(s)) _ausgewaehlt.add(s);
    });
  }

  void _neuenSpielerAnlegen(SpielService service) {
    final name = _neuerNameController.text.trim();
    if (name.isEmpty) return;
    final s = service.spielerAnlegen(name);
    _neuerNameController.clear();
    _spielerHinzufuegen(s);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final verfuegbar = service.allePlayerinnen
        .where((s) => !_ausgewaehlt.contains(s))
        .toList();

    // Einmalig mit den App-Standardwerten vorbefüllen.
    if (_ausgewaehlteSpielartenIds == null) {
      final tarif = service.standardTarif;
      _sauspielController =
          TextEditingController(text: tarif.sauspielPreis.toStringAsFixed(2));
      _soloController =
          TextEditingController(text: tarif.soloPreis.toStringAsFixed(2));
      _aufpreisController =
          TextEditingController(text: tarif.aufpreis.toStringAsFixed(2));
      _ausgewaehlteSpielartenIds =
          Set.of(service.standardAusgewaehlteSpielartenIds);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Neues Spiel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _neuerNameController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Neuen Spieler anlegen',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _neuenSpielerAnlegen(service),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () => _neuenSpielerAnlegen(service),
                  ),
                ],
              ),
              if (_neuerNameController.text.length >= 20)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Maximale Länge von 20 Zeichen erreicht',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (verfuegbar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Bekannte Spieler',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            Wrap(
              spacing: 8,
              children: verfuegbar
                  .map((s) => ActionChip(
                        label: Text(s.name),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed:
                         _ausgewaehlt.length >= 14 ? null : () => _spielerHinzufuegen(s),
                      ))
                  .toList(),
            ),
          ],
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Reihenfolge am Tisch (${_ausgewaehlt.length} Spieler, min. 4)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          _ausgewaehlt.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Noch keine Spieler ausgewählt'),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ausgewaehlt.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final s = _ausgewaehlt.removeAt(oldIndex);
                      _ausgewaehlt.insert(newIndex, s);
                    });
                  },
                  itemBuilder: (context, index) {
                    final s = _ausgewaehlt[index];
                    return ListTile(
                      key: ValueKey(s.id),
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(s.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _ausgewaehlt.remove(s)),
                      ),
                    );
                  },
                ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Verfügbare Spiele',
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Spiele bearbeiten'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SpieleBearbeitenScreen()),
                  );
                  // Nach dem Bearbeiten evtl. neu hinzugekommene Spiele
                  // ebenfalls vorauswählen.
                  setState(() {
                    final gueltigeIds =
                        service.spielarten.map((s) => s.id).toSet();
                    _ausgewaehlteSpielartenIds =
                        _ausgewaehlteSpielartenIds!.union(
                      service.standardAusgewaehlteSpielartenIds
                          .difference(_ausgewaehlteSpielartenIds!),
                    )..retainAll(gueltigeIds);
                  });
                },
              ),
            ],
          ),
          if (service.spielarten.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Noch keine Spielarten angelegt'),
            )
          else
            ...service.spielarten.map((s) => CheckboxListTile(
                  value: _ausgewaehlteSpielartenIds!.contains(s.id),
                  title: Text(s.name),
                  subtitle:
                      Text(s.einzelspieler ? 'Solo' : 'Sauspiel'),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _ausgewaehlteSpielartenIds!.add(s.id);
                      } else {
                        _ausgewaehlteSpielartenIds!.remove(s.id);
                      }
                    });
                  },
                )),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text('Tarif', style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sauspielController,
                  decoration: const InputDecoration(
                      labelText: 'Sauspiel (€)', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _soloController,
                  decoration: const InputDecoration(
                      labelText: 'Solo (€)', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aufpreisController,
            decoration: const InputDecoration(
                labelText: 'Aufpreis je Laufendem / Schneider (€)',
                border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  label: const Text('Tisch Erstellen'),
                  onPressed: _ausgewaehlt.length < 4 ||
                      _ausgewaehlteSpielartenIds!.isEmpty
                      ? null
                      : () => _erstellen(service),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _erstellen(SpielService service) {
    final tarif = Tarif(
      sauspielPreis: double.tryParse(
              _sauspielController.text.replaceAll(',', '.')) ??
          0.20,
      soloPreis:
          double.tryParse(_soloController.text.replaceAll(',', '.')) ?? 0.50,
      aufpreis: double.tryParse(
              _aufpreisController.text.replaceAll(',', '.')) ??
          0.20,
    );
    final gewaehlteSpielarten = service.spielarten
        .where((s) => _ausgewaehlteSpielartenIds!.contains(s.id))
        .toList();
    final neuerTisch = service.tischAnlegen(_ausgewaehlt,
        tarif: tarif, spielarten: gewaehlteSpielarten);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TischDetailScreen(tisch: neuerTisch)),
    );
  }
}
