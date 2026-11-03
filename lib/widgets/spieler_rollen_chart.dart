import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../services/spiel_service.dart';
import '../screens/tisch_detail_screen.dart';

enum RollenKategorie {
  ansager,
  mitspieler,
  nichtspieler,
  ohneSpieler,
  spielerpartei,
}

class RollenRundenMatch {
  final Tisch tisch;
  final Runde runde;
  final String rolle;
  final bool gewonnen;
  final double punkte;

  RollenRundenMatch({
    required this.tisch,
    required this.runde,
    required this.rolle,
    required this.gewonnen,
    required this.punkte,
  });
}

/// Statistische Rollenverteilung & Gewinnquoten (Ansager vs. Mitspieler vs. Nichtspieler)
class SpielerRollenStatistik {
  final String spielartName;
  final int anzahlGesamt;

  // Ansager (1. Gewählter in der Spielerpartei)
  final int anzahlAnsager;
  final int gewonneneAnsager;

  // Mitspieler (2. Gewählter in der Spielerpartei, z. B. Sauspiel-Partner)
  final int anzahlMitspieler;
  final int gewonneneMitspieler;

  // Nichtspieler / Gegenspieler
  final int anzahlNichtspieler;
  final int gewonneneNichtspieler;

  final int anzahlOhneSpieler;
  final int gewonneneOhneSpieler;

  SpielerRollenStatistik({
    required this.spielartName,
    required this.anzahlGesamt,
    required this.anzahlAnsager,
    required this.gewonneneAnsager,
    required this.anzahlMitspieler,
    required this.gewonneneMitspieler,
    required this.anzahlNichtspieler,
    required this.gewonneneNichtspieler,
    this.anzahlOhneSpieler = 0,
    this.gewonneneOhneSpieler = 0,
  });

  double get gewinnquoteOhneSpieler =>
      anzahlOhneSpieler == 0 ? 0.0 : gewonneneOhneSpieler / anzahlOhneSpieler;

  /// Prüft, ob eine Runde eine Spielart ohne Spieler ist (hatSpieler == false oder keine Partei)
  static bool _istOhneSpieler(Runde runde, List<Tisch> alleTische) {
    if (runde.spielerParteiIds.isEmpty) return true;
    for (final t in alleTische) {
      for (final s in t.spielarten) {
        if (s.name == runde.spielartName) {
          return !s.hatSpieler;
        }
      }
    }
    return false;
  }

  int get anzahlSpielerpartei => anzahlAnsager + anzahlMitspieler;
  int get gewonneneSpielerpartei => gewonneneAnsager + gewonneneMitspieler;

  double get gewinnquoteAnsager =>
      anzahlAnsager == 0 ? 0.0 : gewonneneAnsager / anzahlAnsager;

  double get gewinnquoteMitspieler =>
      anzahlMitspieler == 0 ? 0.0 : gewonneneMitspieler / anzahlMitspieler;

  double get gewinnquoteSpielerpartei =>
      anzahlSpielerpartei == 0 ? 0.0 : gewonneneSpielerpartei / anzahlSpielerpartei;

  double get gewinnquoteNichtspieler =>
      anzahlNichtspieler == 0 ? 0.0 : gewonneneNichtspieler / anzahlNichtspieler;

  double get ansagerAnteil =>
      anzahlGesamt == 0 ? 0.0 : anzahlAnsager / anzahlGesamt;

  double get mitspielerAnteil =>
      anzahlGesamt == 0 ? 0.0 : anzahlMitspieler / anzahlGesamt;

  double get spielerparteiAnteil =>
      anzahlGesamt == 0 ? 0.0 : anzahlSpielerpartei / anzahlGesamt;

