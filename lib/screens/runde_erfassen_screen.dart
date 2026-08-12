import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../models/spielart.dart';
import '../services/spiel_service.dart';

class RundeErfassenScreen extends StatefulWidget {
  final Tisch tisch;
  final SpielService service;
  final Runde? bearbeiteRunde;

  const RundeErfassenScreen({
    super.key,
    required this.tisch,
    required this.service,
    this.bearbeiteRunde,
  });

  @override
  State<RundeErfassenScreen> createState() => _RundeErfassenScreenState();
}

class _RundeErfassenScreenState extends State<RundeErfassenScreen> {
  late Set<String> _aktiveSpielerIds;
  late Spielart _spielart;

  /// Bei klassischen Spielen: die Spielerpartei. Bei individuellen
  /// Gewinnern: die ausgewählten Gewinner (kann leer sein = unentschieden).
  final Set<String> _spielerParteiIds = {};

  int _anzahlLaufende = 0;
  bool _schneider = false;
  bool _schwarz = false;
  bool _tout = false;
  bool _gewonnen = true;
  int _multiplikator = 1;

  @override
  void initState() {
    super.initState();
    final bearbeitet = widget.bearbeiteRunde;

    if (bearbeitet != null) {
      _aktiveSpielerIds = {
        ...bearbeitet.spielerParteiIds,
        ...bearbeitet.gegenParteiIds,
      };
      // Die Spielart wird über den Namen im aktuellen Katalog gesucht (Snapshot-
      // Prinzip, siehe Runde-Modell). Ist sie nicht mehr vorhanden (gelöscht),
      // wird ein Platzhalter mit den ursprünglichen Eckdaten rekonstruiert.
      _spielart = widget.tisch.spielarten.firstWhere(
            (s) => s.name == bearbeitet.spielartName,
        orElse: () => Spielart(
          id: 'geloescht',
          name: bearbeitet.spielartName,
          einzelspieler: bearbeitet.spielartEinzelspieler,
          individuelleGewinner: bearbeitet.unentschieden,
        ),
      );
      _spielerParteiIds.addAll(bearbeitet.spielerParteiIds);
      _anzahlLaufende = bearbeitet.anzahlLaufende;
      _schneider = bearbeitet.schneider;
      _schwarz = bearbeitet.schwarz;
      _tout = bearbeitet.tout;
      _gewonnen = bearbeitet.gewonnen;
      _multiplikator = bearbeitet.multiplikator;
    } else {
      // Standardmäßig die ersten 4 Spieler der Tisch-Reihenfolge aktiv setzen.
      _aktiveSpielerIds = _naechsteAktiveSpieler();
      _spielart = widget.tisch.spielarten.first;
    }
  }

  /// Ermittelt die Standard-Auswahl der aktiven Spieler für die neue Runde:
  /// Gab es noch keine Runde, werden die ersten 4 Spieler der Sitzordnung
  /// genommen. Ansonsten rückt jeder Sitzplatz gegenüber der letzten Runde
  /// um genau eine Position weiter (reihum, entsprechend der Sitzordnung
  /// des Tisches) – wer zuletzt ausgesetzt hat, spielt so als erstes wieder mit.
  List<Spieler> get _verfuegbareSpieler =>
      widget.tisch.spieler.where(widget.tisch.spielerIstAktiv).toList();

  Set<String> _naechsteAktiveSpieler() {
    final spieler = _verfuegbareSpieler;
    final n = spieler.length;

    if (widget.tisch.runden.isEmpty || n <= 4) {
      return spieler.take(4).map((s) => s.id).toSet();
    }

    final letzteRunde = widget.tisch.runden.last;
    final letzteAktiveIds = {
      ...letzteRunde.spielerParteiIds,
      ...letzteRunde.gegenParteiIds,
    };

    final letzteAktiveIndizes = letzteAktiveIds
        .map((id) => spieler.indexWhere((s) => s.id == id))
        .where((index) => index != -1)
        .toList();

    // Nur sinnvoll rotierbar, wenn die Vorrunde exakt 4 (noch am Tisch
    // sitzende) aktive Spieler hatte – sonst auf die ersten 4 zurückfallen.
    if (letzteAktiveIndizes.length != 4) {
      return spieler.take(4).map((s) => s.id).toSet();
    }

    // Jede Sitzposition rückt um genau einen Platz weiter (reihum).
    final neueIndizes =
    letzteAktiveIndizes.map((index) => (index + 1) % n).toSet();

    return neueIndizes.map((index) => spieler[index].id).toSet();
  }
    List<Spieler> get _aktiveSpieler => widget.tisch.spieler
      .where((s) => _aktiveSpielerIds.contains(s.id))
      .toList();

