import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../models/tarif.dart';
import '../models/spielart.dart';

/// Ein bei einem "Hinzufügen"-Import erkannter Namenskonflikt: ein
/// importierter Spieler trägt denselben Namen wie ein bereits vorhandener.
class SpielerImportKonflikt {
  final String importierteId;
  final String name;
  final String vorhandeneId;

  SpielerImportKonflikt({
    required this.importierteId,
    required this.name,
    required this.vorhandeneId,
  });
}

/// Ein einzelner Datenpunkt für einen Zeitverlauf: nach einer bestimmten
/// Runde der kumulierte Punktestand (€) und die bis dahin erreichte
/// (rollierende) Gewinnquote.
class VerlaufsPunkt {
  final DateTime zeitpunkt;
  final int rundenNummer;
  final double kumulierterSaldo;
  final double kumulierteGewinnquote;
  final Runde? runde;

  VerlaufsPunkt({
    required this.zeitpunkt,
    required this.rundenNummer,
    required this.kumulierterSaldo,
    required this.kumulierteGewinnquote,
    this.runde,
  });
}

class SpielService extends ChangeNotifier {
  final _uuid = const Uuid();
  static const _storageKey = 'schafkopf_daten_v1';

  /// Globaler Spieler-Pool, damit man beim Anlegen eines Tisches
  /// bereits bekannte Spieler wiederverwenden kann statt Namen neu zu tippen.
  final List<Spieler> _allePlayerinnen = [];
  final List<Tisch> _tische = [];

  /// Editierbarer Katalog aller verfügbaren Spielarten.
  List<Spielart> _spielarten = standardSpielarten();

  /// Standard-Einstellungen für neue Tische.
  Tarif _standardTarif = Tarif();
  Set<String> _standardAusgewaehlteSpielartenIds =
      standardSpielarten().map((s) => s.id).toSet();

  bool _geladen = false;
  bool _speichernAktiv = false;

  List<Spieler> get allePlayerinnen => List.unmodifiable(_allePlayerinnen);
  List<Tisch> get aktiveTische =>
      _tische.where((t) => t.status == TischStatus.aktiv).toList();
  List<Tisch> get beendeteTische {
    final liste = _tische.where((t) => t.status == TischStatus.beendet).toList();
    liste.sort((a, b) {
      final datumA = a.beendetAm ?? a.erstelltAm;
      final datumB = b.beendetAm ?? b.erstelltAm;
      return datumB.compareTo(datumA); // neueste zuerst
    });
    return liste;
  }

  /// Alle Tische, unabhängig vom Status (z.B. für Spieler-Detailstatistiken).
  List<Tisch> get alleTische => List.unmodifiable(_tische);

  List<Spielart> get spielarten => List.unmodifiable(_spielarten);
  Tarif get standardTarif => _standardTarif;
  Set<String> get standardAusgewaehlteSpielartenIds =>
      Set.unmodifiable(_standardAusgewaehlteSpielartenIds);

