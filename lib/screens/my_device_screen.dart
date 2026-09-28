// lib/screens/my_device_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyDeviceScreen extends StatefulWidget {
  const MyDeviceScreen({super.key});

  @override
  State<MyDeviceScreen> createState() => _MyDeviceScreenState();
}

class _MyDeviceScreenState extends State<MyDeviceScreen> {
  bool _loading = true;
  _DeviceInfo? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await _DeviceInfo.fetch();
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Device'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF00D4FF)))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _InfoView(info: _info!),
    );
  }
}

// ─── Info View ─────────────────────────────────────────────────────────────

class _InfoView extends StatelessWidget {
  const _InfoView({required this.info});
  final _DeviceInfo info;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // ── Network / IP ──────────────────────────────
        _Section(icon: Icons.language, color: const Color(0xFF00D4FF),
            title: 'Network Identity', children: [
          _Row('Hostname', info.hostname),
          _Row('Local IP', info.localIP),
          _Row('Public IP', info.publicIP ?? 'Fetching…'),
          _Row('Subnet Mask', info.subnetMask),
          _Row('Default Gateway', info.gateway),
          _Row('MAC Address', info.macAddress),
          _Row('DNS Servers', info.dnsServers),
        ]),

        // ── WiFi ──────────────────────────────────────
        if (info.wifi != null)
          _Section(icon: Icons.wifi, color: const Color(0xFF00FF88),
              title: 'WiFi', children: [
            _Row('SSID', info.wifi!.ssid),
            _Row('Signal', '${info.wifi!.signalPercent}%  ${_signalBar(info.wifi!.signalPercent)}'),
            _Row('Radio Type', info.wifi!.radioType),
            _Row('Authentication', info.wifi!.auth),
            _Row('Channel', info.wifi!.channel),
            _Row('Receive Rate', info.wifi!.rxRate),
            _Row('Transmit Rate', info.wifi!.txRate),
            _Row('BSSID', info.wifi!.bssid),
          ])
        else
          _Section(icon: Icons.wifi_off, color: Colors.white38,
              title: 'WiFi', children: [
            const _Row('Status', 'Not connected / Ethernet only'),
          ]),

        // ── System ────────────────────────────────────
        _Section(icon: Icons.computer, color: const Color(0xFFFFAA00),
            title: 'System', children: [
          _Row('Computer Name', info.computerName),
          _Row('OS', info.osName),
          _Row('OS Version', info.osVersion),
          _Row('Architecture', info.arch),
          _Row('Uptime', info.uptime),
        ]),

        // ── Hardware ──────────────────────────────────
        _Section(icon: Icons.memory, color: const Color(0xFFFF88AA),
            title: 'Hardware', children: [
          _Row('CPU', info.cpu),
          _Row('CPU Cores', info.cpuCores),
          _Row('RAM Total', info.ramTotal),
          _Row('RAM Free', info.ramFree),
          _Row('GPU', info.gpu),
        ]),

        // ── Profile ───────────────────────────────────
        _Section(icon: Icons.person_outline, color: const Color(0xFFAA88FF),
            title: 'User Profile', children: [
          _Row('Username', info.username),
          _Row('Domain', info.domain),
          _Row('User Profile Dir', info.profileDir),
          _Row('System Drive', info.systemDrive),
        ]),
      ],
    );
  }

  String _signalBar(int percent) {
    if (percent >= 80) return '▂▄▆█ Excellent';
    if (percent >= 60) return '▂▄▆░ Good';
    if (percent >= 40) return '▂▄░░ Fair';
    if (percent >= 20) return '▂░░░ Poor';
    return '░░░░ Very Poor';
  }
}

// ─── Section + Row ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.color,
    required this.title, required this.children});
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
        color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.12)))),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(children: children),
      ),
    ]),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 140, child: Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 12))),
      Expanded(child: GestureDetector(
        onLongPress: () {
          if (value == null || value!.isEmpty || value == '—') return;
          Clipboard.setData(ClipboardData(text: value!));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Copied: $value'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating));
        },
        child: Text(value?.isNotEmpty == true ? value! : '—',
            style: const TextStyle(color: Colors.white,
                fontSize: 12, fontFamily: 'monospace')),
      )),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4466), size: 48),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: const Color(0xFF0A0E1A)),
      ),
    ]),
  );
}

// ─── Data model & fetcher ──────────────────────────────────────────────────

class _WifiInfo {
  final String ssid, bssid, radioType, auth, channel, rxRate, txRate;
  final int signalPercent;

  const _WifiInfo({required this.ssid, required this.bssid,
    required this.radioType, required this.auth, required this.channel,
    required this.rxRate, required this.txRate, required this.signalPercent});
}

class _DeviceInfo {
  // Network
  final String hostname, localIP, subnetMask, gateway, macAddress, dnsServers;
  final String? publicIP;
  // WiFi
  final _WifiInfo? wifi;
  // System
  final String computerName, osName, osVersion, arch, uptime;
  // Hardware
  final String cpu, cpuCores, ramTotal, ramFree, gpu;
  // Profile
  final String username, domain, profileDir, systemDrive;

  const _DeviceInfo({
    required this.hostname, required this.localIP, required this.subnetMask,
    required this.gateway, required this.macAddress, required this.dnsServers,
    this.publicIP,
    this.wifi,
    required this.computerName, required this.osName, required this.osVersion,
    required this.arch, required this.uptime,
    required this.cpu, required this.cpuCores,
    required this.ramTotal, required this.ramFree, required this.gpu,
    required this.username, required this.domain,
    required this.profileDir, required this.systemDrive,
  });

