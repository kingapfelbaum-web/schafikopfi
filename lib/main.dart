import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/spiel_service.dart';
import 'screens/aktive_spiele_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/einstellungen_screen.dart';
import 'screens/neues_spiel_screen.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = SpielService();
  await service.ladeDaten();
  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  ).then((val) {
    runApp(SchafkopfApp(service: service));
  });
}

class SchafkopfApp extends StatelessWidget {
  final SpielService service;
  const SchafkopfApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: service,
      child: MaterialApp(
        title: 'Schafkopf',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade800),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.tealAccent.shade700,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _updatePruefen();
  }

  Future<void> _updatePruefen() async {
    debugPrint('Update-Check gestartet...');
    final info = await UpdateService.pruefeAufUpdate();
    debugPrint('UpdateInfo: ${info?.version ?? "null"}');
    if (info != null && mounted) {
      setState(() => _updateInfo = info);
      // Dialog nur zeigen wenn nicht ignoriert
      if (!info.ignoriert) {
        _showUpdateDialog(info, context);
      }
    }
  }

  void _showUpdateDialog(UpdateInfo info, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _UpdateDialog(
        info: info,
        onIgnore: () {
          debugPrint('Update ignoriert');
          UpdateService.versionsIgnorieren(info.version);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          AktiveSpieleScreen(updateInfo: _updateInfo, onUpdateTap: () {
            if (_updateInfo != null) _showUpdateDialog(_updateInfo!, context);
          }),
          const StatistikScreen(),
          const EinstellungenScreen()
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_index == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Neues Spiel'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NeuesSpielScreen()),
                    ),
                  ),
                ),
              ),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.play_arrow), label: 'Aktive Spiele'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart), label: 'Statistik'),
                NavigationDestination(
                    icon: Icon(Icons.settings), label: 'Einstellungen'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final VoidCallback onIgnore;
  const _UpdateDialog({required this.info, required this.onIgnore});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _installing = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _progress = null;
      _error = null;
    });
    try {
      await UpdateService.downloadAndInstall(
        widget.info,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Installation fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_installing ? 'Update wird heruntergeladen' : 'Update verfügbar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_installing) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(
              _progress != null ? '${(_progress! * 100).toStringAsFixed(0)} %' : 'Lädt...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            Text('Version ${widget.info.version} steht auf GitHub bereit.'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (widget.info.hinweis.isNotEmpty && !_installing) ...[
            const SizedBox(height: 8),
            Text(widget.info.hinweis,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _installing ? null : widget.onIgnore,
          child: const Text('Ignorieren'),
        ),
        FilledButton(
          onPressed: _installing ? null : _install,
          child: _installing
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Jetzt installieren'),
        ),
      ],
    );
  }
}
