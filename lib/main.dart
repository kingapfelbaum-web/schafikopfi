import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/spiel_service.dart';
import 'screens/aktive_spiele_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/einstellungen_screen.dart';
import 'screens/neues_spiel_screen.dart';
import 'services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
        _zeigeUpdateDialog(info);
      }
    }
  }

  void _zeigeUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎲 Update verfügbar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${info.version} ist verfügbar.'),
            if (info.hinweis.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(info.hinweis,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await UpdateService.versionsIgnorieren(info.version);
              setState(() => _updateInfo = info);
              Navigator.pop(context);
            },
            child: const Text('Ignorieren'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uri = Uri.parse(info.url);
                await UpdateService.downloadAndInstall(info);
                await Future.delayed(const Duration(milliseconds: 500));
                SystemNavigator.pop(animated: false);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Download-Link konnte nicht geöffnet werden: $e')),
                );
              }
            },
            icon: const Icon(Icons.system_update),
            label: const Text('Installieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
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
            if (_updateInfo != null) _zeigeUpdateDialog(_updateInfo!);
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