  static SpielerRollenStatistik berechne({
    required List<Tisch> alleTische,
    required Spieler spieler,
    String? spielartName,
    int? maxRunden,
  }) {
    final gueltigeIds = _gueltigeRundenIds(
      alleTische: alleTische,
      spieler: spieler,
      maxRunden: maxRunden,
    );
    int anzahlGesamt = 0;
    int anzahlAnsager = 0;
    int gewonneneAnsager = 0;
    int anzahlMitspieler = 0;
    int gewonneneMitspieler = 0;
    int anzahlNichtspieler = 0;
    int gewonneneNichtspieler = 0;
    int anzahlOhneSpieler = 0;
    int gewonneneOhneSpieler = 0;

    for (final tisch in alleTische) {
      if (!tisch.spieler.contains(spieler)) continue;
      for (final runde in tisch.runden) {
        if (gueltigeIds != null && !gueltigeIds.contains(runde.id)) continue;
        if (spielartName != null && runde.spielartName != spielartName) continue;
        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue;

        anzahlGesamt++;
        final istOhneSp = _istOhneSpieler(runde, alleTische);

        if (istOhneSp) {
          anzahlOhneSpieler++;
          if (!runde.unentschieden && punkte > 0) {
            gewonneneOhneSpieler++;
          }
        } else {
          final istPartei = runde.spielerParteiIds.contains(spieler.id);
          if (istPartei) {
            final istAnsager = runde.spielerParteiIds.isNotEmpty &&
                runde.spielerParteiIds.first == spieler.id;
            if (istAnsager) {
              anzahlAnsager++;
              if (!runde.unentschieden && punkte > 0) {
                gewonneneAnsager++;
              }
            } else {
              anzahlMitspieler++;
              if (!runde.unentschieden && punkte > 0) {
                gewonneneMitspieler++;
              }
            }
          } else {
            anzahlNichtspieler++;
            if (!runde.unentschieden && punkte > 0) {
              gewonneneNichtspieler++;
            }
          }
        }
      }
    }

    return SpielerRollenStatistik(
      spielartName: spielartName ?? 'Alle Spielarten',
      anzahlGesamt: anzahlGesamt,
      anzahlAnsager: anzahlAnsager,
      gewonneneAnsager: gewonneneAnsager,
      anzahlMitspieler: anzahlMitspieler,
      gewonneneMitspieler: gewonneneMitspieler,
      anzahlNichtspieler: anzahlNichtspieler,
      gewonneneNichtspieler: gewonneneNichtspieler,
      anzahlOhneSpieler: anzahlOhneSpieler,
      gewonneneOhneSpieler: gewonneneOhneSpieler,
    );
  }

  static Map<String, SpielerRollenStatistik> berechneProSpielart({
    required List<Tisch> alleTische,
    required Spieler spieler,
    int? maxRunden,
  }) {
    final gueltigeIds = _gueltigeRundenIds(
      alleTische: alleTische,
      spieler: spieler,
      maxRunden: maxRunden,
    );
    final Map<String, _RollenCounter> counters = {};

    for (final tisch in alleTische) {
      if (!tisch.spieler.contains(spieler)) continue;
      for (final runde in tisch.runden) {
        if (gueltigeIds != null && !gueltigeIds.contains(runde.id)) continue;
        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue;

        final c = counters.putIfAbsent(
          runde.spielartName,
              () => _RollenCounter(spielartName: runde.spielartName),
        );

        c.anzahlGesamt++;
        final istOhneSp = _istOhneSpieler(runde, alleTische);
        if (istOhneSp) {
          c.anzahlOhneSpieler++;
          if (!runde.unentschieden && punkte > 0) {
            c.gewonneneOhneSpieler++;
          }
        } else {
          final istPartei = runde.spielerParteiIds.contains(spieler.id);
          if (istPartei) {
            final istAnsager = runde.spielerParteiIds.isNotEmpty &&
                runde.spielerParteiIds.first == spieler.id;
            if (istAnsager) {
              c.anzahlAnsager++;
              if (!runde.unentschieden && punkte > 0) {
                c.gewonneneAnsager++;
              }
            } else {
              c.anzahlMitspieler++;
              if (!runde.unentschieden && punkte > 0) {
                c.gewonneneMitspieler++;
              }
            }
          } else {
            c.anzahlNichtspieler++;
            if (!runde.unentschieden && punkte > 0) {
              c.gewonneneNichtspieler++;
            }
          }
        }
      }
    }

    return counters.map(
          (k, v) => MapEntry(
        k,
        SpielerRollenStatistik(
          spielartName: v.spielartName,
          anzahlGesamt: v.anzahlGesamt,
          anzahlAnsager: v.anzahlAnsager,
          gewonneneAnsager: v.gewonneneAnsager,
          anzahlMitspieler: v.anzahlMitspieler,
          gewonneneMitspieler: v.gewonneneMitspieler,
          anzahlNichtspieler: v.anzahlNichtspieler,
          gewonneneNichtspieler: v.gewonneneNichtspieler,
        ),
      ),
    );
  }

