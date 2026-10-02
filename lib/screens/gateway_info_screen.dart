// lib/screens/gateway_info_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

// ─── Brand profiles ───────────────────────────────────────────────────────────

class _BrandProfile {
  final String name;
  final String defaultUser;
  final String defaultPass;
  final String adminUrl;
  final List<String> tokens; // substrings to match in HTTP headers/body
  const _BrandProfile({
    required this.name, required this.defaultUser, required this.defaultPass,
    required this.adminUrl, required this.tokens,
  });
}

const _brandProfiles = <_BrandProfile>[
  _BrandProfile(name: 'TP-Link',    defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['tplink','tp-link','archer','tl-']),
  _BrandProfile(name: 'ASUS',       defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['asus','asuswrt','rt-','merlin']),
  _BrandProfile(name: 'Netgear',    defaultUser: 'admin', defaultPass: 'password',
      adminUrl: 'http://{ip}',         tokens: ['netgear','orbi','nighthawk','readynas']),
  _BrandProfile(name: 'D-Link',     defaultUser: 'admin', defaultPass: '',
      adminUrl: 'http://{ip}',         tokens: ['d-link','dlink','dap-','dir-']),
  _BrandProfile(name: 'Linksys',    defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['linksys','cisco-linksys','velop']),
  _BrandProfile(name: 'Ubiquiti',   defaultUser: 'ubnt',  defaultPass: 'ubnt',
      adminUrl: 'https://{ip}',        tokens: ['ubiquiti','ubnt','unifi','edgeos','airmax']),
  _BrandProfile(name: 'MikroTik',   defaultUser: 'admin', defaultPass: '',
      adminUrl: 'http://{ip}',         tokens: ['mikrotik','routeros','rb']),
  _BrandProfile(name: 'Cisco',      defaultUser: 'cisco', defaultPass: 'cisco',
      adminUrl: 'http://{ip}',         tokens: ['cisco','ios','catalyst','aironet']),
  _BrandProfile(name: 'Huawei',     defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['huawei','hg','echolife']),
  _BrandProfile(name: 'Xiaomi',     defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['xiaomi','miui','miwifi']),
  _BrandProfile(name: 'ZTE',        defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['zte','zxhn','f660']),
  _BrandProfile(name: 'Zyxel',      defaultUser: 'admin', defaultPass: '1234',
      adminUrl: 'http://{ip}',         tokens: ['zyxel','zywall','nbg']),
  _BrandProfile(name: 'Tenda',      defaultUser: 'admin', defaultPass: 'admin',
      adminUrl: 'http://{ip}',         tokens: ['tenda','tendawifi']),
  _BrandProfile(name: 'Belkin',     defaultUser: '',      defaultPass: '',
      adminUrl: 'http://{ip}',         tokens: ['belkin']),
  _BrandProfile(name: 'Fritz!Box',  defaultUser: 'admin', defaultPass: 'fritz1234',
      adminUrl: 'http://fritz.box',    tokens: ['fritzbox','fritz!box','avm']),
];

