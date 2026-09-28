// lib/services/update_service.dart
import 'dart:convert';
import 'dart:io';

const _currentVersion = '1.0.0';
const _githubRepo = 'kiabeak-blip/unify-net-monitor';
const _releasesApiUrl =
    'https://api.github.com/repos/$_githubRepo/releases/latest';
const _releasesPageUrl =
    'https://github.com/$_githubRepo/releases/latest';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.downloadUrl,
  });
}

class UpdateService {
  static String get currentVersion => _currentVersion;

  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(_releasesApiUrl));
      req.headers.set('User-Agent', 'UnifyNetMonitor/$_currentVersion');
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return UpdateInfo(hasUpdate: false, latestVersion: _currentVersion,
            downloadUrl: _releasesPageUrl);
      }
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').replaceAll('v', '');
      final downloadUrl = _assetUrl(json) ?? _releasesPageUrl;
      final hasUpdate = _isNewer(tag, _currentVersion);
      return UpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: tag.isEmpty ? _currentVersion : tag,
          downloadUrl: downloadUrl);
    } catch (_) {
      return UpdateInfo(hasUpdate: false, latestVersion: _currentVersion,
          downloadUrl: _releasesPageUrl);
    }
  }

  static String? _assetUrl(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final a in assets) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.exe')) {
        return a['browser_download_url'] as String?;
      }
    }
    return null;
  }

  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }

  static Future<void> openDownloadPage(String url) async {
    await Process.start('cmd', ['/c', 'start', '', url]);
  }
}