  static List<RollenRundenMatch> rundenFuerKategorie({
    required List<Tisch> alleTische,
    required Spieler spieler,
    required RollenKategorie kategorie,
    String? spielartName,
    int? maxRunden,
  }) {
    final gueltigeIds = _gueltigeRundenIds(
      alleTische: alleTische,
      spieler: spieler,
      maxRunden: maxRunden,
    );
    final treffer = <RollenRundenMatch>[];

    for (final tisch in alleTische) {
      if (!tisch.spieler.contains(spieler)) continue;
      for (final runde in tisch.runden) {
        if (gueltigeIds != null && !gueltigeIds.contains(runde.id)) continue;
        if (spielartName != null &&
            spielartName != 'Alle (Gesamt)' &&
            spielartName != 'Alle (Vergleich)' &&
            runde.spielartName != spielartName) {
          continue;
        }

        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue;

        final istPartei = runde.spielerParteiIds.contains(spieler.id);
        final istAnsager = istPartei &&
            runde.spielerParteiIds.isNotEmpty &&
            runde.spielerParteiIds.first == spieler.id;
        final istMitspieler = istPartei && !istAnsager;
        final istOhneSpieler = _istOhneSpieler(runde, alleTische);


        bool passt = false;
        String rolleName = '';

        switch (kategorie) {
          case RollenKategorie.ansager:
            if (istAnsager) {
              passt = true;
              rolleName = 'Ansager';
            }
            break;
          case RollenKategorie.mitspieler:
            if (istMitspieler) {
              passt = true;
              rolleName = 'Mitspieler';
            }
            break;
          case RollenKategorie.nichtspieler:
            if (!istPartei) {
              passt = true;
              rolleName = 'Gegenspieler';
            }
            break;
          case RollenKategorie.ohneSpieler:
            if (istOhneSpieler) {
              passt = true;
              rolleName = 'Ohne Spieler';
            }
            break;
          case RollenKategorie.spielerpartei:
            if (istPartei) {
              passt = true;
              rolleName = istAnsager ? 'Ansager' : 'Mitspieler';
            }
            break;
        }

        if (passt) {
          treffer.add(RollenRundenMatch(
            tisch: tisch,
            runde: runde,
            rolle: rolleName,
            gewonnen: !runde.unentschieden && punkte > 0,
            punkte: punkte,
          ));
        }
      }
    }

    treffer.sort((a, b) => b.runde.zeitpunkt.compareTo(a.runde.zeitpunkt));
    return treffer;
  }

  static Set<String>? _gueltigeRundenIds({
    required List<Tisch> alleTische,
    required Spieler spieler,
    int? maxRunden,
  }) {
    if (maxRunden == null) return null;

    final alleEintraege = <({DateTime zeitpunkt, String id})>[];
    for (final tisch in alleTische) {
      if (!tisch.spieler.contains(spieler)) continue;
      for (final runde in tisch.runden) {
        if (runde.punkteProSpieler.containsKey(spieler.id)) {
          alleEintraege.add((zeitpunkt: runde.zeitpunkt, id: runde.id));
        }
      }
    }
    if (alleEintraege.length <= maxRunden) return null;

    alleEintraege.sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    final relevante = alleEintraege.sublist(alleEintraege.length - maxRunden);
    return relevante.map((e) => e.id).toSet();
  }
}

class _RollenCounter {
  final String spielartName;
  int anzahlGesamt = 0;
  int anzahlAnsager = 0;
  int gewonneneAnsager = 0;
  int anzahlMitspieler = 0;
  int gewonneneMitspieler = 0;
  int anzahlNichtspieler = 0;
  int gewonneneNichtspieler = 0;
  int anzahlOhneSpieler = 0;
  int gewonneneOhneSpieler = 0;


  _RollenCounter({required this.spielartName});
}

/// Diagramm-Widget zur Anzeige der Rollen-Statistik inklusive Ansager-/Mitspieler-Unterscheidung.
/// Tappen auf einen Balken oder eine Karte öffnet die Liste der entsprechenden Spiele.
class SpielerRollenChart extends StatefulWidget {
  final Spieler spieler;
  final String? festeSpielart;
  final int? zeitraum;