// OUI prefix → brand name (first 3 bytes of MAC, uppercase no separators)
const _ouiBrands = <String, String>{
  // TP-Link
  'C80101': 'TP-Link', '50C7BF': 'TP-Link', 'B0BE76': 'TP-Link',
  'D8071A': 'TP-Link', '1C3BF3': 'TP-Link', 'E8DE27': 'TP-Link',
  // ASUS
  '049226': 'ASUS', '107B44': 'ASUS', '3497F6': 'ASUS',
  '6045CB': 'ASUS', 'AC9E17': 'ASUS', 'F8321A': 'ASUS',
  // Netgear
  '9C3DCF': 'Netgear', 'A040A0': 'Netgear', 'C03F0E': 'Netgear',
  'E091F5': 'Netgear', '20E52A': 'Netgear', '2CB05D': 'Netgear',
  // D-Link
  '1C7EE5': 'D-Link', '28107B': 'D-Link', '84C9B2': 'D-Link',
  'B8A386': 'D-Link', 'C8BE19': 'D-Link',
  // Linksys
  '00177F': 'Linksys', '203A07': 'Linksys', '48F8B3': 'Linksys',
  // Ubiquiti
  '0418D6': 'Ubiquiti', '44D9E7': 'Ubiquiti', '687272': 'Ubiquiti',
  '788A20': 'Ubiquiti', 'DCBF31': 'Ubiquiti', 'E863BB': 'Ubiquiti',
  'F09FC2': 'Ubiquiti', '24A43C': 'Ubiquiti', '80210A': 'Ubiquiti',
  // MikroTik
  '4C5E0C': 'MikroTik', '6C3B6B': 'MikroTik', 'B8069F': 'MikroTik',
  'D4CA6D': 'MikroTik', 'E48D8C': 'MikroTik',
  // Cisco
  '00001B': 'Cisco', '000164': 'Cisco', '0050BF': 'Cisco',
  '2C54CF': 'Cisco', '3C0E23': 'Cisco', '6400F1': 'Cisco',
  // Huawei
  '001E10': 'Huawei', '00259E': 'Huawei', '0C37DC': 'Huawei',
  '287810': 'Huawei', '4C5499': 'Huawei', '5C4CA9': 'Huawei',
  // Xiaomi
  '28D244': 'Xiaomi', '5486E8': 'Xiaomi', '64B473': 'Xiaomi',
  '8C97EA': 'Xiaomi', 'A4C138': 'Xiaomi', 'F48B32': 'Xiaomi',
  // ZTE
  '002293': 'ZTE', '001E8C': 'ZTE', '7C4CE4': 'ZTE', 'F4C714': 'ZTE',
  // Zyxel
  '001349': 'Zyxel', '00A0C5': 'Zyxel', '5C497D': 'Zyxel', 'BC9911': 'Zyxel',
  // Tenda
  'C83A35': 'Tenda', 'D0C7C0': 'Tenda', 'F43E61': 'Tenda',
};

// ─── Data model ───────────────────────────────────────────────────────────────

enum _DeviceRole { gateway, switch_, accessPoint, unknown }

class _GatewayDevice {
  final String ip;
  final String? mac;
  final String? brand;
  final _DeviceRole role;
  final String? hostname;
  final String? pageTitle;
  final String? serverHeader;
  final bool httpOpen;
  final bool httpsOpen;
  final bool sshOpen;
  final bool telnetOpen;
  final bool snmpOpen;
  final _BrandProfile? profile;

