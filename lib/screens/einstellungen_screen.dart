import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tarif.dart';
import '../services/spiel_service.dart';
import 'spiele_bearbeiten_screen.dart';
import 'spieler_verwalten_screen.dart';
import 'gruppe_screen.dart';

class EinstellungenScreen extends StatefulWidget {
  const EinstellungenScreen({super.key});

  @override
  State<EinstellungenScreen> createState() => _EinstellungenScreenState();
}

class _EinstellungenScreenState extends State<EinstellungenScreen> {
  late TextEditingController _sauspielController;
  late TextEditingController _soloController;
  late TextEditingController _aufpreisController;

  @override
  void initState() {
    super.initState();
    final service = context.read<SpielService>();
    final tarif = service.standardTarif;
    _sauspielController =
        TextEditingController(text: tarif.sauspielPreis.toStringAsFixed(2));
    _soloController =
        TextEditingController(text: tarif.soloPreis.toStringAsFixed(2));
    _aufpreisController =
        TextEditingController(text: tarif.aufpreis.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _sauspielController.dispose();
    _soloController.dispose();
    _aufpreisController.dispose();
    super.dispose();
  }

  void _speichern() {
    final service = context.read<SpielService>();
    service.standardTarifAendern(Tarif(
      sauspielPreis:
          double.tryParse(_sauspielController.text.replaceAll(',', '.')) ??
              0.20,
      soloPreis:
          double.tryParse(_soloController.text.replaceAll(',', '.')) ?? 0.50,
      aufpreis:
          double.tryParse(_aufpreisController.text.replaceAll(',', '.')) ??
              0.20,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard-Tarif gespeichert')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
          title: const Text('Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Standard-Tarif für neue Tische',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
              'Diese Werte werden beim Erstellen eines neuen Tisches vorausgefüllt.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _speichern,
            child: const Text('Speichern'),
          ),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spielarten',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verwalte verfügbare Spielarten und lege fest, welche beim Erstellen eines neuen Tisches vorausgewählt sind.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Bearbeiten'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SpieleBearbeitenScreen()),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spieler',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.group),
                label: const Text('Spieler verwalten'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SpielerVerwaltenScreen()),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gruppen-Synchronisierung',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.group_work),
                label: const Text('Verwalten'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GruppeScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Teile Spieler und Spiele mit anderen Geräten über eine gemeinsame Gruppe.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
