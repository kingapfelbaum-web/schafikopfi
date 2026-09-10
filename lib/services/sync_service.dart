import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spiel_service.dart';

/// Info-Objekt für einen auf dem Server vorhandenen, lokal noch NICHT
/// vorhandenen Tisch (zur Anzeige in der Download-Auswahl).
class RemoteTischInfo {
  final String id;
  final DateTime erstelltAm;
  final List<String> spielerNamen;
  final int anzahlRunden;
  final bool istBeendet;

  RemoteTischInfo({
    required this.id,
    required this.erstelltAm,
    required this.spielerNamen,
    required this.anzahlRunden,
    required this.istBeendet,
  });
}

/// Eine einzelne Gruppe, der beigetreten wurde.
class Gruppe {
  final String id;
  String? name;

  Gruppe({required this.id, this.name});

  String get anzeigename => name ?? id;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Gruppe.fromJson(Map<String, dynamic> json) => Gruppe(
    id: json['id'] as String,
    name: json['name'] as String?,
  );

  @override
  bool operator ==(Object other) => other is Gruppe && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Verwaltet die Mitgliedschaft in MEHREREN Synchronisierungs-Gruppen und
/// den selektiven Datenabgleich mit Firebase Firestore. Jede Gruppe ist ein
/// eigenes JSON-Dokument in Firestore (Collection "gruppen", Dokument-ID =
/// Gruppen-Code).
class SyncService extends ChangeNotifier {
  final SpielService spielService;
  static const _gruppenKey = 'schafkopf_gruppen_liste_v1';

  final List<Gruppe> _gruppen = [];
  bool istAmSynchronisieren = false;
  DateTime? letzterSync;
  String? letzterFehler;

  SyncService(this.spielService);

  List<Gruppe> get gruppen => List.unmodifiable(_gruppen);
  bool get istInMindestensEinerGruppe => _gruppen.isNotEmpty;

  CollectionReference<Map<String, dynamic>> get _gruppenCollection =>
      FirebaseFirestore.instance.collection('gruppen');

  Future<void> gruppenLaden() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gruppenKey);
    _gruppen.clear();
    if (raw != null) {
      try {
        final liste = jsonDecode(raw) as List;
        _gruppen.addAll(
            liste.map((g) => Gruppe.fromJson(g as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('Gruppenliste konnte nicht geladen werden: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _gruppenSpeichern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gruppenKey,
      jsonEncode(_gruppen.map((g) => g.toJson()).toList()),
    );
  }

  Future<void> gruppeBeitreten(String code, {String? anzeigename}) async {
    final id = code.trim();
    if (id.isEmpty) return;
    if (_gruppen.any((g) => g.id == id)) return; // bereits Mitglied

    final name = anzeigename?.trim();
    _gruppen.add(Gruppe(id: id, name: (name == null || name.isEmpty) ? null : name));
    await _gruppenSpeichern();
    notifyListeners();
  }

  Future<void> gruppeVerlassen(Gruppe gruppe) async {
    _gruppen.removeWhere((g) => g.id == gruppe.id);
    await _gruppenSpeichern();
    notifyListeners();
  }

  /// Lädt den kompletten Remote-Datensatz einer bestimmten Gruppe herunter.
  Future<Map<String, dynamic>?> remoteDatenAbrufen(Gruppe gruppe) async {
    final snapshot = await _gruppenCollection.doc(gruppe.id).get();
    if (!snapshot.exists || snapshot.data()?['daten'] is! String) return null;
    return jsonDecode(snapshot.data()!['daten'] as String)
    as Map<String, dynamic>;
  }

  List<RemoteTischInfo> neueRemoteTische(Map<String, dynamic> remoteJson) {
    final lokaleIds = spielService.alleTische.map((t) => t.id).toSet();
    final spielerNamenById = <String, String>{
      for (final p in (remoteJson['allePlayerinnen'] as List? ?? []))
        (p as Map<String, dynamic>)['id'] as String: p['name'] as String,
    };

    final ergebnis = <RemoteTischInfo>[];
    for (final t in (remoteJson['tische'] as List? ?? [])) {
      final tischJson = t as Map<String, dynamic>;
      final id = tischJson['id'] as String;
      if (lokaleIds.contains(id)) continue;
      final spielerIds =
      List<String>.from(tischJson['spielerIds'] as List? ?? []);
      ergebnis.add(RemoteTischInfo(
        id: id,
        erstelltAm:
        DateTime.tryParse(tischJson['erstelltAm'] as String? ?? '') ??
            DateTime.now(),
        spielerNamen:
        spielerIds.map((sid) => spielerNamenById[sid] ?? '?').toList(),
        anzahlRunden: (tischJson['runden'] as List? ?? []).length,
        istBeendet: tischJson['status'] == 'beendet',
      ));
    }
    ergebnis.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));
    return ergebnis;
  }

  Future<int> herunterladenAusgewaehlt(
      Gruppe gruppe,
      Map<String, dynamic> remoteJson,
      Set<String> tischIds,
      Map<String, String> entscheidungen,
      ) async {
    final anzahl = spielService.serverDatenEinspielenAusgewaehlt(
      remoteJson,
      tischIds: tischIds,
      spielerEntscheidungen: entscheidungen,
      gruppenName: gruppe.anzeigename,
    );
    letzterSync = DateTime.now();
    notifyListeners();
    return anzahl;
  }

  Future<void> hochladenAusgewaehlt(Gruppe gruppe, Set<String> tischIds) async {
    if (tischIds.isEmpty) return;
    istAmSynchronisieren = true;
    letzterFehler = null;
    notifyListeners();

    try {
      final teilExportStr =
      spielService.datenExportierenGefiltert(tischIds: tischIds);
      final teilExport = jsonDecode(teilExportStr) as Map<String, dynamic>;

      final dokument = _gruppenCollection.doc(gruppe.id);
      final snapshot = await dokument.get();
      final bisherigesRemote =
      (snapshot.exists && snapshot.data()?['daten'] is String)
          ? jsonDecode(snapshot.data()!['daten'] as String)
      as Map<String, dynamic>
          : <String, dynamic>{};

      final zusammengefuehrt =
      zusammenfuehrenJsonDokumente(bisherigesRemote, teilExport);

      await dokument.set({
        'daten': const JsonEncoder.withIndent('  ').convert(zusammengefuehrt),
        'aktualisiertAm': DateTime.now().toIso8601String(),
        if (gruppe.name != null) 'name': gruppe.name,
      });
      letzterSync = DateTime.now();
    } catch (e) {
      letzterFehler = e.toString();
      debugPrint('Upload fehlgeschlagen: $e');
    } finally {
      istAmSynchronisieren = false;
      notifyListeners();
    }
  }
}