  /// Jede Zustandsänderung (überall im Service via notifyListeners genutzt)
  /// löst automatisch ein Speichern auf dem Gerät aus.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _speichern();
  }

  // ---------- Persistenz & Export/Import (gemeinsame JSON-Basis) ----------

  Map<String, dynamic> _zustandAlsJson() => {
        'allePlayerinnen': _allePlayerinnen.map((p) => p.toJson()).toList(),
        'spielarten': _spielarten.map((s) => s.toJson()).toList(),
        'standardTarif': _standardTarif.toJson(),
        'standardAusgewaehlteSpielartenIds':
            _standardAusgewaehlteSpielartenIds.toList(),
        'tische': _tische.map((t) => t.toJson()).toList(),
      };

  void _zustandAusJson(Map<String, dynamic> json) {
    final geladenePlayerinnen = <Spieler>[];
    for (final p in (json['allePlayerinnen'] as List? ?? [])) {
      try {
        geladenePlayerinnen.add(Spieler.fromJson(p as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Spieler konnte nicht geladen werden: $e');
      }
    }
    _allePlayerinnen
      ..clear()
      ..addAll(geladenePlayerinnen);

    final geladeneSpielarten = <Spielart>[];
    for (final s in (json['spielarten'] as List? ?? [])) {
      try {
        geladeneSpielarten.add(Spielart.fromJson(s as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Spielart konnte nicht geladen werden: $e');
      }
    }
    _spielarten = geladeneSpielarten.isEmpty ? standardSpielarten() : geladeneSpielarten;

    try {
      _standardTarif =
          Tarif.fromJson(json['standardTarif'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Standard-Tarif konnte nicht geladen werden: $e');
      _standardTarif = Tarif();
    }

    try {
      _standardAusgewaehlteSpielartenIds =
      Set<String>.from(json['standardAusgewaehlteSpielartenIds'] as List? ?? []);
    } catch (e) {
      debugPrint('Standard-Auswahl konnte nicht geladen werden: $e');
      _standardAusgewaehlteSpielartenIds = _spielarten.map((s) => s.id).toSet();
    }

    final geladeneTische = <Tisch>[];
    for (final t in (json['tische'] as List? ?? [])) {
      try {
        geladeneTische.add(Tisch.fromJson(
          t as Map<String, dynamic>,
          allePlayerinnen: _allePlayerinnen,
          alleSpielarten: _spielarten,
        ));
      } catch (e) {
        debugPrint('Tisch konnte nicht geladen werden: $e');
      }
    }
    _tische
      ..clear()
      ..addAll(geladeneTische);
  }

  /// Lädt gespeicherte Daten vom Gerät. Muss einmalig beim App-Start
  /// aufgerufen werden (siehe main.dart), bevor die UI aufgebaut wird.
  Future<void> ladeDaten() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) {
        _geladen = true;
        return;
      }
      _zustandAusJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Fehler beim Laden der gespeicherten Daten: $e');
    } finally {
      _geladen = true;
    }
  }

  Future<void> _speichern() async {
    // Vor dem ersten ladeDaten() nicht speichern, sonst würde ein evtl.
    // vorhandener gespeicherter Stand versehentlich überschrieben.
    if (!_geladen || _speichernAktiv) return;
    _speichernAktiv = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_zustandAlsJson()));
    } catch (e) {
      debugPrint('Fehler beim Speichern der Daten: $e');
    } finally {
      _speichernAktiv = false;
    }
  }

  /// Ermittelt Namenskonflikte zwischen Spielern, die in den ausgewählten
  /// Remote-Tischen vorkommen, und bereits lokal vorhandenen Spielern mit
  /// gleichem Namen, aber anderer ID.
  List<SpielerImportKonflikt> remoteKonflikteErmitteln(
      Map<String, dynamic> json, {
        required Set<String> tischIds,
      }) {
    final relevanteSpielerIds = <String>{};
    for (final t in (json['tische'] as List? ?? [])) {
      final tischJson = t as Map<String, dynamic>;
      if (!tischIds.contains(tischJson['id'])) continue;
      relevanteSpielerIds
          .addAll(List<String>.from(tischJson['spielerIds'] as List? ?? []));
    }

    final konflikte = <SpielerImportKonflikt>[];
    for (final p in (json['allePlayerinnen'] as List? ?? [])) {
      try {
        final importiert = Spieler.fromJson(p as Map<String, dynamic>);
        if (!relevanteSpielerIds.contains(importiert.id)) continue;
        // Derselbe Spieler (gleiche ID) ist kein Konflikt, sondern schon
        // synchronisiert.
        if (_allePlayerinnen.any((s) => s.id == importiert.id)) continue;

        Spieler? vorhandener;
        for (final s in _allePlayerinnen) {
          if (s.name.toLowerCase() == importiert.name.toLowerCase()) {
            vorhandener = s;
            break;
          }
        }
        if (vorhandener != null) {
          konflikte.add(SpielerImportKonflikt(
            importierteId: importiert.id,
            name: importiert.name,
            vorhandeneId: vorhandener.id,
          ));
        }
      } catch (e) {
        debugPrint('Spieler bei Remote-Kollisionsprüfung übersprungen: $e');
      }
    }
    return konflikte;
  }

  /// Spielt nur die ausgewählten Tische (inkl. der dafür benötigten Spieler
  /// und Spielarten) aus einem Remote-Datensatz lokal ein.
  ///
  /// [spielerEntscheidungen]: Schlüssel ist die importierte Spieler-ID,
  /// Wert 'merge' führt mit dem gleichnamigen lokalen Spieler zusammen,
  /// jeder andere Wert (oder fehlender Eintrag bei echtem Konflikt) legt
  /// den Spieler neu an – bei einem Namenskonflikt automatisch umbenannt
  /// zu "Name (Gruppenname)".
  int serverDatenEinspielenAusgewaehlt(
      Map<String, dynamic> json, {
        required Set<String> tischIds,
        required Map<String, String> spielerEntscheidungen,
        Map<String, String> tischEntscheidungen = const {},
        String? gruppenName,
      }) {
    final idUmschreibungSpieler = <String, String>{};
    for (final p in (json['allePlayerinnen'] as List? ?? [])) {
      try {
        final importiert = Spieler.fromJson(p as Map<String, dynamic>);

        if (_allePlayerinnen.any((s) => s.id == importiert.id)) {
          idUmschreibungSpieler[importiert.id] = importiert.id;
          continue;
        }

        final entscheidung = spielerEntscheidungen[importiert.id];
        if (entscheidung == 'merge') {
          final ziel = _allePlayerinnen.firstWhere(
                (s) => s.name.toLowerCase() == importiert.name.toLowerCase(),
            orElse: () => importiert,
          );
          if (!_allePlayerinnen.contains(ziel)) _allePlayerinnen.add(ziel);
          idUmschreibungSpieler[importiert.id] = ziel.id;
        } else {
          final kollidiert = _allePlayerinnen.any(
                  (s) => s.name.toLowerCase() == importiert.name.toLowerCase());
          final neuerName = kollidiert && gruppenName != null
              ? '${importiert.name} ($gruppenName)'
              : importiert.name;
          final neu = Spieler(id: importiert.id, name: neuerName);
          _allePlayerinnen.add(neu);
          idUmschreibungSpieler[importiert.id] = neu.id;
        }
      } catch (e) {
        debugPrint('Spieler beim selektiven Sync übersprungen: $e');
      }
    }

    final idUmschreibungSpielart = <String, String>{};
    for (final s in (json['spielarten'] as List? ?? [])) {
      try {
        final importiert = Spielart.fromJson(s as Map<String, dynamic>);
        if (_spielarten.any((sa) => sa.id == importiert.id)) {
          idUmschreibungSpielart[importiert.id] = importiert.id;
          continue;
        }
        final vorhandene = _spielarten.firstWhere(
              (sa) => sa.name.toLowerCase() == importiert.name.toLowerCase(),
          orElse: () => importiert,
        );
        if (!_spielarten.contains(vorhandene)) _spielarten.add(vorhandene);
        idUmschreibungSpielart[importiert.id] = vorhandene.id;
      } catch (e) {
        debugPrint('Spielart beim selektiven Sync übersprungen: $e');
      }
    }

    var eingespielt = 0;
    for (final t in (json['tische'] as List? ?? [])) {
      final tischJson = Map<String, dynamic>.from(t as Map<String, dynamic>);
      final tischId = tischJson['id'] as String;
      if (!tischIds.contains(tischId)) continue;

      try {
        tischJson['spielerIds'] = List<String>.from(
            tischJson['spielerIds'] as List? ?? [])
            .map((id) => idUmschreibungSpieler[id] ?? id)
            .toList();
        tischJson['spielartenIds'] = List<String>.from(
            tischJson['spielartenIds'] as List? ?? [])
            .map((id) => idUmschreibungSpielart[id] ?? id)
            .toList();

        final urspruenglicheRunden =
        List<dynamic>.from(tischJson['runden'] as List? ?? []);
        tischJson['runden'] = urspruenglicheRunden.map((r) {
          final rundeJson =
          Map<String, dynamic>.from(r as Map<String, dynamic>);
          rundeJson['spielerParteiIds'] = List<String>.from(
              rundeJson['spielerParteiIds'] as List? ?? [])
              .map((id) => idUmschreibungSpieler[id] ?? id)
              .toList();
          rundeJson['gegenParteiIds'] = List<String>.from(
              rundeJson['gegenParteiIds'] as List? ?? [])
              .map((id) => idUmschreibungSpieler[id] ?? id)
              .toList();
          final urspruenglichePunkte = Map<String, dynamic>.from(
              rundeJson['punkteProSpieler'] as Map? ?? {});
          rundeJson['punkteProSpieler'] = {
            for (final eintrag in urspruenglichePunkte.entries)
              (idUmschreibungSpieler[eintrag.key] ?? eintrag.key):
              eintrag.value,
          };
          return rundeJson;
        }).toList();

        final tisch = Tisch.fromJson(
          tischJson,
          allePlayerinnen: _allePlayerinnen,
          alleSpielarten: _spielarten,
        );
        _tische.add(tisch);
        eingespielt += 1;
        final neuerTisch = Tisch.fromJson(
          tischJson,
          allePlayerinnen: _allePlayerinnen,
          alleSpielarten: _spielarten,
        );

        final lokalerIndex = _tische.indexWhere((tt) => tt.id == tischId);
        if (lokalerIndex == -1) {
          _tische.add(neuerTisch);
          eingespielt += 1;
        } else {
          final modus = tischEntscheidungen[tischId] ?? 'merge';
          if (modus == 'overwrite') {
            _tische[lokalerIndex] = neuerTisch;
            eingespielt += 1;
          } else {
            // 'merge': Fehlende Runden ergänzen & Status abgleichen
            final lokalerTisch = _tische[lokalerIndex];
            final vorhandeneRundenIds = lokalerTisch.runden.map((r) => r.id).toSet();

            final hatteLokaleExtras = lokalerTisch.runden.any(
                    (lr) => !neuerTisch.runden.any((rr) => rr.id == lr.id));

            for (final remoteRunde in neuerTisch.runden) {
              if (vorhandeneRundenIds.add(remoteRunde.id)) {
                lokalerTisch.runden.add(remoteRunde);
              }
            }
            lokalerTisch.runden.sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));

            if (neuerTisch.status == TischStatus.beendet) {
              lokalerTisch.status = TischStatus.beendet;
              lokalerTisch.beendetAm ??= neuerTisch.beendetAm ?? DateTime.now();
            }
            if (hatteLokaleExtras) {
              lokalerTisch.aktualisiertAm = DateTime.now();
            } else {
              lokalerTisch.aktualisiertAm = neuerTisch.aktualisiertAm;
            }
            eingespielt += 1;
          }
        }
      } catch (e) {
        debugPrint('Tisch beim selektiven Sync übersprungen: $e');
      }
    }

    notifyListeners();
    return eingespielt;
  }

  /// Exportiert die ausgewählten Tische inkl. aller Spieler, die dort
  /// mitgespielt haben, sowie nur der Spielarten, die an diesen Tischen
  /// tatsächlich freigeschaltet waren (nicht der komplette globale Katalog).
  String datenExportierenGefiltert({required Set<String> tischIds}) {
    final ausgewaehlteTische =
    _tische.where((t) => tischIds.contains(t.id)).toList();

    final spielerIdsGesamt = <String>{
      for (final t in ausgewaehlteTische) ...t.spieler.map((s) => s.id),
    };
    final ausgewaehltePlayerinnen =
    _allePlayerinnen.where((s) => spielerIdsGesamt.contains(s.id)).toList();

    final spielartIdsGesamt = <String>{
      for (final t in ausgewaehlteTische) ...t.spielarten.map((s) => s.id),
    };
    final ausgewaehlteSpielarten =
    _spielarten.where((s) => spielartIdsGesamt.contains(s.id)).toList();

    final json = {
      'allePlayerinnen': ausgewaehltePlayerinnen.map((p) => p.toJson()).toList(),
      'spielarten': ausgewaehlteSpielarten.map((s) => s.toJson()).toList(),
      'standardTarif': _standardTarif.toJson(),
      'standardAusgewaehlteSpielartenIds':
      _standardAusgewaehlteSpielartenIds.toList(),
      'tische': ausgewaehlteTische.map((t) => t.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Aktualisiert die lokalen Tische mit den zusammengeführten Daten aus einem Sync-Upload.
  void lokaleTischeAusMergedAktualisieren(
      Map<String, dynamic> mergedJson, {
        required Set<String> tischIds,
      }) {
    final tischeJson = mergedJson['tische'] as List? ?? [];
    var geaendert = false;

    for (final t in tischeJson) {
      final tMap = t as Map<String, dynamic>;
      final id = tMap['id'] as String;
      if (!tischIds.contains(id)) continue;

      final idx = _tische.indexWhere((tt) => tt.id == id);
      if (idx != -1) {
        try {
          final mergedTisch = Tisch.fromJson(
            tMap,
            allePlayerinnen: _allePlayerinnen,
            alleSpielarten: _spielarten,
          );
          _tische[idx] = mergedTisch;
          geaendert = true;
        } catch (e) {
          debugPrint('Fehler beim Aktualisieren des lokalen Tisches $id: $e');
        }
      }
    }

    if (geaendert) {
      notifyListeners();
    }
  }

  // ---------- Spieler ----------

  Spieler spielerAnlegen(String name) {
    final bereinigt = name.trim();
    final begrenzt =
    bereinigt.length > 20 ? bereinigt.substring(0, 20) : bereinigt;
    final vorhandener = _allePlayerinnen.firstWhere(
          (s) => s.name.toLowerCase() == begrenzt.toLowerCase(),
      orElse: () => Spieler(id: _uuid.v4(), name: begrenzt),
    );
    if (!_allePlayerinnen.contains(vorhandener)) {
      _allePlayerinnen.add(vorhandener);
      notifyListeners();
    }
    return vorhandener;
  }

  bool spielerKannGeloeschtWerden(Spieler spieler) => !_tische.any(
          (t) => t.status == TischStatus.aktiv && t.spieler.contains(spieler));

  void spielerLoeschen(Spieler spieler) {
    if (!spielerKannGeloeschtWerden(spieler)) return;
    _allePlayerinnen.remove(spieler);
    notifyListeners();
  }

  // ---------- Spielarten-Katalog ----------

  Spielart spielartHinzufuegen(
      String name,
      bool einzelspieler, {
        bool individuelleGewinner = false,
        int individuelleAnzahl = 0,
        bool eigeneBetraege = false,
        double siegBetrag = 0,
        double verlustBetrag = 0,
        bool hatSpieler = true,
      }) {
    final s = Spielart(
      id: _uuid.v4(),
      name: name,
      einzelspieler: einzelspieler,
      individuelleGewinner: individuelleGewinner,
      individuelleAnzahl: individuelleAnzahl,
      eigeneBetraege: eigeneBetraege,
      siegBetrag: siegBetrag,
      verlustBetrag: verlustBetrag,
      hatSpieler: hatSpieler,
    );
    _spielarten.add(s);
    _standardAusgewaehlteSpielartenIds.add(s.id);
    notifyListeners();
    return s;
  }

  void spielartAktualisieren(
      Spielart spielart,
      String name,
      bool einzelspieler, {
        bool individuelleGewinner = false,
        int individuelleAnzahl = 0,
        bool eigeneBetraege = false,
        double siegBetrag = 0,
        double verlustBetrag = 0,
        bool hatSpieler = true,
      }) {
    spielart.name = name;
    spielart.einzelspieler = einzelspieler;
    spielart.individuelleGewinner = individuelleGewinner;
    spielart.individuelleAnzahl = individuelleAnzahl;
    spielart.eigeneBetraege = eigeneBetraege;
    spielart.siegBetrag = siegBetrag;
    spielart.verlustBetrag = verlustBetrag;
    spielart.hatSpieler = hatSpieler;
    notifyListeners();
  }

  void spielartLoeschen(Spielart spielart) {
    _spielarten.remove(spielart);
    _standardAusgewaehlteSpielartenIds.remove(spielart.id);
    notifyListeners();
  }

  // ---------- Standard-Einstellungen ----------

  void standardTarifAendern(Tarif tarif) {
    _standardTarif = tarif;
    notifyListeners();
  }

  void standardAuswahlAendern(Set<String> spielartenIds) {
    _standardAusgewaehlteSpielartenIds = spielartenIds;
    notifyListeners();
  }

  // ---------- Tische ----------

  Tisch tischAnlegen(
    List<Spieler> spielerInReihenfolge, {
    Tarif? tarif,
    List<Spielart>? spielarten,
  }) {
    assert(spielerInReihenfolge.length >= 4,
        'Ein Tisch braucht mindestens vier Spieler');
    final tisch = Tisch(
      id: _uuid.v4(),
      erstelltAm: DateTime.now(),
      spieler: List.of(spielerInReihenfolge),
      tarif: tarif,
      spielarten: spielarten,
    );
    _tische.add(tisch);
    notifyListeners();
    return tisch;
  }

  void spielerZuTischHinzufuegen(Tisch tisch, Spieler spieler) {
    tisch.spielerHinzufuegen(spieler);
    notifyListeners();
  }

  bool spielerVonTischEntfernen(Tisch tisch, Spieler spieler) {
    final entfernt = tisch.spielerEntfernen(spieler);
    if (entfernt) notifyListeners();
    return entfernt;
  }

  void spielerAufPauseSetzen(Tisch tisch, Spieler spieler) {
    tisch.spielerAufPause(spieler);
    notifyListeners();
  }

  void spielerReaktivieren(Tisch tisch, Spieler spieler) {
    tisch.spielerReaktivieren(spieler);
    notifyListeners();
  }

  void spielerReihenfolgeAendern(Tisch tisch, int oldIndex, int newIndex) {
    tisch.spielerVerschieben(oldIndex, newIndex);
    notifyListeners();
  }

  void tarifAendern(Tisch tisch, Tarif tarif) {
    tisch.tarif = tarif;
    notifyListeners();
  }

  /// Ändert die für diesen Tisch freigeschalteten Spielarten nachträglich
  /// (z.B. wenn nach dem Erstellen noch eine Spielart ergänzt werden soll).
  void spielartenFuerTischAendern(Tisch tisch, List<Spielart> neueSpielarten) {
    tisch.spielarten
      ..clear()
      ..addAll(neueSpielarten);
    notifyListeners();
  }

  void solorundeUmschalten(Tisch tisch, bool aktiv) {
    tisch.solorundeAktiv = aktiv;
    notifyListeners();
  }

  void rundeHinzufuegen(Tisch tisch, Runde runde) {
    tisch.runden.add(runde);
    tisch.aktualisiertAm = DateTime.now();
    notifyListeners();
  }

  void rundeAktualisieren(Tisch tisch, Runde alteRunde, Runde neueRunde) {
    final index = tisch.runden.indexWhere((r) => r.id == alteRunde.id);
    if (index == -1) return;
    tisch.runden[index] = neueRunde;
    tisch.aktualisiertAm = DateTime.now();
    notifyListeners();
  }

  void rundeLoeschen(Tisch tisch, Runde runde) {
    tisch.runden.removeWhere((r) => r.id == runde.id);
    tisch.aktualisiertAm = DateTime.now();
    notifyListeners();
  }

  void tischBeenden(Tisch tisch) {
    tisch.beenden();
    notifyListeners();
  }

  void tischReaktivieren(Tisch tisch) {
    tisch.reaktivieren();
    notifyListeners();
  }

  void tischLoeschen(Tisch tisch) {
    _tische.remove(tisch);
    notifyListeners();
  }

  // ---------- Statistik ----------

  /// Aggregierte Statistik über alle (auch aktive) Tische, pro Spieler.
  Map<Spieler, SpielerStatistik> get statistikProSpieler {
    final Map<String, SpielerStatistik> stats = {};

    for (final tisch in _tische) {
      for (final spieler in tisch.spieler) {
        stats.putIfAbsent(
          spieler.id,
          () => SpielerStatistik(spieler: spieler),
        );
      }
      for (final runde in tisch.runden) {
        runde.punkteProSpieler.forEach((spielerId, punkte) {
          final spieler = tisch.spieler.firstWhere((s) => s.id == spielerId);
          final s = stats.putIfAbsent(
            spielerId,
            () => SpielerStatistik(spieler: spieler),
          );
          s.gesamtPunkte += punkte;
          s.anzahlRunden += 1;
          if (punkte > 0) s.gewonneneRunden += 1;
        });
      }
    }

    for (final tisch in _tische) {
      for (final spieler in tisch.spieler) {
        stats[spieler.id]?.anzahlTische += 1;
      }
    }

    return {for (final s in stats.values) s.spieler: s};
  }

  /// Alle Tische, an denen mindestens eine Runde der angegebenen Spielart
  /// gespielt wurde. Optional eingeschränkt auf einen bestimmten Spieler
  /// (dann nur Tische, an denen dieser Spieler an einer solchen Runde
  /// beteiligt war).
  List<Tisch> tischeFuerSpielart(String spielartName, {Spieler? spieler}) {
    final treffer = <Tisch>[];
    for (final tisch in _tische) {
      final hatRunde = tisch.runden.any((r) {
        if (r.spielartName != spielartName) return false;
        if (spieler == null) return true;
        return r.punkteProSpieler.containsKey(spieler.id);
      });
      if (hatRunde) treffer.add(tisch);
    }
    treffer.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));
    return treffer;
  }

  List<SpielartStatistik> get statistikProSpielart {
    final Map<String, SpielartStatistik> stats = {};

    for (final tisch in _tische) {
      for (final runde in tisch.runden) {
        final s = stats.putIfAbsent(
          runde.spielartName,
              () => SpielartStatistik(name: runde.spielartName),
        );
        s.anzahlRunden += 1;
        if (!runde.unentschieden && runde.gewonnen) {
          s.gewonneneRunden += 1;
        }
      }
    }

    final liste = stats.values.toList()
      ..sort((a, b) => b.anzahlRunden.compareTo(a.anzahlRunden));
    return liste;
  }

  /// Detaillierte Statistik für einen einzelnen Spieler, u.a. aufgeschlüsselt
  /// nach Spielart, sowie die Liste aller Tische, an denen er teilnahm.
  SpielerDetailStatistik detailStatistikFuer(Spieler spieler) {
    final proSpielart = <String, SpielartStatistik>{};
    double gesamtPunkte = 0;
    int anzahlRunden = 0;
    int gewonneneRunden = 0;
    int unentschiedenRunden = 0;
    final tischeDesSpielers = <Tisch>[];

    for (final tisch in _tische) {
      if (!tisch.spieler.contains(spieler)) continue;
      tischeDesSpielers.add(tisch);

      for (final runde in tisch.runden) {
        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue; // Spieler hat in dieser Runde ausgesetzt

        gesamtPunkte += punkte;
        anzahlRunden += 1;
        if (runde.unentschieden) {
          unentschiedenRunden += 1;
        } else if (punkte > 0) {
          gewonneneRunden += 1;
        }

        final sa = proSpielart.putIfAbsent(
          runde.spielartName,
          () => SpielartStatistik(name: runde.spielartName),
        );
        sa.anzahlRunden += 1;
        sa.gesamtPunkte += punkte;
        if (!runde.unentschieden && punkte > 0) sa.gewonneneRunden += 1;
      }
    }

    tischeDesSpielers.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

    return SpielerDetailStatistik(
      spieler: spieler,
      gesamtPunkte: gesamtPunkte,
      anzahlRunden: anzahlRunden,
      gewonneneRunden: gewonneneRunden,
      unentschiedenRunden: unentschiedenRunden,
      anzahlTische: tischeDesSpielers.length,
      proSpielart: proSpielart.values.toList()
        ..sort((a, b) => b.anzahlRunden.compareTo(a.anzahlRunden)),
      tische: tischeDesSpielers,
    );
  }

  /// Zeitverlauf (Saldo + Gewinnquote) für einen einzelnen Spieler,
  /// über alle Tische hinweg, chronologisch nach Rundenzeitpunkt sortiert.
  List<VerlaufsPunkt> verlaufFuerSpieler(Spieler spieler) {
    final eintraege = <_SpielerRundenEintrag>[];

    for (final tisch in _tische) {
      if (!tisch.spieler.contains(spieler)) continue;
      for (final runde in tisch.runden) {
        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue; // ausgesetzt
        eintraege.add(_SpielerRundenEintrag(runde: runde, punkte: punkte));
      }
    }

    eintraege.sort((a, b) => a.runde.zeitpunkt.compareTo(b.runde.zeitpunkt));

    final verlauf = <VerlaufsPunkt>[];
    double saldo = 0;
    int anzahl = 0;
    int gewonnen = 0;

    for (final e in eintraege) {
      saldo += e.punkte;
      anzahl += 1;
      if (e.punkte > 0) gewonnen += 1;
      verlauf.add(VerlaufsPunkt(
        zeitpunkt: e.runde.zeitpunkt,
        rundenNummer: anzahl,
        kumulierterSaldo: saldo,
        kumulierteGewinnquote: gewonnen / anzahl,
        runde: e.runde,
      ));
    }

    return verlauf;
  }

  /// Mehrlinien-Verlauf für einen Tisch: für jede Runde der kumulierte
  /// Saldo JEDES am Tisch sitzenden Spielers (chronologisch sortiert).
  List<TischVerlaufsPunkt> mehrlinienVerlaufFuerTisch(Tisch tisch) {
    final rundenSortiert = List.of(tisch.runden)
      ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));

    final laufenderSaldo = <String, double>{
      for (final s in tisch.spieler) s.id: 0,
    };

    final verlauf = <TischVerlaufsPunkt>[];
    var nummer = 0;
    for (final runde in rundenSortiert) {
      nummer += 1;
      runde.punkteProSpieler.forEach((spielerId, punkte) {
        laufenderSaldo[spielerId] = (laufenderSaldo[spielerId] ?? 0) + punkte;
      });
      verlauf.add(TischVerlaufsPunkt(
        runde: runde,
        rundenNummer: nummer,
        saldoProSpieler: Map.of(laufenderSaldo),
      ));
    }
    return verlauf;
  }
}