  bool get _individuell => _spielart.individuelleGewinner;

  /// Bei fester individueller Anzahl (Ramsch: immer 1) ist die Auswahl exakt
  /// vorgegeben; bei flexibler Anzahl (0) sind 0-2 Spieler erlaubt.
  bool get _flexibleAnzahl => _individuell && _spielart.individuelleAnzahl == 0;

  int get _maxSpielerpartei => _individuell
      ? (_flexibleAnzahl ? 2 : _spielart.individuelleAnzahl)
      : _spielart.anzahlSpielerpartei;

  bool get _auswahlGueltig {
    if (_aktiveSpielerIds.length != 4) return false;
    if (_flexibleAnzahl) {
      return _spielerParteiIds.length <= 2 &&
          _spielerParteiIds.every(_aktiveSpielerIds.contains);
    }
    return _spielerParteiIds.length == _maxSpielerpartei &&
        _spielerParteiIds.every(_aktiveSpielerIds.contains);
  }

  /// Unentschieden ist nur bei flexibler Anzahl mit 0 ausgewählten Spielern
  /// möglich (z.B. individuelles Sonderspiel ohne Ramsch-artige Festlegung).
  bool get _unentschieden => _flexibleAnzahl && _spielerParteiIds.isEmpty;

  double get _vorschauSpielwert {
    if (_spielart.eigeneBetraege) {
      return (_gewonnen ? _spielart.siegBetrag : _spielart.verlustBetrag) *
          _multiplikator;
    }
    final tarif = widget.tisch.tarif;
    final grundpreis = tarif.grundpreis(_spielart.einzelspieler);
    final zuschlag =
        tarif.aufpreis * _anzahlLaufende + (_schneider ? tarif.aufpreis : 0)
            + (_schwarz ? tarif.aufpreis : 0)
            ;
    if (_tout) {
      return (grundpreis + zuschlag) * _multiplikator * 2;
    }
    return (grundpreis + zuschlag) * _multiplikator;
  }