  const _GatewayDevice({
    required this.ip, required this.role, required this.httpOpen,
    required this.httpsOpen, required this.sshOpen, required this.telnetOpen,
    required this.snmpOpen,
    this.mac, this.brand, this.hostname, this.pageTitle,
    this.serverHeader, this.profile,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class GatewayInfoScreen extends StatefulWidget {
  const GatewayInfoScreen({super.key});
  @override State<GatewayInfoScreen> createState() => _GatewayInfoScreenState();
}

class _GatewayInfoScreenState extends State<GatewayInfoScreen> {
  bool _loading = false;
  String _status = '';
  List<_GatewayDevice> _devices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; _devices = []; _status = 'Detecting gateway...'; });
    try {
      final dm = context.read<DeviceManager>();
      final gatewayIp = dm.gateway;
      if (gatewayIp == null || gatewayIp.isEmpty) {
        setState(() { _error = 'Could not detect gateway IP'; _loading = false; });
        return;
      }

      // Probe gateway
      setState(() => _status = 'Probing $gatewayIp...');
      final gw = await _probeDevice(gatewayIp, _DeviceRole.gateway);
      if (mounted) setState(() => _devices = [gw]);

      // Look for switches/APs at common IPs near the gateway
      final prefix = gatewayIp.substring(0, gatewayIp.lastIndexOf('.'));
      final candidateLastOctets = <int>{};
      // Common switch/AP addresses: .1, .2, .254, .253, .100, .200
      for (final o in [1, 2, 254, 253, 100, 200]) candidateLastOctets.add(o);
      // Also add gateway's last octet ±1
      final gwLast = int.tryParse(gatewayIp.split('.').last) ?? 0;
      for (final d in [-1, 1, 2]) {
        final o = gwLast + d;
        if (o > 0 && o < 255) candidateLastOctets.add(o);
      }
      candidateLastOctets.remove(gwLast); // skip gateway itself

      setState(() => _status = 'Scanning for switches / APs...');
      final candidates = candidateLastOctets.map((o) => '$prefix.$o').toList();
      final results = await Future.wait(candidates.map((ip) => _probeCandidate(ip)));
      final found = results.whereType<_GatewayDevice>().toList();
      if (mounted) setState(() { _devices = [gw, ...found]; _status = ''; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  // Full probe for gateway
  Future<_GatewayDevice> _probeDevice(String ip, _DeviceRole role) async {
    final results = await Future.wait([
      _tcpCheck(ip, 80),
      _tcpCheck(ip, 443),
      _tcpCheck(ip, 22),
      _tcpCheck(ip, 23),
      _tcpCheck(ip, 161),
    ]);
    final httpOpen = results[0];
    final httpsOpen = results[1];
    final sshOpen = results[2];
    final telnetOpen = results[3];
    final snmpOpen = results[4];

    final mac = await _getMac(ip);
    String? pageTitle, serverHeader, hostname, brand;

    if (httpOpen) {
      final info = await _fetchHttpInfo(ip, 80, 'http');
      pageTitle = info.$1;
      serverHeader = info.$2;
    } else if (httpsOpen) {
      final info = await _fetchHttpInfo(ip, 443, 'https');
      pageTitle = info.$1;
      serverHeader = info.$2;
    }

    // DNS hostname
    hostname = await _reverseDns(ip);

    // Detect brand: OUI → HTTP tokens → hostname tokens
    brand = _detectBrand(mac, pageTitle, serverHeader, hostname);
    final profile = brand != null
        ? _brandProfiles.where((b) => b.name == brand).firstOrNull
        : null;

    return _GatewayDevice(
      ip: ip, mac: mac, brand: brand, role: role, hostname: hostname,
      pageTitle: pageTitle, serverHeader: serverHeader,
      httpOpen: httpOpen, httpsOpen: httpsOpen, sshOpen: sshOpen,
      telnetOpen: telnetOpen, snmpOpen: snmpOpen, profile: profile,
    );
  }

  // Quick probe for candidate IPs — only include if HTTP/HTTPS/SSH responds
  Future<_GatewayDevice?> _probeCandidate(String ip) async {
    final results = await Future.wait([
      _tcpCheck(ip, 80),
      _tcpCheck(ip, 443),
      _tcpCheck(ip, 22),
      _tcpCheck(ip, 23),
      _tcpCheck(ip, 161),
    ]);
    final httpOpen = results[0];
    final httpsOpen = results[1];
    final sshOpen = results[2];
    final telnetOpen = results[3];
    final snmpOpen = results[4];

    if (!httpOpen && !httpsOpen && !sshOpen && !telnetOpen) return null;

    final mac = await _getMac(ip);
    String? pageTitle, serverHeader, hostname, brand;

    if (httpOpen) {
      final info = await _fetchHttpInfo(ip, 80, 'http');
      pageTitle = info.$1; serverHeader = info.$2;
    } else if (httpsOpen) {
      final info = await _fetchHttpInfo(ip, 443, 'https');
      pageTitle = info.$1; serverHeader = info.$2;
    }
    hostname = await _reverseDns(ip);
    brand = _detectBrand(mac, pageTitle, serverHeader, hostname);

    // Classify role
    _DeviceRole role = _DeviceRole.unknown;
    final combined = '${pageTitle ?? ''} ${serverHeader ?? ''} ${hostname ?? ''} ${brand ?? ''}'.toLowerCase();
    if (combined.contains('switch') || combined.contains('sg') || combined.contains('gs') ||
        combined.contains('managed') || sshOpen && !httpOpen) {
      role = _DeviceRole.switch_;
    } else if (combined.contains('ap') || combined.contains('access point') ||
        combined.contains('unifi') || combined.contains('aironet')) {
      role = _DeviceRole.accessPoint;
    } else if (httpOpen || httpsOpen) {
      role = _DeviceRole.gateway;
    }

    final profile = brand != null
        ? _brandProfiles.where((b) => b.name == brand).firstOrNull
        : null;

    return _GatewayDevice(
      ip: ip, mac: mac, brand: brand, role: role, hostname: hostname,
      pageTitle: pageTitle, serverHeader: serverHeader,
      httpOpen: httpOpen, httpsOpen: httpsOpen, sshOpen: sshOpen,
      telnetOpen: telnetOpen, snmpOpen: snmpOpen, profile: profile,
    );
  }

  Future<bool> _tcpCheck(String ip, int port) async {
    try {
      final s = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      await s.close();
      return true;
    } catch (_) { return false; }
  }

  Future<(String?, String?)> _fetchHttpInfo(String ip, int port, String scheme) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => true;
      final req = await client.getUrl(Uri.parse('$scheme://$ip:$port/'))
          .timeout(const Duration(seconds: 3));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      req.headers.set('Connection', 'close');
      final res = await req.close().timeout(const Duration(seconds: 3));
      final server = res.headers.value('server');
      final body = await res.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 3));
      client.close();
      final titleMatch = RegExp(r'<title[^>]*>([^<]{1,120})</title>', caseSensitive: false)
          .firstMatch(body);
      return (titleMatch?.group(1)?.trim(), server);
    } catch (_) { return (null, null); }
  }

