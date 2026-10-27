import '../models/tarif.dart';

/// Eine konfigurierbare Spielart (z.B. "Sauspiel", "Wenz", "Ramsch", ...).
/// Der Katalog ist vom Nutzer editierbar (siehe SpieleBearbeitenScreen).
final Tarif standardTarif = Tarif();

class Spielart {
  final String id;
  String name;

  /// true  = Grundpreis wird über den Solo-Tarif berechnet
  /// false = Grundpreis wird über den Sauspiel-Tarif berechnet
  bool einzelspieler;

  /// true  = Spezialspiel (z.B. Ramsch): die Gewinner werden bei jeder
  ///         Runde individuell ausgewählt (0, 1 oder 2 Spieler) statt
  ///         einer festen Partei-Größe. 0 Gewinner = Unentschieden.
  /// false = klassisches Spiel mit fester Spielerpartei
  ///         (1 Spieler bei Solo-Tarif, 2 Spieler bei Sauspiel-Tarif)
  ///         und einem Gewonnen/Verloren-Ergebnis.
  bool individuelleGewinner;

  /// Nur relevant, wenn individuelleGewinner == true:
  /// 0 = flexible Anzahl (0, 1 oder 2 Spieler; 0 = Unentschieden möglich)
  /// 1 = immer genau 1 Spieler (z.B. Ramsch)
  /// 2 = immer genau 2 Spieler
  int individuelleAnzahl;

  /// true = statt der normalen Tarif-Formel (Grundpreis + Aufpreise) werden
  /// feste, unterschiedliche Beträge für Sieg und Niederlage verwendet.
  bool eigeneBetraege;
  double siegBetrag;
  double verlustBetrag;
  bool hatSpieler;

  Spielart({
    required this.id,
    required this.name,
    required this.einzelspieler,
    this.individuelleGewinner = false,
    this.individuelleAnzahl = 0,
    this.eigeneBetraege = false,
    this.siegBetrag = 0,
    this.verlustBetrag = 0,
    this.hatSpieler = false,
  });

  int get anzahlSpielerpartei => einzelspieler ? 1 : 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'einzelspieler': einzelspieler,
        'individuelleGewinner': individuelleGewinner,
        'individuelleAnzahl': individuelleAnzahl,
        'eigeneBetraege': eigeneBetraege,
        'siegBetrag': siegBetrag,
        'verlustBetrag': verlustBetrag,
        'hatSpieler': hatSpieler,
      };

  factory Spielart.fromJson(Map<String, dynamic> json) => Spielart(
        id: json['id'] as String,
        name: json['name'] as String,
        einzelspieler: json['einzelspieler'] as bool,
        individuelleGewinner: json['individuelleGewinner'] as bool? ?? false,
        individuelleAnzahl: json['individuelleAnzahl'] as int? ?? 0,
        eigeneBetraege: json['eigeneBetraege'] as bool? ?? false,
        siegBetrag: (json['siegBetrag'] as num?)?.toDouble() ?? 0,
        verlustBetrag: (json['verlustBetrag'] as num?)?.toDouble() ?? 0,
        hatSpieler: json['hatSpieler'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Spielart && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Der Standard-Katalog, mit dem die App startet.
List<Spielart> standardSpielarten() => [
      Spielart(id: 'sauspiel', name: 'Sauspiel', einzelspieler: false, hatSpieler: true),
      Spielart(id: 'wenz', name: 'Wenz', einzelspieler: true, hatSpieler: true),
      Spielart(id: 'geier', name: 'Geier', einzelspieler: true, hatSpieler: true),
      Spielart(id: 'solo', name: 'Solo', einzelspieler: true, hatSpieler: true),
      Spielart(
        id: 'ramsch',
        name: 'Ramsch',
        einzelspieler: false,
        individuelleGewinner: true,
        individuelleAnzahl: 1,
        eigeneBetraege: true,
        siegBetrag: standardTarif.soloPreis,
        verlustBetrag: standardTarif.sauspielPreis,
      ),
    ];
