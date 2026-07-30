import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String hinweis;
  final bool ignoriert;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.hinweis,
    this.ignoriert = false,
  });
}

class UpdateService {
  static const String _githubUser = 'kingapfelbaum-web';
  static const String _githubRepo = 'schafikopfi';
  static const String _ignoriertKey = 'ignorierte_version';

  static Future<UpdateInfo?> pruefeAufUpdate() async {
    try {
      http.Response? response;
      for (int versuch = 1; versuch <= 2; versuch++) {
        try {
          debugPrint('Update-Check Versuch $versuch...');
          response = await http
              .get(
            Uri.parse(
                'https://api.github.com/repos/$_githubUser/$_githubRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
              .timeout(const Duration(seconds: 10));
          break;
        } catch (e) {
          debugPrint('Versuch $versuch fehlgeschlagen: $e');
          if (versuch == 2) return null;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (response == null) return null;

      debugPrint('Update-Check Status: ${response.statusCode}');
      debugPrint('Update-Check Body: ${response.body}');

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final neueVersion =
      (data['tag_name'] as String).replaceFirst('v', '');
      debugPrint('Neue Version: $neueVersion');

      final assets = data['assets'] as List;
      debugPrint('Assets: ${assets.map((a) => a['name']).toList()}');

      final apkAsset = assets.firstWhere(
            (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );
      if (apkAsset == null) {
        debugPrint('Keine APK gefunden');
        return null;
      }
      final apkUrl = apkAsset['browser_download_url'] as String;
      debugPrint('APK URL: $apkUrl');

      final info = await PackageInfo.fromPlatform();
      final aktuelleVersion = info.version;
      debugPrint('Aktuelle Version: $aktuelleVersion');

      // Ignorierte Version prüfen
      final prefs = await SharedPreferences.getInstance();
      final ignoriertVersion = prefs.getString(_ignoriertKey);
      debugPrint('Ignorierte Version: $ignoriertVersion');

      // UpdateInfo erstellen mit ignoriert-Flag
      final updateInfo = UpdateInfo(
        version: neueVersion,
        url: apkUrl,
        hinweis: data['body'] as String? ?? '',
        ignoriert: ignoriertVersion == neueVersion,
      );

      if (_istNeuer(neueVersion, aktuelleVersion)) {
        debugPrint(updateInfo.ignoriert
            ? 'Update ignoriert'
            : 'Update verfügbar!');
        return updateInfo;
      }
      debugPrint('Kein Update nötig');
      return null;
    } catch (e) {
      debugPrint('Update-Check Fehler: $e');
      return null;
    }
  }

  static Future<void> versionsIgnorieren(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoriertKey, version);
  }

  static bool _istNeuer(String neu, String aktuell) {
    final n = neu.split('.').map(int.parse).toList();
    final a = aktuell.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final ni = i < n.length ? n[i] : 0;
      final ai = i < a.length ? a[i] : 0;
      if (ni > ai) return true;
      if (ni < ai) return false;
    }
    return false;
  }

  /// Lädt die APK herunter und öffnet den Android-Installationsdialog.
  /// Wirft eine Exception, wenn kein APK-Asset im Release vorhanden ist
  /// (dann sollte stattdessen [releaseUrl] im Browser geöffnet werden).
  static Future<void> downloadAndInstall(
      UpdateInfo info, {
        void Function(double? progress)? onProgress,
      }) async {

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.url));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download fehlgeschlagen (${streamedResponse.statusCode}).');
      }

      final totalBytes = streamedResponse.contentLength;
      var receivedBytes = 0;
      final bytes = <int>[];

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(totalBytes != null && totalBytes > 0 ? receivedBytes / totalBytes : null);
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/expense_tracker_update.apk');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } finally {
      SystemNavigator.pop();
      client.close();
    }
  }
}