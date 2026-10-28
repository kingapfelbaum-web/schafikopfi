import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class DownloadDialog extends StatefulWidget {
  final String url;
  final String version;

  const DownloadDialog({
    super.key,
    required this.url,
    required this.version,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _fortschritt = 0.0;
  bool _fehler = false;
  String _fehlerText = '';
  bool _fertig = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await client.send(request);
      final gesamtGroesse = response.contentLength ?? 0;

      final dir = await getTemporaryDirectory();
      final datei = File('${dir.path}/kniffel_update.apk');
      final sink = datei.openWrite();

      int geladenBytes = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        geladenBytes += chunk.length;
        if (gesamtGroesse > 0 && mounted) {
          setState(() =>
          _fortschritt = geladenBytes / gesamtGroesse);
        }
      }
      await sink.close();
      client.close();

      if (!mounted) return;
      setState(() => _fertig = true);

      // Kurz warten dann installieren
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);

      final result = await OpenFilex.open(datei.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler beim Öffnen: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fehler = true;
        _fehlerText = 'Download fehlgeschlagen:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_fertig
          ? '✅ Download abgeschlossen'
          : _fehler
          ? '❌ Fehler'
          : '⬇️ Update ${widget.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_fehler) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_fehlerText,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ] else if (_fertig) ...[
            const Icon(Icons.check_circle,
                color: Colors.green, size: 40),
            const SizedBox(height: 8),
            const Text('Installation wird gestartet...'),
          ] else ...[
            LinearProgressIndicator(
              value: _fortschritt > 0 ? _fortschritt : null,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              _fortschritt > 0
                  ? '${(_fortschritt * 100).toStringAsFixed(0)}% heruntergeladen'
                  : 'Verbindung wird hergestellt...',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
      actions: _fehler
          ? [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ]
          : [],
    );
  }
}