class _SpielerRundenEintrag {
  final Runde runde;
  final double punkte;
  _SpielerRundenEintrag({required this.runde, required this.punkte});
}

/// Ein einzelner Datenpunkt für den Mehrlinien-Verlauf eines Tisches:
/// der kumulierte Saldo (€) für jeden Spieler nach einer bestimmten Runde.
class TischVerlaufsPunkt {
  final Runde runde;
  final int rundenNummer;

  /// Kumulierter Saldo je Spieler-ID nach dieser Runde.
  final Map<String, double> saldoProSpieler;

  TischVerlaufsPunkt({
    required this.runde,
    required this.rundenNummer,
    required this.saldoProSpieler,
  });
}

class SpielerStatistik {
  final Spieler spieler;
  double gesamtPunkte = 0;
  int anzahlRunden = 0;
  int gewonneneRunden = 0;
  int anzahlTische = 0;

  SpielerStatistik({required this.spieler});

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}

/// Feingranulare Statistik einer einzelnen Spielart für einen Spieler.
class SpielartStatistik {
  final String name;
  int anzahlRunden = 0;
  int gewonneneRunden = 0;
  double gesamtPunkte = 0;

  SpielartStatistik({required this.name});

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}

/// Detaillierte Statistik für einen einzelnen Spieler (siehe SpielerDetailScreen).
class SpielerDetailStatistik {
  final Spieler spieler;
  final double gesamtPunkte;
  final int anzahlRunden;
  final int gewonneneRunden;
  final int unentschiedenRunden;
  final int anzahlTische;
  final List<SpielartStatistik> proSpielart;
  final List<Tisch> tische;

