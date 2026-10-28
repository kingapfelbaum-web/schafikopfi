import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/sync_service.dart';
import 'services/spiel_service.dart';
import 'screens/aktive_spiele_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/einstellungen_screen.dart';
import 'screens/neues_spiel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final service = SpielService();
  await service.ladeDaten();

  final syncService = SyncService(service);
  await syncService.gruppenLaden();

  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  ).then((val) {
    runApp(SchafkopfApp(service: service, syncService: syncService));
  });
}

class SchafkopfApp extends StatelessWidget {
  final SpielService service;
  final SyncService syncService;
  const SchafkopfApp({super.key, required this.service, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: service),
        ChangeNotifierProvider.value(value: syncService),
      ],
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

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AktiveSpieleScreen(),
          StatistikScreen(),
          EinstellungenScreen()
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

