import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tisch.dart';
import '../services/spiel_service.dart';
import '../services/sync_service.dart';

class SyncAuswahlScreen extends StatefulWidget {
  final Gruppe gruppe;
  const SyncAuswahlScreen({super.key, required this.gruppe});

  @override
  State<SyncAuswahlScreen> createState() => _SyncAuswahlScreenState();
}

class _SyncAuswahlScreenState extends State<SyncAuswahlScreen> {
  Set<String> _uploadAuswahl = {};
  Set<String> _downloadAuswahl = {};
  Set<String> _bereitsSynchronisierteIds = {};
  Set<String> _abweichendeIds = {};

  Map<String, dynamic>? _remoteJson;
  List<RemoteTischInfo> _remoteNeueTische = [];
  bool _ladeRemote = true;
  String? _remoteFehler;

  @override
  void initState() {
    super.initState();
    _remoteLaden();
  }

  Future<Map<String, String>?> _tischKonfliktePruefen(
      List<Tisch> ausgewaehlteTische,
      bool isUpload,
      ) async {
    if (_remoteJson == null) return {};
    final remoteTischeMap = <String, Map<String, dynamic>>{
      for (final t in (_remoteJson!['tische'] as List? ?? []))
        (t as Map<String, dynamic>)['id'] as String: t as Map<String, dynamic>,
    };

    final sync = context.read<SyncService>();
    final entscheidungen = <String, String>{};

    for (final tisch in ausgewaehlteTische) {
      final remoteTischJson = remoteTischeMap[tisch.id];
      if (remoteTischJson == null) continue;

      final differ = sync.tischUnterscheidetSich(tisch, remoteTischJson);
      if (!differ) continue;

      final datumStr =
          '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year}';
      final spielerStr = tisch.spieler.map((s) => s.name).join(', ');

      final titel = isUpload
          ? 'Tisch unterscheidet sich in der Cloud'
          : 'Lokaler Tisch unterscheidet sich';
      final inhalt = isUpload
          ? 'Der Tisch vom $datumStr ($spielerStr) existiert bereits in der Cloud, unterscheidet sich aber von deiner lokalen Version.'
          : 'Der Tisch vom $datumStr ($spielerStr) existiert bereits auf deinem Gerät, unterscheidet sich aber von der Cloud-Version.';

      final overwriteBtnText =
      isUpload ? 'Cloud überschreiben' : 'Lokal überschreiben';

      final ergebnis = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(titel),
          content: Text(inhalt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Abbrechen'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('overwrite'),
              child: Text(overwriteBtnText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Zusammenführen'),
            ),
          ],
        ),
      );

