import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spiel_service.dart';
import '../models/tisch.dart';

enum TischSyncStatus {
  neuLokal,     // Existiert nur lokal -> Hochladen
  neuRemote,    // Existiert nur in Cloud -> Herunterladen
  identisch,    // Zeitstempel gleich -> Keine Aktion
  lokalNeuer,   // Lokaler Stand ist neuer -> Im Upload-Tab anbieten
  remoteNeuer,  // Cloud-Stand ist neuer -> Im Download-Tab anbieten
}

/// Info-Objekt für einen auf dem Server vorhandenen, lokal noch NICHT
/// vorhandenen Tisch (zur Anzeige in der Download-Auswahl).
class RemoteTischInfo {
  final String id;
  final DateTime erstelltAm;
  final List<String> spielerNamen;
  final int anzahlRunden;
  final bool istBeendet;
  final bool istGeaendert;

  RemoteTischInfo({
    required this.id,
    required this.erstelltAm,
    required this.spielerNamen,
    required this.anzahlRunden,
    required this.istBeendet,
    this.istGeaendert = false,
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
    try {
      await aktivitaetVermerken(Gruppe(id: id));
    } catch (_) {}
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
    try {
      await aktivitaetVermerken(gruppe);
    } catch (_) {}
    final snapshot = await _gruppenCollection.doc(gruppe.id).get();
    if (!snapshot.exists || snapshot.data()?['daten'] is! String) return null;
    return jsonDecode(snapshot.data()!['daten'] as String)
    as Map<String, dynamic>;
  }

  TischSyncStatus vergleicheTische(
      Tisch lokalerTisch, Map<String, dynamic> remoteTischJson) {
    DateTime? remoteAktualisiert;
    final remoteStr = remoteTischJson['aktualisiertAm'] as String?;
    if (remoteStr != null) {
      remoteAktualisiert = DateTime.tryParse(remoteStr);
    }

    remoteAktualisiert ??= DateTime.tryParse(
        remoteTischJson['beendetAm'] as String? ?? '') ??
        DateTime.tryParse(remoteTischJson['erstelltAm'] as String? ?? '');

    if (remoteAktualisiert == null) {
      return TischSyncStatus.lokalNeuer;
    }

    final lokalIso = lokalerTisch.aktualisiertAm.toIso8601String();
    final remoteIso = remoteAktualisiert.toIso8601String();

    final diffMs = lokalerTisch.aktualisiertAm
        .difference(remoteAktualisiert)
        .inMilliseconds
        .abs();
    if (diffMs < 1000 || lokalIso == remoteIso || lokalerTisch.aktualisiertAm.isAtSameMomentAs(remoteAktualisiert)) {
      return TischSyncStatus.identisch;
    }

    if (lokalerTisch.aktualisiertAm.isAfter(remoteAktualisiert)) {
      return TischSyncStatus.lokalNeuer;
    } else {
      return TischSyncStatus.remoteNeuer;
    }
  }

  bool tischUnterscheidetSich(
      Tisch lokalerTisch, Map<String, dynamic> remoteTischJson) {
    return vergleicheTische(lokalerTisch, remoteTischJson) !=
        TischSyncStatus.identisch;
  }

  List<RemoteTischInfo> neueRemoteTische(Map<String, dynamic> remoteJson) {
    final lokaleTischeMap = {for (final t in spielService.alleTische) t.id: t};
    final spielerNamenById = <String, String>{
      for (final p in (remoteJson['allePlayerinnen'] as List? ?? []))
        (p as Map<String, dynamic>)['id'] as String: p['name'] as String,
    };

    final ergebnis = <RemoteTischInfo>[];
    for (final t in (remoteJson['tische'] as List? ?? [])) {
      final tischJson = t as Map<String, dynamic>;
      final id = tischJson['id'] as String;
      final lokalerTisch = lokaleTischeMap[id];

      bool istGeaendert = false;
      if (lokalerTisch != null) {
        final status = vergleicheTische(lokalerTisch, tischJson);
        if (status != TischSyncStatus.remoteNeuer) continue; // Identischer Stand -> nicht erneut herunterladen
        istGeaendert = true;
      }

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
        istGeaendert: istGeaendert,
      ));
    }
    ergebnis.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));
    return ergebnis;
  }

  Future<int> herunterladenAusgewaehlt(
      Gruppe gruppe,
      Map<String, dynamic> remoteJson,
      Set<String> tischIds,
      Map<String, String> entscheidungen, {
        Map<String, String> tischEntscheidungen = const {},
      }) async {
    try {
      await aktivitaetVermerken(gruppe);
    } catch (_) {}
    final anzahl = spielService.serverDatenEinspielenAusgewaehlt(
      remoteJson,
      tischIds: tischIds,
      spielerEntscheidungen: entscheidungen,
      tischEntscheidungen: tischEntscheidungen,
      gruppenName: gruppe.anzeigename,
    );
    letzterSync = DateTime.now();
    notifyListeners();
    return anzahl;
  }

  Future<void> hochladenAusgewaehlt(
      Gruppe gruppe,
      Set<String> tischIds, {
        Map<String, String> tischEntscheidungen = const {},
      }) async {
    try {
      await aktivitaetVermerken(gruppe);
    } catch (_) {}
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

      final zusammengefuehrt = zusammenfuehrenJsonDokumente(
        bisherigesRemote,
        teilExport,
        tischModi: tischEntscheidungen,
      );

      await dokument.set({
        'daten': const JsonEncoder.withIndent('  ').convert(zusammengefuehrt),
        'aktualisiertAm': DateTime.now().toIso8601String(),
        if (gruppe.name != null) 'name': gruppe.name,
      });

      spielService.lokaleTischeAusMergedAktualisieren(
        zusammengefuehrt,
        tischIds: tischIds,
      );
      letzterSync = DateTime.now();
    } catch (e) {
      letzterFehler = e.toString();
      debugPrint('Upload fehlgeschlagen: $e');
    } finally {
      istAmSynchronisieren = false;
      notifyListeners();
    }
  }

  /// Verschiebt das automatische Löschen der Gruppe auf heute + 5 Jahre.
  Future<void> aktivitaetVermerken(Gruppe g) async {
    await FirebaseFirestore.instance
        .collection('gruppen')
        .doc(g.id)
        .set({
      'loeschenAm': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 5 * 365))),
    }, SetOptions(merge: true));
  }
}