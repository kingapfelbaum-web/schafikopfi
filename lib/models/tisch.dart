import 'package:flutter/foundation.dart';

import 'spieler.dart';
import 'runde.dart';
import 'tarif.dart';
import 'spielart.dart';

enum TischStatus { aktiv, beendet }

class Tisch {
  final String id;
  final DateTime erstelltAm;
  DateTime? beendetAm;
  TischStatus status;
  Tarif tarif;

  /// Die für diesen Tisch freigeschalteten Spielarten (Auswahl bei Erstellung).
  final List<Spielart> spielarten;

  /// Reihenfolge ist bewusst eine Liste (nicht Set) -> Sitzordnung bleibt erhalten.
  final List<Spieler> spieler;
  final List<Runde> runden;
  final Set<String> inaktiveSpielerIds;
  bool solorundeAktiv;

  Tisch({
    required this.id,
    required this.erstelltAm,
    required this.spieler,
    Tarif? tarif,
    List<Spielart>? spielarten,
    List<Runde>? runden,
    Set<String>? inaktiveSpielerIds,
    this.solorundeAktiv = false,
    this.status = TischStatus.aktiv,
    this.beendetAm,
  })  : runden = runden ?? [],
        tarif = tarif ?? Tarif(),
        spielarten = spielarten ?? standardSpielarten(),
        inaktiveSpielerIds = inaktiveSpielerIds ?? {};

  /// Aktueller Punktestand (in €) je Spieler-ID, summiert über alle Runden.
  Map<String, double> get punktestand {
    final result = <String, double>{for (final s in spieler) s.id: 0};
    for (final runde in runden) {
      runde.punkteProSpieler.forEach((spielerId, punkte) {
        result[spielerId] = (result[spielerId] ?? 0) + punkte;
      });
    }
    return result;
  }

  void spielerHinzufuegen(Spieler neuer) {
    if (!spieler.contains(neuer)) {
      spieler.add(neuer);
    }
  }

  bool spielerHatRunden(Spieler s) => runden.any((r) =>
  r.spielerParteiIds.contains(s.id) || r.gegenParteiIds.contains(s.id));

  bool spielerEntfernen(Spieler s) {
    if (spielerHatRunden(s)) return false;
    return spieler.remove(s);
  }

  bool spielerIstAktiv(Spieler s) => !inaktiveSpielerIds.contains(s.id);

  void spielerAufPause(Spieler s) => inaktiveSpielerIds.add(s.id);

  void spielerReaktivieren(Spieler s) => inaktiveSpielerIds.remove(s.id);

  void spielerVerschieben(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final s = spieler.removeAt(oldIndex);
    spieler.insert(newIndex, s);
  }

  void beenden() {
    status = TischStatus.beendet;
    beendetAm = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'erstelltAm': erstelltAm.toIso8601String(),
        'beendetAm': beendetAm?.toIso8601String(),
        'status': status.name,
        'tarif': tarif.toJson(),
        'spielerIds': spieler.map((s) => s.id).toList(),
        'spielartenIds': spielarten.map((s) => s.id).toList(),
        'runden': runden.map((r) => r.toJson()).toList(),
        'inaktiveSpielerIds': inaktiveSpielerIds.toList(),
        'solorundeAktiv': solorundeAktiv,
      };

  /// Löst spielerIds/spielartenIds gegen die übergebenen globalen Listen auf.
  /// Ist eine ID dort nicht (mehr) vorhanden (z.B. gelöschte Spielart),
  /// wird ein minimaler Platzhalter erzeugt, damit alte Runden lesbar bleiben.
  factory Tisch.fromJson(
      Map<String, dynamic> json, {
        required List<Spieler> allePlayerinnen,
        required List<Spielart> alleSpielarten,
      }) {
    final spielerIds = List<String>.from(json['spielerIds'] as List? ?? []);
    final spieler = spielerIds
        .map((id) => allePlayerinnen.firstWhere(
          (s) => s.id == id,
      orElse: () => Spieler(id: id, name: '(gelöschter Spieler)'),
    ))
        .toList();

    final spielartenIds =
    List<String>.from(json['spielartenIds'] as List? ?? []);
    final spielarten = spielartenIds
        .map((id) => alleSpielarten.firstWhere(
          (s) => s.id == id,
      orElse: () => Spielart(
          id: id, name: '(gelöschte Spielart)', einzelspieler: false),
    ))
        .toList();

    // Jede Runde einzeln parsen: eine defekte/inkompatible Runde soll nicht
    // den kompletten Tisch (inkl. aller anderen, gültigen Runden) verwerfen.
    final runden = <Runde>[];
    for (final r in (json['runden'] as List? ?? [])) {
      try {
        runden.add(Runde.fromJson(r as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Runde konnte nicht geladen werden: $e');
      }
    }

    // Robust gegen unterschiedliche Serialisierungsformen (z.B. reiner
    // Enum-Name "beendet" oder mit Präfix "TischStatus.beendet") und
    // Groß-/Kleinschreibung, damit ein beendeter Tisch nicht versehentlich
    // als "aktiv" importiert wird.
    TischStatus status = TischStatus.aktiv;
    final statusRaw = json['status'];
    if (statusRaw is String) {
      final bereinigt =
      statusRaw.contains('.') ? statusRaw.split('.').last : statusRaw;
      status = TischStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == bereinigt.toLowerCase(),
        orElse: () {
          debugPrint('Unbekannter Tisch-Status "$statusRaw", nehme "aktiv"');
          return TischStatus.aktiv;
        },
      );
    }

    Tarif tarif;
    try {
      tarif = Tarif.fromJson(json['tarif'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Tarif konnte nicht gelesen werden, nehme Standardwerte: $e');
      tarif = Tarif();
    }

    return Tisch(
      id: json['id'] as String,
      erstelltAm: DateTime.parse(json['erstelltAm'] as String),
      beendetAm: json['beendetAm'] == null
          ? null
          : DateTime.parse(json['beendetAm'] as String),
      status: status,
      tarif: tarif,
      spieler: spieler,
      spielarten: spielarten,
      runden: runden,
      inaktiveSpielerIds: Set<String>.from(json['inaktiveSpielerIds'] as List? ?? []),
      solorundeAktiv: json['solorundeAktiv'] as bool? ?? false,
    );
  }
}