      if (ergebnis == null || ergebnis == 'cancel') return null;
      entscheidungen[tisch.id] = ergebnis;
    }
    return entscheidungen;
  }

  Future<void> _remoteLaden() async {
    setState(() {
      _ladeRemote = true;
      _remoteFehler = null;
    });
    final sync = context.read<SyncService>();
    final spielService = context.read<SpielService>();
    try {
      final json = await sync.remoteDatenAbrufen(widget.gruppe);
      setState(() {
        _remoteJson = json;
        _remoteNeueTische = json == null ? [] : sync.neueRemoteTische(json);
        _downloadAuswahl = _remoteNeueTische.map((t) => t.id).toSet();

        _bereitsSynchronisierteIds = {};
        _abweichendeIds = {};

        if (json != null) {
          final remoteTischeMap = <String, Map<String, dynamic>>{
            for (final t in (json['tische'] as List? ?? []))
              (t as Map<String, dynamic>)['id'] as String:
              t as Map<String, dynamic>,
          };

          for (final lokalerTisch in spielService.alleTische) {
            final remoteTisch = remoteTischeMap[lokalerTisch.id];
            if (remoteTisch != null) {
              final status = sync.vergleicheTische(lokalerTisch, remoteTisch);
              if (status == TischSyncStatus.lokalNeuer) {
                _abweichendeIds.add(lokalerTisch.id);
              } else {
                _bereitsSynchronisierteIds.add(lokalerTisch.id);
              }
            }
          }
        }

        _uploadAuswahl.removeWhere(_bereitsSynchronisierteIds.contains);
      });
    } catch (e) {
      setState(() => _remoteFehler = e.toString());
    } finally {
      setState(() => _ladeRemote = false);
    }
  }

  Future<void> _hochladen(SyncService sync) async {
    if (_uploadAuswahl.isEmpty) return;

    final spielService = context.read<SpielService>();
    final tischeFuerUpload = spielService.alleTische
        .where((t) => _uploadAuswahl.contains(t.id))
        .toList();

    final tischEntscheidungen =
    await _tischKonfliktePruefen(tischeFuerUpload, true);
    if (tischEntscheidungen == null) return;

    final hochgeladeneIds = Set<String>.of(_uploadAuswahl);
    await sync.hochladenAusgewaehlt(
      widget.gruppe,
      _uploadAuswahl,
      tischEntscheidungen: tischEntscheidungen,
    );

    if (!mounted) return;
    if (sync.letzterFehler != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: ${sync.letzterFehler}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${hochgeladeneIds.length} Tisch(e) hochgeladen')),
      );
      await _remoteLaden();
    }
  }

  Future<void> _herunterladen(
      SyncService sync, SpielService spielService) async {
    if (_downloadAuswahl.isEmpty || _remoteJson == null) return;

    final tischeFuerDownload = spielService.alleTische
        .where((t) => _downloadAuswahl.contains(t.id))
        .toList();

    final tischEntscheidungen =
    await _tischKonfliktePruefen(tischeFuerDownload, false);
    if (tischEntscheidungen == null) return;

    final konflikte = spielService.remoteKonflikteErmitteln(
      _remoteJson!,
      tischIds: _downloadAuswahl,
    );

    final spielerEntscheidungen = <String, String>{};
    for (final konflikt in konflikte) {
      if (!mounted) return;
      final ergebnis = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Spielername bereits vorhanden'),
          content: Text(
              'Es gibt bereits einen Spieler namens "${konflikt.name}". '
                  'Zusammenführen verknüpft die Statistiken beider. '
                  'Getrennt halten legt den importierten Spieler als '
                  '"${konflikt.name} (${widget.gruppe.anzeigename})" an.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen')),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('rename'),
              child: const Text('Getrennt halten'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Zusammenführen'),
            ),
          ],
        ),
      );
      if (ergebnis == null) return;
      spielerEntscheidungen[konflikt.importierteId] = ergebnis;
    }

    final anzahl = await sync.herunterladenAusgewaehlt(
      widget.gruppe,
      _remoteJson!,
      _downloadAuswahl,
      spielerEntscheidungen,
      tischEntscheidungen: tischEntscheidungen,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$anzahl Tisch(e) heruntergeladen')),
    );
    await _remoteLaden();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final spielService = context.watch<SpielService>();
    final lokaleTische = List.of(spielService.alleTische)
      ..sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Synchronisieren · ${widget.gruppe.anzeigename}'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Hochladen'),
            Tab(text: 'Herunterladen'),
          ]),
        ),
        body: TabBarView(
          children: [
            // ---------- Upload ----------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _ladeRemote
                        ? 'Prüfe, welche Tische bereits synchronisiert sind …'
                        : 'Nur beendete Tische können hochgeladen werden. Wähle aus, welche in die Gruppe übertragen werden sollen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: _ladeRemote
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(builder: (context) {
                    final beendeteTische = lokaleTische
                        .where((t) => t.status == TischStatus.beendet)
                        .toList();
                    final hochladbareTische = beendeteTische
                        .where((t) => !_bereitsSynchronisierteIds
                        .contains(t.id))
                        .toList();
                    final bereitsSynchronisiert = beendeteTische
                        .where((t) => _bereitsSynchronisierteIds
                        .contains(t.id))
                        .toList();

                    if (beendeteTische.isEmpty) {
                      return const Center(
                          child: Text(
                              'Keine beendeten Tische vorhanden. Nur beendete Tische können hochgeladen werden.'));
                    }

                    return ListView(
                      children: [
                        if (hochladbareTische.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Alle lokalen Tische sind bereits synchronisiert'),
                          )
                        else
                          ...hochladbareTische.map((tisch) {
                            final istAbweichend =
                            _abweichendeIds.contains(tisch.id);
                            return CheckboxListTile(
                              value: _uploadAuswahl.contains(tisch.id),
                              title: Text(tisch.spieler
                                  .map((s) => s.name)
                                  .join(', ')),
                              subtitle: Text(
                                '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year} · '
                                    '${tisch.runden.length} Spiele${istAbweichend ? ' · Lokal geändert (neuer als Cloud)' : ''}',
                                style: TextStyle(
                                    color: istAbweichend
                                        ? Colors.orange.shade800
                                        : null),
                              ),
                              secondary: istAbweichend
                                  ? const Icon(Icons.sync_problem,
                                  color: Colors.orange)
                                  : null,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _uploadAuswahl.add(tisch.id);
                                  } else {
                                    _uploadAuswahl.remove(tisch.id);
                                  }
                                });
                              },
                            );
                          }),
                        if (bereitsSynchronisiert.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 4),
                            child: Text(
                              'Bereits synchronisiert (${bereitsSynchronisiert.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ),
                          ...bereitsSynchronisiert.map((tisch) => ListTile(
                            enabled: false,
                            leading: const Icon(Icons.cloud_done,
                                color: Colors.grey),
                            title: Text(
                              tisch.spieler
                                  .map((s) => s.name)
                                  .join(', '),
                              style: TextStyle(
                                  color: Colors.grey.shade500),
                            ),
                            subtitle: Text(
                              '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year} · ${tisch.runden.length} Spiele',
                            ),
                          )),
                        ],
                      ],
                    );
                  }),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: sync.istAmSynchronisieren
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload),
                        label: Text('Hochladen (${_uploadAuswahl.length})'),
                        onPressed: _uploadAuswahl.isEmpty ||
                            sync.istAmSynchronisieren
                            ? null
                            : () => _hochladen(sync),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ---------- Download ----------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Diese Tische sind in der Gruppe vorhanden und lokal noch nicht bekannt oder in der Cloud neuer.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: _ladeRemote
                      ? const Center(child: CircularProgressIndicator())
                      : _remoteFehler != null
                      ? Center(child: Text('Fehler: $_remoteFehler'))
                      : _remoteNeueTische.isEmpty
                      ? const Center(
                      child: Text(
                          'Keine neuen oder geänderten Tische in der Gruppe'))
                      : ListView.builder(
                    itemCount: _remoteNeueTische.length,
                    itemBuilder: (context, index) {
                      final info = _remoteNeueTische[index];
                      return CheckboxListTile(
                        value: _downloadAuswahl.contains(info.id),
                        title: Text(info.spielerNamen.join(', ')),
                        subtitle: Text(
                          '${info.erstelltAm.day.toString().padLeft(2, '0')}.${info.erstelltAm.month.toString().padLeft(2, '0')}.${info.erstelltAm.year} · '
                              '${info.anzahlRunden} Spiele${info.istGeaendert ? ' · In Cloud geändert (neuer als lokal)' : ''}',
                          style: TextStyle(
                              color: info.istGeaendert
                                  ? Colors.orange.shade800
                                  : null),
                        ),
                        secondary: info.istGeaendert
                            ? const Icon(Icons.sync_problem,
                            color: Colors.orange)
                            : null,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _downloadAuswahl.add(info.id);
                            } else {
                              _downloadAuswahl.remove(info.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Aktualisieren',
                          onPressed: _ladeRemote ? null : _remoteLaden,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: sync.istAmSynchronisieren
                                ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download),
                            label: Text(
                                'Herunterladen (${_downloadAuswahl.length})'),
                            onPressed: _downloadAuswahl.isEmpty ||
                                sync.istAmSynchronisieren
                                ? null
                                : () => _herunterladen(sync, spielService),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}