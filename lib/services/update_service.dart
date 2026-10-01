import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

const _currentVersion = '1.3.4';
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

  /// Downloads the installer to the system temp folder, reporting progress
  /// via [onProgress] (0.0–1.0). Returns the local path when done.
  static Future<String> downloadUpdate(
      String url, void Function(double) onProgress) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'UnifyNetMonitor/$_currentVersion');
    final res = await req.close().timeout(const Duration(seconds: 15));

    final total = res.contentLength; // -1 if unknown
    final dest = p.join(Directory.systemTemp.path,
        'UnifyNetMonitor_Update_${DateTime.now().millisecondsSinceEpoch}.exe');
    final file = File(dest);
    final sink = file.openWrite();

    int received = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.flush();
    await sink.close();
    return dest;
  }

  /// Launches the installer via VBScript + ShellExecute "runas".
  /// This avoids all Windows argument-quoting pitfalls (the cmd /c start
  /// approach re-escapes embedded quotes, appending a stray backslash to the
  /// path). VBScript string concatenation sidesteps the issue entirely, and
  /// wscript.exe runs detached so it survives after the app calls exit(0).
  static Future<void> runInstaller(String path) async {
    // Double backslashes for VBScript string literal
    final vbsPath = p.join(Directory.systemTemp.path,
        'unm_launch_${DateTime.now().millisecondsSinceEpoch}.vbs');
    // Build args as a separate VBScript variable to avoid any quote nesting
    final vbs = [
      'Dim exePath',
      'exePath = "$path"',
      'Dim oShell',
      'Set oShell = CreateObject("Shell.Application")',
      'oShell.ShellExecute exePath, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART", "", "runas", 1',
    ].join('\r\n');
    await File(vbsPath).writeAsString(vbs);
    await Process.start(
      'wscript.exe',
      ['//nologo', vbsPath],
      runInShell: false,
      mode: ProcessStartMode.detached,
    );
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
}