  Future<String?> _getMac(String ip) async {
    try {
      final res = await Process.run('arp', ['-a', ip], runInShell: false)
          .timeout(const Duration(seconds: 2));
      final out = res.stdout.toString();
      final m = RegExp(r'([0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2})',
          caseSensitive: false).firstMatch(out);
      return m?.group(1)?.toUpperCase().replaceAll('-', ':');
    } catch (_) { return null; }
  }

  Future<String?> _reverseDns(String ip) async {
    try {
      final res = await Process.run('nslookup', [ip], runInShell: false)
          .timeout(const Duration(seconds: 3));
      final out = res.stdout.toString();
      for (final line in out.split('\n')) {
        if (line.trim().toLowerCase().startsWith('name:')) {
          return line.trim().substring(5).trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _detectBrand(String? mac, String? title, String? server, String? host) {
    // 1. OUI lookup
    if (mac != null) {
      final oui = mac.replaceAll(':', '').substring(0, 6).toUpperCase();
      final fromOui = _ouiBrands[oui];
      if (fromOui != null) return fromOui;
    }
    // 2. Token match in page title + server header + hostname
    final combined = '${title ?? ''} ${server ?? ''} ${host ?? ''}'.toLowerCase();
    if (combined.isEmpty) return null;
    for (final p in _brandProfiles) {
      for (final t in p.tokens) {
        if (combined.contains(t)) return p.name;
      }
    }
    return null;
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gateway & Switch Info', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Detects router/switch brand, default credentials & open management ports',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ])),
            if (!_loading)
              ElevatedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Rescan'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              ),
          ]),
          const SizedBox(height: 16),

          if (_loading) ...[
            Row(children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF))),
              const SizedBox(width: 10),
              Text(_status, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
          ],

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),

          if (_devices.isNotEmpty)
            Expanded(child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (_, i) => _DeviceCard(device: _devices[i]),
            ))
          else if (!_loading && _error == null)
            const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.router_outlined, size: 48, color: Colors.white12),
              SizedBox(height: 12),
              Text('No gateway detected', style: TextStyle(color: Colors.white38, fontSize: 14)),
            ]))),
        ]),
      ),
    );
  }
}