  SpielerDetailStatistik({
    required this.spieler,
    required this.gesamtPunkte,
    required this.anzahlRunden,
    required this.gewonneneRunden,
    required this.unentschiedenRunden,
    required this.anzahlTische,
    required this.proSpielart,
    required this.tische,
  });

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}

/// Führt zwei Export-JSON-Dokumente additiv zusammen: Spieler, Spielarten
/// und Tische aus [zusatz] werden zu [basis] hinzugefügt, sofern ihre ID
/// dort nicht schon vorhanden ist (kein Überschreiben bestehender Einträge).
Map<String, dynamic> zusammenfuehrenJsonDokumente(
    Map<String, dynamic> basis,
    Map<String, dynamic> zusatz, {
      Map<String, String> tischModi = const {},
    }) {
  final allePlayerinnen =
  List<dynamic>.from(basis['allePlayerinnen'] as List? ?? []);
  final spielarten = List<dynamic>.from(basis['spielarten'] as List? ?? []);
  final tische = List<dynamic>.from(basis['tische'] as List? ?? []);

  final playerIds = allePlayerinnen
      .map((p) => (p as Map<String, dynamic>)['id'] as String)
      .toSet();
  for (final p in (zusatz['allePlayerinnen'] as List? ?? [])) {
    final id = (p as Map<String, dynamic>)['id'] as String;
    if (playerIds.add(id)) allePlayerinnen.add(p);
  }

  final spielartIds = spielarten
      .map((s) => (s as Map<String, dynamic>)['id'] as String)
      .toSet();
  for (final s in (zusatz['spielarten'] as List? ?? [])) {
    final id = (s as Map<String, dynamic>)['id'] as String;
    if (spielartIds.add(id)) spielarten.add(s);
  }

  for (final t in (zusatz['tische'] as List? ?? [])) {
    final tMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
    final id = tMap['id'] as String;
    final existIndex =
    tische.indexWhere((b) => (b as Map<String, dynamic>)['id'] == id);

    if (existIndex == -1) {
      tische.add(tMap);
    } else {
      final modus = tischModi[id] ?? 'merge';
      if (modus == 'overwrite') {
        tische[existIndex] = tMap;
      } else {
        final basisTischMap =
        Map<String, dynamic>.from(tische[existIndex] as Map<String, dynamic>);
        final basisRunden =
        List<dynamic>.from(basisTischMap['runden'] as List? ?? []);
        final basisRundenIds = basisRunden
            .map((r) => (r as Map<String, dynamic>)['id'] as String)
            .toSet();

        final zusatzRunden = List<dynamic>.from(tMap['runden'] as List? ?? []);
        for (final r in zusatzRunden) {
          final rId = (r as Map<String, dynamic>)['id'] as String;
          if (basisRundenIds.add(rId)) {
            basisRunden.add(r);
          }
        }
        basisRunden.sort((a, b) {
          final zA = (a as Map<String, dynamic>)['zeitpunkt'] as String? ?? '';
          final zB = (b as Map<String, dynamic>)['zeitpunkt'] as String? ?? '';
          return zA.compareTo(zB);
        });
        basisTischMap['runden'] = basisRunden;

        if (tMap['status'] == 'beendet' ||
            basisTischMap['status'] == 'beendet') {
          basisTischMap['status'] = 'beendet';
          basisTischMap['beendetAm'] ??=
              tMap['beendetAm'] ?? DateTime.now().toIso8601String();
        }
        basisTischMap['aktualisiertAm'] = DateTime.now().toIso8601String();

        tische[existIndex] = basisTischMap;
      }
    }
  }

  return {
    'allePlayerinnen': allePlayerinnen,
    'spielarten': spielarten,
    'tische': tische,
  };
}
