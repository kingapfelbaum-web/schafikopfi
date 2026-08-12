import 'tarif.dart';
import 'spielart.dart';

/// Eine einzelne gespielte Runde an einem Tisch.
/// Es spielen immer genau 4 der Tisch-Spieler mit, der Rest setzt aus.
class Runde {
  final String id;
  final DateTime zeitpunkt;

  /// Snapshot der Spielart zum Zeitpunkt der Eingabe (Name + Tarif-Typ).
  /// Bewusst kein Verweis auf den (editierbaren) Spielart-Katalog, damit
  /// spätere Änderungen/Löschungen im Katalog alte Runden nicht verändern.
  final String spielartName;
  final bool spielartEinzelspieler;

  /// Bei klassischen Spielen: die feste Spielerpartei (1 oder 2 Spieler).
  /// Bei Spielen mit individuellen Gewinnern (z.B. Ramsch): die Gewinner
  /// dieser Runde (0, 1 oder 2 Spieler; 0 = unentschieden).
  final List<String> spielerParteiIds;

  /// Die restlichen der 4 aktiven Spieler (Gegenpartei bzw. Verlierer).
  final List<String> gegenParteiIds;

  final int anzahlLaufende;
  final bool schneider;
  final bool schwarz;
  final bool solorunde;
  final bool tout;

  /// Bei klassischen Spielen: hat die Spielerpartei gewonnen?
  /// Bei individuellen Gewinnern: true, sofern nicht unentschieden.
  final bool gewonnen;

  /// true, wenn diese Runde unentschieden ausging (nur bei Spielarten mit
  /// individuellen Gewinnern möglich). In diesem Fall ist punkteProSpieler
  /// für alle beteiligten Spieler 0.
  final bool unentschieden;

  final int multiplikator;

  /// Der Betrag, den jeder einzelne Verlierer/Gegenspieler zahlt/erhält
  /// (Gewinner erhalten/zahlen ein Vielfaches davon, siehe Berechnung).
  final double spielwert;

  /// Punktedifferenz pro Spieler-ID (positiv = Gewinn, negativ = Verlust)
  final Map<String, double> punkteProSpieler;

  Runde({
    required this.id,
    required this.zeitpunkt,
    required this.spielartName,
    required this.spielartEinzelspieler,
    required this.spielerParteiIds,
    required this.gegenParteiIds,
    required this.anzahlLaufende,
    required this.schneider,
    this.schwarz = false,
    this.solorunde = false,
    this.tout = false,
    required this.gewonnen,
    this.unentschieden = false,
    required this.multiplikator,
    required this.spielwert,
    required this.punkteProSpieler,
  });

  /// Berechnet Spielwert und Punkteverteilung nach Schafkopf-Regeln:
  /// Der Grundpreis + Aufpreise ergeben den "Spielwert" je Verlierer.
  /// Ist die Gewinner-Gruppe kleiner als die Verlierer-Gruppe (z.B. Solo
  /// 1 vs 3), zahlt/kassiert jeder Gewinner ein entsprechendes Vielfaches.
  /// Bei unentschieden = true (nur bei individuellen Gewinnern möglich)
  /// wechselt kein Punkt den Besitzer.
  factory Runde.berechnet({
    required Tarif tarif,
    required Spielart spielart,
    required List<String> spielerParteiIds,
    required List<String> gegenParteiIds,
    required int anzahlLaufende,
    required bool schneider,
    bool schwarz = false,
    bool solorunde = false,
    bool tout = false,
    required bool gewonnen,
    bool unentschieden = false,
    required int multiplikator,
    required String id,
    DateTime? zeitpunkt,
    required double spielwert,
  }) {
        tarif.aufpreis * anzahlLaufende + (schneider ? tarif.aufpreis : 0)
        + (schwarz ? tarif.aufpreis : 0)
    ;

    final punkte = <String, double>{};

    if (unentschieden) {
      for (final spielerId in [...spielerParteiIds, ...gegenParteiIds]) {
        punkte[spielerId] = 0;
      }
    } else {
      final numDeclarers = spielerParteiIds.length;
      final numOpponents = gegenParteiIds.length;
      final faktorSpielerpartei =
      numDeclarers == 0 ? 0 : numOpponents / numDeclarers;

      for (final spielerId in gegenParteiIds) {
        punkte[spielerId] = gewonnen ? -spielwert : spielwert;
      }
      for (final spielerId in spielerParteiIds) {
        punkte[spielerId] = gewonnen
            ? spielwert * faktorSpielerpartei
            : -spielwert * faktorSpielerpartei;
      }
    }

    return Runde(
      id: id,
      zeitpunkt: zeitpunkt ?? DateTime.now(),
      spielartName: spielart.name,
      spielartEinzelspieler: spielart.einzelspieler,
      spielerParteiIds: spielerParteiIds,
      gegenParteiIds: gegenParteiIds,
      anzahlLaufende: anzahlLaufende,
      schneider: schneider,
      schwarz: schwarz,
      solorunde: solorunde,
      tout: tout,
      gewonnen: unentschieden ? false : gewonnen,
      unentschieden: unentschieden,
      multiplikator: multiplikator,
      spielwert: spielwert,
      punkteProSpieler: punkte,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'spielartName': spielartName,
        'spielartEinzelspieler': spielartEinzelspieler,
        'spielerParteiIds': spielerParteiIds,
        'gegenParteiIds': gegenParteiIds,
        'anzahlLaufende': anzahlLaufende,
        'schneider': schneider,
        'schwarz': schwarz,
        'solorunde': solorunde,
        'tout': tout,
        'gewonnen': gewonnen,
        'unentschieden': unentschieden,
        'multiplikator': multiplikator,
        'spielwert': spielwert,
        'punkteProSpieler': punkteProSpieler,
      };

  factory Runde.fromJson(Map<String, dynamic> json) => Runde(
    id: json['id'] as String? ?? '',
    zeitpunkt: json['zeitpunkt'] != null
        ? DateTime.tryParse(json['zeitpunkt'] as String) ?? DateTime.now()
        : DateTime.now(),
    spielartName: json['spielartName'] as String? ?? '(unbekannt)',
    spielartEinzelspieler: json['spielartEinzelspieler'] as bool? ?? false,
    spielerParteiIds:
    List<String>.from(json['spielerParteiIds'] as List? ?? []),
    gegenParteiIds:
    List<String>.from(json['gegenParteiIds'] as List? ?? []),
    anzahlLaufende: json['anzahlLaufende'] as int? ?? 0,
    schneider: json['schneider'] as bool? ?? false,
    schwarz: json['schwarz'] as bool? ?? false,
    solorunde: json['solorunde'] as bool? ?? false,
    tout: json['tout'] as bool? ?? false,
    gewonnen: json['gewonnen'] as bool? ?? true,
    unentschieden: json['unentschieden'] as bool? ?? false,
    multiplikator: json['multiplikator'] as int? ?? 1,
    spielwert: (json['spielwert'] as num?)?.toDouble() ?? 0,
    punkteProSpieler: json['punkteProSpieler'] != null
        ? Map<String, double>.from(
      (json['punkteProSpieler'] as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    )
        : <String, double>{},
  );
}