// ─── Device card ──────────────────────────────────────────────────────────────

class _DeviceCard extends StatefulWidget {
  const _DeviceCard({required this.device});
  final _GatewayDevice device;
  @override State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _showPass = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final profile = d.profile;
    final roleLabel = switch (d.role) {
      _DeviceRole.gateway      => 'Gateway / Router',
      _DeviceRole.switch_      => 'Switch',
      _DeviceRole.accessPoint  => 'Access Point',
      _DeviceRole.unknown      => 'Network Device',
    };
    final roleColor = switch (d.role) {
      _DeviceRole.gateway     => const Color(0xFF00D4FF),
      _DeviceRole.switch_     => const Color(0xFF9B59B6),
      _DeviceRole.accessPoint => const Color(0xFF2ECC71),
      _DeviceRole.unknown     => const Color(0xFF95A5A6),
    };
    final roleIcon = switch (d.role) {
      _DeviceRole.gateway     => Icons.router,
      _DeviceRole.switch_     => Icons.device_hub,
      _DeviceRole.accessPoint => Icons.wifi,
      _DeviceRole.unknown     => Icons.device_unknown_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1321),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(roleIcon, color: roleColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(d.brand ?? 'Unknown Brand',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(roleLabel, style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(d.ip, style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12)),
              if (d.hostname != null && d.hostname!.isNotEmpty)
                Text(d.hostname!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: d.ip)),
              child: const Icon(Icons.copy, size: 14, color: Colors.white24),
            ),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFF1E2D45)),

        // ── Info rows ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // MAC address
            if (d.mac != null) ...[
              _InfoRow(icon: Icons.settings_ethernet, label: 'MAC', value: d.mac!),
              const SizedBox(height: 8),
            ],

            // Page title / server header
            if (d.pageTitle != null && d.pageTitle!.isNotEmpty) ...[
              _InfoRow(icon: Icons.web, label: 'Page Title', value: d.pageTitle!),
              const SizedBox(height: 8),
            ],
            if (d.serverHeader != null && d.serverHeader!.isNotEmpty) ...[
              _InfoRow(icon: Icons.dns_outlined, label: 'Server', value: d.serverHeader!),
              const SizedBox(height: 8),
            ],

            // Default credentials
            if (profile != null) ...[
              const SizedBox(height: 4),
              const Text('Default Credentials',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _CredChip(
                    label: 'Username', value: profile.defaultUser.isEmpty ? '(none)' : profile.defaultUser)),
                const SizedBox(width: 8),
                Expanded(child: _CredChip(
                    label: 'Password',
                    value: _showPass
                        ? (profile.defaultPass.isEmpty ? '(none)' : profile.defaultPass)
                        : '••••••••',
                    onTap: () => setState(() => _showPass = !_showPass))),
              ]),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.open_in_browser, label: 'Admin URL',
                  value: profile.adminUrl.replaceAll('{ip}', d.ip)),
              const SizedBox(height: 8),
            ],

            // Open ports
            const SizedBox(height: 4),
            const Text('Management Ports',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _portChip('80/HTTP',    d.httpOpen),
              _portChip('443/HTTPS',  d.httpsOpen),
              _portChip('22/SSH',     d.sshOpen),
              _portChip('23/Telnet',  d.telnetOpen),
              _portChip('161/SNMP',   d.snmpOpen),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _portChip(String label, bool open) {
    const openColor  = Color(0xFF3DD68C);
    const closeColor = Color(0xFF6B7280);
    final c = open ? openColor : closeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: open ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: open ? 0.35 : 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: open ? 1.0 : 0.4))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.withValues(alpha: open ? 1.0 : 0.5),
            fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 13, color: Colors.white24),
    const SizedBox(width: 6),
    Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
    Expanded(child: GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: value)),
      child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis),
    )),
  ]);
}

class _CredChip extends StatelessWidget {
  const _CredChip({required this.label, required this.value, this.onTap});
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3F5F)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFF00D4FF), fontFamily: 'monospace', fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
