import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;

  const UpdateInfo(this.version, this.downloadUrl);
}

/// Verifica su GitHub Releases se esiste una versione piu' recente dell'app.
/// Qualsiasi errore di rete/parsing viene ignorato (nessun popup).
class UpdateChecker {
  static const _apiUrl =
      'https://api.github.com/repos/Panko74/CWReader/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final resp = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'User-Agent': 'CWReader'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      if (tag == null) return null;

      final latest = _parseVersion(tag);
      final installed = _parseVersion(current);
      if (latest == null || installed == null) return null;
      if (_compare(latest, installed) <= 0) return null;

      var url = json['html_url'] as String? ?? '';
      for (final a in (json['assets'] as List<dynamic>?) ?? <dynamic>[]) {
        final map = a as Map<String, dynamic>;
        if (map['name'] == 'CWReader-release.apk') {
          url = map['browser_download_url'] as String? ?? url;
          break;
        }
      }
      if (url.isEmpty) return null;

      return UpdateInfo(tag.replaceFirst(RegExp(r'^v'), ''), url);
    } catch (_) {
      return null;
    }
  }

  static List<int>? _parseVersion(String v) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    if (m == null) return null;
    return [
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    ];
  }

  static int _compare(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}