  const SpielerRollenChart({
    super.key,
    required this.spieler,
    this.festeSpielart,
    this.zeitraum,
  });

  @override
  State<SpielerRollenChart> createState() => _SpielerRollenChartState();
}

class _SpielerRollenChartState extends State<SpielerRollenChart> {
  static const String _modusGesamt = 'Alle (Gesamt)';
  static const String _modusVergleich = 'Alle (Vergleich)';

  late String _ausgewaehlterModus;

  @override
  void initState() {
    super.initState();
    _ausgewaehlterModus = widget.festeSpielart ?? _modusGesamt;
  }

  void _zeigeSpieleListe(
      BuildContext context,
      List<Tisch> alleTische,
      RollenKategorie kategorie,
      String titel, {
        String? spielartFilter,
      }) {
    final spiele = SpielerRollenStatistik.rundenFuerKategorie(
      alleTische: alleTische,
      spieler: widget.spieler,
      kategorie: kategorie,
      spielartName: spielartFilter ?? _ausgewaehlterModus,
      maxRunden: widget.zeitraum,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$titel (${spiele.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: spiele.isEmpty
                      ? const Center(
                    child: Text('Keine Spiele in dieser Kategorie vorhanden'),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    itemCount: spiele.length,
                    itemBuilder: (context, index) {
                      final match = spiele[index];
                      final runde = match.runde;
                      final tisch = match.tisch;

                      final datum =
                          '${runde.zeitpunkt.day.toString().padLeft(2, '0')}.${runde.zeitpunkt.month.toString().padLeft(2, '0')}.${runde.zeitpunkt.year}';

                      final vorzeichen = match.punkte > 0.005
                          ? '+'
                          : '';
                      final punkteText =
                          '$vorzeichen${match.punkte.toStringAsFixed(2)} €';

                      final parteiNamen = runde.spielerParteiIds
                          .map((id) => tisch.spieler
                          .firstWhere((s) => s.id == id,
                          orElse: () => Spieler(id: id, name: id))
                          .name)
                          .join(' & ');

                      return ListTile(
                        leading: Icon(
                          runde.unentschieden
                              ? Icons.remove_circle_outline
                              : match.gewonnen
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: runde.unentschieden
                              ? Colors.grey
                              : match.gewonnen
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text('${runde.spielartName} · $datum'),
                        subtitle: Text(
                          parteiNamen.isNotEmpty
                              ? 'Partei: $parteiNamen (${match.rolle})'
                              : 'Rolle: ${match.rolle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          punkteText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: match.punkte > 0.005
                                ? Colors.green
                                : match.punkte < -0.005
                                ? Colors.red
                                : null,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TischDetailScreen(tisch: tisch),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final alleTische = service.alleTische;

    final statsProSpielart = SpielerRollenStatistik.berechneProSpielart(
      alleTische: alleTische,
      spieler: widget.spieler,
      maxRunden: widget.zeitraum,
    );

    final spielartOptionen = [
      _modusGesamt,
      if (statsProSpielart.length > 1) _modusVergleich,
      ...statsProSpielart.keys,
    ];

    if (!spielartOptionen.contains(_ausgewaehlterModus) && widget.festeSpielart == null) {
      _ausgewaehlterModus = _modusGesamt;
    }

    final isVergleichMode = _ausgewaehlterModus == _modusVergleich && widget.festeSpielart == null;

    final aktuelleStat = isVergleichMode
        ? null
        : (_ausgewaehlterModus == _modusGesamt
        ? SpielerRollenStatistik.berechne(
      alleTische: alleTische,
      spieler: widget.spieler,
      maxRunden: widget.zeitraum,
    )
        : (statsProSpielart[_ausgewaehlterModus] ??
        SpielerRollenStatistik.berechne(
          alleTische: alleTische,
          spieler: widget.spieler,
          spielartName: _ausgewaehlterModus,
          maxRunden: widget.zeitraum,
        )));

    final farbeAnsager = Colors.green.shade700;
    final farbeMitspieler = Colors.teal.shade600;
    final farbeNichtspieler = Colors.blue.shade600;
    final farbeAnteil = Colors.orange.shade700;
    final farbeOhneSpieler = Colors.purple.shade600;

    final hatMitspielerSpiele = aktuelleStat != null && aktuelleStat.anzahlMitspieler > 0;
    final hatOhneSpielerSpiele = aktuelleStat != null && aktuelleStat.anzahlOhneSpieler > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Gewinnquote & Rollen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.festeSpielart == null && spielartOptionen.isNotEmpty)
                  DropdownButton<String>(
                    value: _ausgewaehlterModus,
                    isDense: true,
                    underline: const SizedBox(),
                    items: spielartOptionen.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(
                          opt,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _ausgewaehlterModus = val);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Legende
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _legendenEintrag(farbeAnsager, 'Siegquote (Ansager)'),
                if (hatMitspielerSpiele || isVergleichMode)
                  _legendenEintrag(farbeMitspieler, 'Siegquote (Mitspieler)'),
                _legendenEintrag(farbeNichtspieler, 'Siegquote (Gegensp.)'),
                if (hatOhneSpielerSpiele || isVergleichMode)
                  _legendenEintrag(farbeOhneSpieler, 'Siegquote (Ohne Sp.)'),
                _legendenEintrag(farbeAnteil, '% in Spielerpartei'),
              ],
            ),
            const SizedBox(height: 16),

            if (isVergleichMode) ...[
              SizedBox(
                height: 200,
                child: _VergleichsChartCanvas(
                  statsMap: statsProSpielart,
                  farbeAnsager: farbeAnsager,
                  farbeMitspieler: farbeMitspieler,
                  farbeNichtspieler: farbeNichtspieler,
                  farbeOhneSpieler: farbeOhneSpieler,
                  farbeAnteil: farbeAnteil,
                  onBarTap: (stat, kat) {
                    final titel = kat == RollenKategorie.ansager
                        ? 'Ansager (${stat.spielartName})'
                        : kat == RollenKategorie.mitspieler
                        ? 'Mitspieler (${stat.spielartName})'
                        : kat == RollenKategorie.nichtspieler
                        ? 'Gegenspieler (${stat.spielartName})'
                        : 'Spielerpartei (${stat.spielartName})';
                    _zeigeSpieleListe(
                      context,
                      alleTische,
                      kat,
                      titel,
                      spielartFilter: stat.spielartName,
                    );
                  },
                ),
              ),
            ] else if (aktuelleStat == null || aktuelleStat.anzahlGesamt == 0) ...[
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text('Noch keine Spiele für diese Auswahl vorhanden'),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 180,
                child: _EinzelRollenChartCanvas(
                  stat: aktuelleStat,
                  farbeAnsager: farbeAnsager,
                  farbeMitspieler: farbeMitspieler,
                  farbeNichtspieler: farbeNichtspieler,
                  farbeOhneSpieler: farbeOhneSpieler,
                  farbeAnteil: farbeAnteil,
                  onBarTap: (kat) {
                    final titel = kat == RollenKategorie.ansager
                        ? 'Spiele als Ansager'
                        : kat == RollenKategorie.mitspieler
                        ? 'Spiele als Mitspieler'
                        : kat == RollenKategorie.nichtspieler
                        ? 'Spiele als Gegenspieler'
                        : 'Spiele in der Spielerpartei';
                    _zeigeSpieleListe(context, alleTische, kat, titel);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // KPI-Karten (ebenfalls klickbar)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _kpiCard(
                    context,
                    'Als Ansager',
                    '${(aktuelleStat.gewinnquoteAnsager * 100).toStringAsFixed(0)}%',
                    '${aktuelleStat.gewonneneAnsager} / ${aktuelleStat.anzahlAnsager} gew.',
                    farbeAnsager,
                    onTap: () => _zeigeSpieleListe(
                      context,
                      alleTische,
                      RollenKategorie.ansager,
                      'Spiele als Ansager',
                    ),
                  ),
                  if (hatMitspielerSpiele)
                    _kpiCard(
                      context,
                      'Als Mitspieler',
                      '${(aktuelleStat.gewinnquoteMitspieler * 100).toStringAsFixed(0)}%',
                      '${aktuelleStat.gewonneneMitspieler} / ${aktuelleStat.anzahlMitspieler} gew.',
                      farbeMitspieler,
                      onTap: () => _zeigeSpieleListe(
                        context,
                        alleTische,
                        RollenKategorie.mitspieler,
                        'Spiele als Mitspieler',
                      ),
                    ),
                  _kpiCard(
                    context,
                    'Als Nichtspieler',
                    '${(aktuelleStat.gewinnquoteNichtspieler * 100).toStringAsFixed(0)}%',
                    '${aktuelleStat.gewonneneNichtspieler} / ${aktuelleStat.anzahlNichtspieler} gew.',
                    farbeNichtspieler,
                    onTap: () => _zeigeSpieleListe(
                      context,
                      alleTische,
                      RollenKategorie.nichtspieler,
                      'Spiele als Gegenspieler',
                    ),
                  ),
                  if (hatOhneSpielerSpiele)
                    _kpiCard(
                      context,
                      'Ohne Spieler',
                      '${(aktuelleStat.gewinnquoteOhneSpieler * 100).toStringAsFixed(0)}%',
                      '${aktuelleStat.gewonneneOhneSpieler} / ${aktuelleStat.anzahlOhneSpieler} gew.',
                      farbeOhneSpieler,
                      onTap: () => _zeigeSpieleListe(
                        context,
                        alleTische,
                        RollenKategorie.ohneSpieler,
                        'Spiele ohne Spieler',
                      ),
                    ),
                  _kpiCard(
                    context,
                    'Spielerpartei',
                    '${(aktuelleStat.spielerparteiAnteil * 100).toStringAsFixed(0)}%',
                    '${aktuelleStat.anzahlSpielerpartei} / ${aktuelleStat.anzahlGesamt} Spiele',
                    farbeAnteil,
                    onTap: () => _zeigeSpieleListe(
                      context,
                      alleTische,
                      RollenKategorie.spielerpartei,
                      'Spiele in der Spielerpartei',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendenEintrag(Color farbe, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _kpiCard(
      BuildContext context,
      String titel,
      String prozentText,
      String detailText,
      Color farbe, {
        VoidCallback? onTap,
      }) {
    final width = (MediaQuery.of(context).size.width - 72) / 2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width.clamp(110.0, 160.0),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: farbe.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              titel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              prozentText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: farbe,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    detailText,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 12, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EinzelRollenChartCanvas extends StatelessWidget {
  final SpielerRollenStatistik stat;
  final Color farbeAnsager;
  final Color farbeMitspieler;
  final Color farbeNichtspieler;
  final Color farbeOhneSpieler;
  final Color farbeAnteil;
  final ValueChanged<RollenKategorie> onBarTap;

  const _EinzelRollenChartCanvas({
    required this.stat,
    required this.farbeAnsager,
    required this.farbeMitspieler,
    required this.farbeNichtspieler,
    required this.farbeOhneSpieler,
    required this.farbeAnteil,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final textFarbe = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final gitterFarbe = textFarbe.withValues(alpha: 0.2);

    final zeigeMitspieler = stat.anzahlMitspieler > 0;
    final zeigeOhneSpieler = stat.anzahlOhneSpieler > 0;
    final kategorien = [
      RollenKategorie.ansager,
      if (zeigeMitspieler) RollenKategorie.mitspieler,
      RollenKategorie.nichtspieler,
      if (zeigeOhneSpieler) RollenKategorie.ohneSpieler,
      RollenKategorie.spielerpartei,
    ];

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text('100%', style: TextStyle(fontSize: 10)),
              Text('75%', style: TextStyle(fontSize: 10)),
              Text('50%', style: TextStyle(fontSize: 10)),
              Text('25%', style: TextStyle(fontSize: 10)),
              Text('0%', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final width = box.size.width - 44;
              if (width <= 0) return;
              final x = (details.localPosition.dx - 44).clamp(0.0, width);
              final index = (x / (width / kategorien.length)).floor().clamp(0, kategorien.length - 1);
              onBarTap(kategorien[index]);
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: _EinzelChartPainter(
                stat: stat,
                farbeAnsager: farbeAnsager,
                farbeMitspieler: farbeMitspieler,
                farbeNichtspieler: farbeNichtspieler,
                farbeOhneSpieler: farbeOhneSpieler,
                farbeAnteil: farbeAnteil,
                gitterFarbe: gitterFarbe,
                textFarbe: textFarbe,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EinzelChartPainter extends CustomPainter {
  final SpielerRollenStatistik stat;
  final Color farbeAnsager;
  final Color farbeMitspieler;
  final Color farbeNichtspieler;
  final Color farbeOhneSpieler;
  final Color farbeAnteil;
  final Color gitterFarbe;
  final Color textFarbe;

  _EinzelChartPainter({
    required this.stat,
    required this.farbeAnsager,
    required this.farbeMitspieler,
    required this.farbeNichtspieler,
    required this.farbeOhneSpieler,
    required this.farbeAnteil,
    required this.gitterFarbe,
    required this.textFarbe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 24;
    final chartWidth = size.width;

    final gridPaint = Paint()
      ..color = gitterFarbe
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final zeigeMitspieler = stat.anzahlMitspieler > 0;
    final zeigeOhneSpieler = stat.anzahlOhneSpieler > 0;


    final saeulen = [
      _SaeulenData(
        wert: stat.gewinnquoteAnsager,
        hatSpiele: stat.anzahlAnsager > 0,
        farbe: farbeAnsager,
      ),
      if (zeigeMitspieler)
        _SaeulenData(
          wert: stat.gewinnquoteMitspieler,
          hatSpiele: stat.anzahlMitspieler > 0,
          farbe: farbeMitspieler,
        ),
      _SaeulenData(
        wert: stat.gewinnquoteNichtspieler,
        hatSpiele: stat.anzahlNichtspieler > 0,
        farbe: farbeNichtspieler,
      ),
      if (zeigeOhneSpieler)
        _SaeulenData(
          wert: stat.gewinnquoteOhneSpieler,
          hatSpiele: stat.anzahlOhneSpieler > 0,
          farbe: farbeOhneSpieler,
        ),
      _SaeulenData(
        wert: stat.spielerparteiAnteil,
        hatSpiele: stat.anzahlGesamt > 0,
        farbe: farbeAnteil,
      ),
    ];

    final n = saeulen.length;
    final slotWidth = chartWidth / n;
    final saeuleWidth = (slotWidth * 0.45).clamp(14.0, 44.0);

    for (int i = 0; i < n; i++) {
      final data = saeulen[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final left = centerX - saeuleWidth / 2;

      final valHeight = chartHeight * data.wert.clamp(0.0, 1.0);
      final top = chartHeight - valHeight;

      if (data.hatSpiele && valHeight > 0) {
        final barPaint = Paint()..color = data.farbe;
        final rect = Rect.fromLTRB(left, top, left + saeuleWidth, chartHeight);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(rrect, barPaint);
      }

      final prozentText = data.hatSpiele
          ? '${(data.wert * 100).toStringAsFixed(0)}%'
          : '—';
      final tpVal = TextPainter(
        text: TextSpan(
          text: prozentText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: data.hatSpiele ? data.farbe : textFarbe.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tpVal.paint(
        canvas,
        Offset(centerX - tpVal.width / 2, (top - tpVal.height - 2).clamp(0.0, chartHeight - 14)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EinzelChartPainter oldDelegate) => true;
}

class _SaeulenData {
  final double wert;
  final bool hatSpiele;
  final Color farbe;

  _SaeulenData({
    required this.wert,
    required this.hatSpiele,
    required this.farbe,
  });
}

class _VergleichsChartCanvas extends StatelessWidget {
  final Map<String, SpielerRollenStatistik> statsMap;
  final Color farbeAnsager;
  final Color farbeMitspieler;
  final Color farbeNichtspieler;
  final Color farbeOhneSpieler;
  final Color farbeAnteil;
  final void Function(SpielerRollenStatistik stat, RollenKategorie kat) onBarTap;

  const _VergleichsChartCanvas({
    required this.statsMap,
    required this.farbeAnsager,
    required this.farbeMitspieler,
    required this.farbeNichtspieler,
    required this.farbeOhneSpieler,
    required this.farbeAnteil,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final textFarbe = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final gitterFarbe = textFarbe.withValues(alpha: 0.2);

    final statsList = statsMap.values.toList();

    return Row(
      children: [
        const SizedBox(
          width: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('100%', style: TextStyle(fontSize: 10)),
              Text('75%', style: TextStyle(fontSize: 10)),
              Text('50%', style: TextStyle(fontSize: 10)),
              Text('25%', style: TextStyle(fontSize: 10)),
              Text('0%', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = statsList.length * 90.0;
              final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final x = details.localPosition.dx.clamp(0.0, width);
                      final groupIndex = (x / (width / statsList.length)).floor().clamp(0, statsList.length - 1);
                      final stat = statsList[groupIndex];

                      final groupSlotWidth = width / statsList.length;
                      final localXInGroup = x - groupIndex * groupSlotWidth;
                      final ratio = localXInGroup / groupSlotWidth;

                      final kat = ratio < 0.25
                          ? RollenKategorie.ansager
                          : ratio < 0.5
                          ? (stat.anzahlMitspieler > 0 ? RollenKategorie.mitspieler : RollenKategorie.nichtspieler)
                          : ratio < 0.75
                          ? RollenKategorie.nichtspieler
                          : RollenKategorie.spielerpartei;

                      onBarTap(stat, kat);
                    },
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _VergleichsChartPainter(
                        statsList: statsList,
                        farbeAnsager: farbeAnsager,
                        farbeMitspieler: farbeMitspieler,
                        farbeNichtspieler: farbeNichtspieler,
                        farbeOhneSpieler: farbeOhneSpieler,
                        farbeAnteil: farbeAnteil,
                        gitterFarbe: gitterFarbe,
                        textFarbe: textFarbe,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VergleichsChartPainter extends CustomPainter {
  final List<SpielerRollenStatistik> statsList;
  final Color farbeAnsager;
  final Color farbeMitspieler;
  final Color farbeNichtspieler;
  final Color farbeOhneSpieler;
  final Color farbeAnteil;
  final Color gitterFarbe;
  final Color textFarbe;

  _VergleichsChartPainter({
    required this.statsList,
    required this.farbeAnsager,
    required this.farbeMitspieler,
    required this.farbeNichtspieler,
    required this.farbeOhneSpieler,
    required this.farbeAnteil,
    required this.gitterFarbe,
    required this.textFarbe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 24;
    final chartWidth = size.width;

    final gridPaint = Paint()
      ..color = gitterFarbe
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final n = statsList.length;
    if (n == 0) return;

    final groupSlotWidth = chartWidth / n;
    final barWidth = (groupSlotWidth * 0.18).clamp(5.0, 14.0);

    for (int i = 0; i < n; i++) {
      final stat = statsList[i];
      final groupCenterX = groupSlotWidth * i + groupSlotWidth / 2;

      final values = [
        _SubBar(wert: stat.gewinnquoteAnsager, hatSpiele: stat.anzahlAnsager > 0, farbe: farbeAnsager),
        if (stat.anzahlMitspieler > 0)
          _SubBar(wert: stat.gewinnquoteMitspieler, hatSpiele: true, farbe: farbeMitspieler),
        _SubBar(wert: stat.gewinnquoteNichtspieler, hatSpiele: stat.anzahlNichtspieler > 0, farbe: farbeNichtspieler),
        if (stat.anzahlOhneSpieler > 0)
          _SubBar(wert: stat.gewinnquoteOhneSpieler, hatSpiele: true, farbe: farbeOhneSpieler),
        _SubBar(wert: stat.spielerparteiAnteil, hatSpiele: stat.anzahlGesamt > 0, farbe: farbeAnteil),
      ];

      final totalBarSpan = values.length * barWidth + (values.length - 1) * 2.5;
      final startX = groupCenterX - totalBarSpan / 2;

      for (int j = 0; j < values.length; j++) {
        final barData = values[j];
        final left = startX + j * (barWidth + 2.5);
        final valHeight = chartHeight * barData.wert.clamp(0.0, 1.0);
        final top = chartHeight - valHeight;

        if (barData.hatSpiele && valHeight > 0) {
          final paint = Paint()..color = barData.farbe;
          final rect = Rect.fromLTRB(left, top, left + barWidth, chartHeight);
          final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
          canvas.drawRRect(rrect, paint);
        }
      }

      final tpLabel = TextPainter(
        text: TextSpan(
          text: stat.spielartName,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textFarbe),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: groupSlotWidth - 4);

      tpLabel.paint(
        canvas,
        Offset(groupCenterX - tpLabel.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VergleichsChartPainter oldDelegate) => true;
}

class _SubBar {
  final double wert;
  final bool hatSpiele;
  final Color farbe;

  _SubBar({required this.wert, required this.hatSpiele, required this.farbe});
}