  @override
  Widget build(BuildContext context) {
    final alleSpieler = _verfuegbareSpieler;
    final brauchtAuswahl = alleSpieler.length > 4;
    final spielarten = widget.tisch.spielarten;

    if (spielarten.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Runde erfassen')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Für diesen Tisch sind keine Spielarten freigeschaltet. '
              'Bitte beim Erstellen eines neuen Tisches mindestens eine Spielart auswählen.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.bearbeiteRunde == null
          ? 'Runde erfassen'
          : 'Runde bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (brauchtAuswahl) ...[
            _abschnittsTitel(context, 'Wer spielt mit? (genau 4)'),
            ...alleSpieler.map((s) => CheckboxListTile(
                  value: _aktiveSpielerIds.contains(s.id),
                  title: Text(s.name),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        if (_aktiveSpielerIds.length < 4) {
                          _aktiveSpielerIds.add(s.id);
                        }
                      } else {
                        _aktiveSpielerIds.remove(s.id);
                        _spielerParteiIds.remove(s.id);
                      }
                    });
                  },
                )),
            const SizedBox(height: 8),
          ],
          _abschnittsTitel(context, 'Spielart'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spielarten
                .map((s) => ChoiceChip(
                      label: Text(s.name),
                      selected: _spielart == s,
                      onSelected: (_) {
                        setState(() {
                          _spielart = s;
                          _spielerParteiIds.clear();
                        });
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _abschnittsTitel(
            context,
            _individuell
                ? 'Gewinner (${_spielerParteiIds.length}/2, 0 = unentschieden)'
                : 'Spielerpartei (${_spielerParteiIds.length}/$_maxSpielerpartei)',
          ),
          ..._aktiveSpieler.map((s) => CheckboxListTile(
                value: _spielerParteiIds.contains(s.id),
                title: Text(s.name),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      if (_spielerParteiIds.length < _maxSpielerpartei) {
                        _spielerParteiIds.add(s.id);
                      }
                    } else {
                      _spielerParteiIds.remove(s.id);
                    }
                  });
                },
              )),
          if (_individuell && _unentschieden)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Kein Gewinner ausgewählt → Runde gilt als unentschieden, es werden keine Punkte verteilt.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const Divider(height: 32),
          _abschnittsTitel(context, 'Details'),
          if (!_unentschieden)
            SwitchListTile(
              title: Text('Spielerpartei gewonnen'),
              value: _gewonnen,
              onChanged: (v) => setState(() => _gewonnen = v),
            ),
          Row(
            children: [
              const Expanded(child: Text('Laufende')),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _anzahlLaufende > 0
                    ? () => setState(() => _anzahlLaufende--)
                    : null,
              ),
              Text('$_anzahlLaufende',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _anzahlLaufende < 14
                    ? () => setState(() => _anzahlLaufende++)
                    : null,
              ),
            ],
          ),
          if (!_tout)
            SwitchListTile(
              title: const Text('Schneider'),
              value: _schneider,
              onChanged: (v) => setState(() => _schneider = v),
            ),
            if (_schneider)
              SwitchListTile(
                title: const Text('Schwarz'),
                value: _schwarz,
                onChanged: (v) => setState(() => _schwarz = v),
              ),
          SwitchListTile(
            title: Text('Tout'),
            value: _tout,
            onChanged: (v) => setState(() {
                _tout = v;
                if (v) {
                  _schwarz = false;
                  _schneider = false;
                }
              }
            ),
          ),
          Row(
            children: [
              const Expanded(
                  child: Text('Multiplikator (z.B. Kontra/Re, Tout)')),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _multiplikator > 1
                    ? () => setState(() => _multiplikator=_multiplikator~/2)
                    : null,
              ),
              Text('${_multiplikator}x',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _multiplikator=_multiplikator*2),
              ),
            ],
          ),
          const Divider(height: 32),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_unentschieden
                      ? 'Unentschieden'
                      : 'Spielwert'),
                  Text(
                    _unentschieden
                        ? '0,00 €'
                        : (_individuell && _spielerParteiIds.length == 1) || _maxSpielerpartei <2
                            ? '${_vorschauSpielwert.toStringAsFixed(2)} €/ ${(_vorschauSpielwert*3).toStringAsFixed(2)} €'
                            : '${_vorschauSpielwert.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
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
                child: FilledButton(
                  onPressed: _auswahlGueltig ? _speichern : null,
                  child: Text(widget.bearbeiteRunde == null ? 'Speichern' : 'Änderungen speichern'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _abschnittsTitel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  void _speichern() {
    final gegenParteiIds = _aktiveSpielerIds
        .where((id) => !_spielerParteiIds.contains(id))
        .toList();

    final runde = Runde.berechnet(
      id: widget.bearbeiteRunde?.id ?? const Uuid().v4(),
      zeitpunkt: widget.bearbeiteRunde?.zeitpunkt,
      tarif: widget.tisch.tarif,
      spielart: _spielart,
      spielerParteiIds: _spielerParteiIds.toList(),
      gegenParteiIds: gegenParteiIds,
      anzahlLaufende: _anzahlLaufende,
      schneider: _schneider,
      schwarz: _schwarz,
      solorunde: widget.bearbeiteRunde?.solorunde ?? widget.tisch.solorundeAktiv,
      tout: _tout,
      gewonnen: _gewonnen,
      unentschieden: _unentschieden,
      multiplikator: _multiplikator,
      spielwert: _vorschauSpielwert,
    );

    if (widget.bearbeiteRunde == null) {
      widget.service.rundeHinzufuegen(widget.tisch, runde);
    } else {
      widget.service
          .rundeAktualisieren(widget.tisch, widget.bearbeiteRunde!, runde);
    }
    Navigator.of(context).pop();
  }
}