  static Future<_DeviceInfo> fetch() async {
    // Run all queries in parallel
    final results = await Future.wait([
      _ps(_networkScript),   // 0
      _ps(_systemScript),    // 1
      _ps(_hardwareScript),  // 2
      _ps(_profileScript),   // 3
      _getPublicIP(),        // 4
      _getWifi(),            // 5
    ]);

    final net = _parseKV(results[0] as String);
    final sys = _parseKV(results[1] as String);
    final hw  = _parseKV(results[2] as String);
    final prof = _parseKV(results[3] as String);
    final publicIP = results[4] as String?;
    final wifi = results[5] as _WifiInfo?;

    return _DeviceInfo(
      hostname:     net['Hostname'] ?? Platform.localHostname,
      localIP:      net['IPv4'] ?? '—',
      subnetMask:   net['SubnetMask'] ?? '—',
      gateway:      net['Gateway'] ?? '—',
      macAddress:   net['MAC'] ?? '—',
      dnsServers:   net['DNS'] ?? '—',
      publicIP:     publicIP,
      wifi:         wifi,
      computerName: sys['ComputerName'] ?? '—',
      osName:       sys['OS'] ?? '—',
      osVersion:    sys['OSVersion'] ?? '—',
      arch:         sys['Arch'] ?? '—',
      uptime:       sys['Uptime'] ?? '—',
      cpu:          hw['CPU'] ?? '—',
      cpuCores:     hw['Cores'] ?? '—',
      ramTotal:     hw['RAMTotal'] ?? '—',
      ramFree:      hw['RAMFree'] ?? '—',
      gpu:          hw['GPU'] ?? '—',
      username:     prof['Username'] ?? '—',
      domain:       prof['Domain'] ?? '—',
      profileDir:   prof['ProfileDir'] ?? '—',
      systemDrive:  prof['SystemDrive'] ?? '—',
    );
  }

  // ── PowerShell scripts ──────────────────────────────────────────────────

  static const _networkScript = r'''
$a = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$ip  = $a.IPv4Address.IPAddress
$gw  = $a.IPv4DefaultGateway.NextHop
$dns = ($a.DNSServer.ServerAddresses -join ", ")
$sub = (Get-NetIPAddress -IPAddress $ip -ErrorAction SilentlyContinue).PrefixLength
$mac = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).MacAddress
$hn  = $env:COMPUTERNAME
"Hostname=$hn"
"IPv4=$ip"
"SubnetMask=/$sub"
"Gateway=$gw"
"MAC=$mac"
"DNS=$dns"
''';

  static const _systemScript = r'''
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$boot = $os.LastBootUpTime
$uptime = (Get-Date) - $boot
$days = [int]$uptime.TotalDays
$hrs  = $uptime.Hours
$mins = $uptime.Minutes
"ComputerName=$($cs.Name)"
"OS=$($os.Caption)"
"OSVersion=$($os.Version)"
"Arch=$($os.OSArchitecture)"
"Uptime=${days}d ${hrs}h ${mins}m"
''';

  static const _hardwareScript = r'''
$cpu  = (Get-CimInstance Win32_Processor | Select-Object -First 1)
$ram  = Get-CimInstance Win32_OperatingSystem
$gpu  = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
$totalGB = [math]::Round($ram.TotalVisibleMemorySize / 1MB, 1)
$freeGB  = [math]::Round($ram.FreePhysicalMemory / 1MB, 1)
"CPU=$($cpu.Name.Trim())"
"Cores=$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
"RAMTotal=${totalGB} GB"
"RAMFree=${freeGB} GB free"
"GPU=$gpu"
''';

  static const _profileScript = r'''
"Username=$env:USERNAME"
"Domain=$env:USERDOMAIN"
"ProfileDir=$env:USERPROFILE"
"SystemDrive=$env:SystemDrive"
''';

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Future<String> _ps(String script) async {
    try {
      final result = await Process.run(
          'powershell', ['-NoProfile', '-Command', script],
          stdoutEncoding: const SystemEncoding());
      return result.stdout.toString();
    } catch (_) { return ''; }
  }

  static Map<String, String> _parseKV(String output) {
    final map = <String, String>{};
    for (final line in output.split('\n')) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        map[line.substring(0, idx).trim()] =
            line.substring(idx + 1).trim();
      }
    }
    return map;
  }

  static Future<String?> _getPublicIP() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(
          Uri.parse('https://api.ipify.org'));
      final res = await req.close();
      final ip = await res.transform(utf8.decoder).join();
      client.close();
      return ip.trim();
    } catch (_) { return null; }
  }

  static Future<_WifiInfo?> _getWifi() async {
    try {
      final result = await Process.run(
          'netsh', ['wlan', 'show', 'interfaces'],
          stdoutEncoding: const SystemEncoding());
      final out = result.stdout.toString();
      if (!out.contains('SSID')) return null;

      String _field(String key) {
        final pattern = RegExp('$key\\s*:\\s*(.+)', caseSensitive: false);
        return pattern.firstMatch(out)?.group(1)?.trim() ?? '—';
      }

      int _signal() {
        final m = RegExp(r'Signal\s*:\s*(\d+)%').firstMatch(out);
        return int.tryParse(m?.group(1) ?? '0') ?? 0;
      }

      return _WifiInfo(
        ssid:          _field('SSID'),
        bssid:         _field('BSSID'),
        radioType:     _field('Radio type'),
        auth:          _field('Authentication'),
        channel:       _field('Channel'),
        rxRate:        _field('Receive rate'),
        txRate:        _field('Transmit rate'),
        signalPercent: _signal(),
      );
    } catch (_) { return null; }
  }
}
