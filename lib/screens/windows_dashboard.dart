// lib/screens/windows_dashboard.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/device_manager.dart';
import '../services/update_service.dart';
import 'ping_screen.dart';
import 'traceroute_screen.dart';
import 'dns_lookup_screen.dart';
import 'arp_screen.dart';
import 'nmap_screen.dart';
import 'ssh_screen.dart';
import 'rdp_screen.dart';
import 'vnc_screen.dart';
import 'putty_screen.dart';
import 'ftp_sftp_screen.dart';
import 'speed_test_screen.dart';
import 'my_device_screen.dart';
import 'license_screen.dart';
import 'wifi_analyzer_screen.dart';
import 'subnet_calculator_screen.dart';
import 'hash_generator_screen.dart';
import 'password_generator_screen.dart';
import 'ip_geolocation_screen.dart';
import 'mac_vendor_screen.dart';
import 'whois_screen.dart';
import 'ssl_checker_screen.dart';
import 'banner_grabber_screen.dart';
import 'http_header_screen.dart';
import 'email_security_screen.dart';
import 'firewall_tester_screen.dart';
import 'bandwidth_monitor_screen.dart';
import 'network_connections_screen.dart';
import 'wake_on_lan_screen.dart';
import 'snmp_browser_screen.dart';
import 'netbios_scanner_screen.dart';
import 'camera_scanner_screen.dart';
import 'gateway_info_screen.dart';
import 'device_detail_screen.dart';

enum _NavItem {
  monitor('Monitor', Icons.monitor_heart),
  ping('Ping', Icons.wifi_tethering),
  traceroute('Traceroute', Icons.route),
  dns('DNS Lookup', Icons.dns),
  arp('ARP Table', Icons.table_chart_outlined),
  nmap('Nmap Scanner', Icons.manage_search),
  speedTest('Speed Test', Icons.speed),
  myDevice('My Device', Icons.devices),
  wifiAnalyzer('WiFi Analyzer', Icons.wifi),
  ssh('SSH Terminal', Icons.terminal),
  rdp('RDP Client', Icons.desktop_windows),
  vnc('VNC Viewer', Icons.monitor),
  putty('PuTTY', Icons.computer),
  ftp('FTP / SFTP', Icons.folder_open),
  // Security Tools
  sslChecker('SSL/TLS Checker', Icons.verified_user),
  httpHeaders('HTTP Headers', Icons.http),
  bannerGrabber('Banner Grabber', Icons.flag_outlined),
  whois('Whois', Icons.info_outline),
  emailSecurity('Email Security', Icons.email),
  firewallTester('Firewall Tester', Icons.fireplace_outlined),
  // Network Analysis
  subnetCalc('Subnet Calculator', Icons.calculate),
  ipGeo('IP Geolocation', Icons.location_on_outlined),
  macVendor('MAC Vendor', Icons.settings_ethernet),
  hashGen('Hash Generator', Icons.tag),
  passwordGen('Password Generator', Icons.password),
  bandwidth('Bandwidth Monitor', Icons.bar_chart),
  connections('Net Connections', Icons.device_hub),
  wakeOnLan('Wake on LAN', Icons.power_settings_new),
  snmp('SNMP Browser', Icons.account_tree_outlined),
  netbios('NetBIOS Scanner', Icons.lan_outlined),
  cameraScanner('Camera Scanner', Icons.videocam_outlined),
  gatewayInfo('Gateway & Switch', Icons.router_outlined);

  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ─── Root ──────────────────────────────────────────────────────────────────

class WindowsDashboard extends StatefulWidget {
  const WindowsDashboard({super.key});

  @override
  State<WindowsDashboard> createState() => _WindowsDashboardState();
}

class _WindowsDashboardState extends State<WindowsDashboard> {
  _NavItem _selected = _NavItem.monitor;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  @override
  void dispose() { _clockTimer?.cancel(); super.dispose(); }

  Widget _buildContent() => switch (_selected) {
    _NavItem.monitor      => _MonitorView(now: _now),
    _NavItem.ping         => const PingScreen(),
    _NavItem.traceroute   => const TracerouteScreen(),
    _NavItem.dns          => const DnsLookupScreen(),
    _NavItem.arp          => const ArpScreen(),
    _NavItem.nmap         => const NmapScreen(),
    _NavItem.speedTest    => const SpeedTestScreen(),
    _NavItem.myDevice     => const MyDeviceScreen(),
    _NavItem.wifiAnalyzer => const WifiAnalyzerScreen(),
    _NavItem.ssh          => const _SshLauncher(),
    _NavItem.rdp          => const RdpScreen(),
    _NavItem.vnc          => const VncScreen(),
    _NavItem.putty        => const PuttyScreen(),
    _NavItem.ftp          => const FtpSftpScreen(),
    _NavItem.sslChecker   => const SslCheckerScreen(),
    _NavItem.httpHeaders  => const HttpHeaderScreen(),
    _NavItem.bannerGrabber => const BannerGrabberScreen(),
    _NavItem.whois        => const WhoisScreen(),
    _NavItem.emailSecurity => const EmailSecurityScreen(),
    _NavItem.firewallTester => const FirewallTesterScreen(),
    _NavItem.subnetCalc   => const SubnetCalculatorScreen(),
    _NavItem.ipGeo        => const IpGeolocationScreen(),
    _NavItem.macVendor    => const MacVendorScreen(),
    _NavItem.hashGen      => const HashGeneratorScreen(),
    _NavItem.passwordGen  => const PasswordGeneratorScreen(),
    _NavItem.bandwidth    => const BandwidthMonitorScreen(),
    _NavItem.connections  => const NetworkConnectionsScreen(),
    _NavItem.wakeOnLan    => const WakeOnLanScreen(),
    _NavItem.snmp         => const SnmpBrowserScreen(),
    _NavItem.netbios        => const NetBiosScannerScreen(),
    _NavItem.cameraScanner  => const CameraScannerScreen(),
    _NavItem.gatewayInfo    => const GatewayInfoScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DeviceManager>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(children: [
        _Sidebar(selected: _selected, dm: dm, now: _now,
            onSelect: (item) => setState(() => _selected = item)),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1E2D45)),
        Expanded(child: _buildContent()),
      ]),
    );
  }
}

// ─── Sidebar ───────────────────────────────────────────────────────────────

class _Sidebar extends StatefulWidget {
  const _Sidebar({required this.selected, required this.dm,
    required this.now, required this.onSelect});

  final _NavItem selected;
  final DeviceManager dm;
  final DateTime now;
  final ValueChanged<_NavItem> onSelect;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  UpdateInfo? _updateInfo;
  bool _checking = false;
  int _ignoreCount = 0;

  static const _maxIgnores = 3; // after 3 dismissals, auto-install

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() { _updateInfo = info; _checking = false; });

    if (info.hasUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'update_ignored_${info.latestVersion}';
      _ignoreCount = prefs.getInt(key) ?? 0;
      if (!mounted) return;
      // Auto-popup: show dialog immediately on launch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateDialog(context, info);
      });
    }
  }

  Future<void> _onIgnore(UpdateInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'update_ignored_${info.latestVersion}';
    _ignoreCount = (_ignoreCount + 1);
    await prefs.setInt(key, _ignoreCount);
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UpdateDialog(
        info: info,
        ignoreCount: _ignoreCount,
        maxIgnores: _maxIgnores,
        onIgnore: () => _onIgnore(info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return SizedBox(
      width: 210,
      child: Container(
        color: const Color(0xFF0D1321),
        child: Column(children: [
          // ── Fixed header ──
          _SidebarHeader(dm: widget.dm),
          const Divider(height: 1, color: Color(0xFF1E2D45)),
          // ── Scrollable nav ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SectionLabel('NETWORK TOOLS'),
                for (final item in [_NavItem.monitor, _NavItem.ping,
                  _NavItem.traceroute, _NavItem.dns, _NavItem.arp,
                  _NavItem.nmap, _NavItem.speedTest, _NavItem.myDevice,
                  _NavItem.wifiAnalyzer])
                  _NavTile(item: item, selected: widget.selected == item,
                      badge: item == _NavItem.monitor && widget.dm.offlineCount > 0
                          ? '${widget.dm.offlineCount}' : null,
                      onTap: () => widget.onSelect(item)),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFF1E2D45)),
                const SizedBox(height: 6),
                _SectionLabel('REMOTE ACCESS'),
                for (final item in [_NavItem.ssh, _NavItem.rdp, _NavItem.vnc,
                  _NavItem.putty, _NavItem.ftp])
                  _NavTile(item: item, selected: widget.selected == item,
                      onTap: () => widget.onSelect(item)),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFF1E2D45)),
                const SizedBox(height: 6),
                _SectionLabel('SECURITY TOOLS'),
                for (final item in [_NavItem.sslChecker, _NavItem.httpHeaders,
                  _NavItem.bannerGrabber, _NavItem.whois, _NavItem.emailSecurity,
                  _NavItem.firewallTester])
                  _NavTile(item: item, selected: widget.selected == item,
                      onTap: () => widget.onSelect(item)),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFF1E2D45)),
                const SizedBox(height: 6),
                _SectionLabel('NETWORK ANALYSIS'),
                for (final item in [_NavItem.subnetCalc, _NavItem.ipGeo,
                  _NavItem.macVendor, _NavItem.hashGen, _NavItem.passwordGen,
                  _NavItem.bandwidth, _NavItem.connections, _NavItem.wakeOnLan,
                  _NavItem.snmp, _NavItem.netbios, _NavItem.cameraScanner,
          _NavItem.gatewayInfo])
                  _NavTile(item: item, selected: widget.selected == item,
                      onTap: () => widget.onSelect(item)),
              ],
            ),
          ),
          // ── Fixed footer ──
          const Divider(height: 1, color: Color(0xFF1E2D45)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF00FF88), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text('v${UpdateService.currentVersion}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10))),
              // Check for updates icon button
              if (_checking)
                const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.white24))
              else
                GestureDetector(
                  onTap: _checkUpdate,
                  child: const Tooltip(
                    message: 'Check for updates',
                    child: Icon(Icons.refresh, color: Colors.white24, size: 14),
                  ),
                ),
              const SizedBox(width: 6),
              Text(timeStr, style: const TextStyle(color: Colors.white24,
                  fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.dm});
  final DeviceManager dm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Title
        Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.monitor_heart, color: Color(0xFF00D4FF), size: 15)),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Unify Net Monitor', style: TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700)),
            Text('by Unify Technologies', style: TextStyle(
                color: Colors.white38, fontSize: 9)),
          ]),
        ]),
        const SizedBox(height: 10),

        // Network info
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2D45))),
          child: Column(children: [
            _InfoRow('MY IP', dm.localIP ?? '—', const Color(0xFF00D4FF)),
            const SizedBox(height: 4),
            _InfoRow('GATEWAY', dm.gateway ?? (dm.subnet != null ? '${dm.subnet}.1' : '—'),
                const Color(0xFF00FF88)),
            const SizedBox(height: 4),
            _InfoRow('SUBNET', dm.subnet != null ? '${dm.subnet}.0/24' : '—',
                Colors.white38),
          ]),
        ),
        const SizedBox(height: 8),

        // Stats row
        Row(children: [
          _StatChip('${dm.totalCount}', 'total', Colors.white38),
          const SizedBox(width: 5),
          _StatChip('${dm.onlineCount}', 'online', const Color(0xFF00FF88)),
          const SizedBox(width: 5),
          _StatChip('${dm.offlineCount}', 'offline', const Color(0xFFFF4466)),
        ]),
        const SizedBox(height: 8),

        // Scan button
        _ScanButton(dm: dm),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 52, child: Text(label, style: const TextStyle(
        color: Colors.white24, fontSize: 9, letterSpacing: 0.5))),
    Expanded(child: Text(value, style: TextStyle(color: color,
        fontSize: 10, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis)),
  ]);
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.value, this.label, this.color);
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8)),
      ]),
    ),
  );
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.dm});
  final DeviceManager dm;

  @override
  Widget build(BuildContext context) {
    if (dm.isScanning) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                  value: dm.scanTotal > 0 ? dm.scanProgress / dm.scanTotal : null,
                  color: const Color(0xFF00D4FF))),
          const SizedBox(width: 7),
          Text('${dm.scanProgress}/${dm.scanTotal}',
              style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                value: dm.scanTotal > 0 ? dm.scanProgress / dm.scanTotal : null,
                backgroundColor: const Color(0xFF1E2D45),
                color: const Color(0xFF00D4FF), minHeight: 3)),
      ]);
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => dm.scanNetwork(),
        icon: const Icon(Icons.radar, size: 13),
        label: const Text('Scan Network'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF).withOpacity(0.12),
          foregroundColor: const Color(0xFF00D4FF),
          side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
          padding: const EdgeInsets.symmetric(vertical: 7),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 5),
    child: Text(text, style: const TextStyle(color: Colors.white24,
        fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected,
    required this.onTap, this.badge});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D4FF);
    final fg = selected ? accent : Colors.white54;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: selected ? accent.withOpacity(0.25) : Colors.transparent),
        ),
        child: Row(children: [
          Icon(item.icon, size: 15, color: fg),
          const SizedBox(width: 9),
          Expanded(child: Text(item.label,
              style: TextStyle(color: fg, fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4466).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF4466).withOpacity(0.3)),
              ),
              child: Text(badge!, style: const TextStyle(
                  color: Color(0xFFFF4466), fontSize: 9,
                  fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ),
        ]),
      ),
    );
  }
}

// ─── Monitor View ──────────────────────────────────────────────────────────

class _MonitorView extends StatefulWidget {
  const _MonitorView({required this.now});
  final DateTime now;

  @override
  State<_MonitorView> createState() => _MonitorViewState();
}

class _MonitorViewState extends State<_MonitorView> {
  bool _showAll = false;
  bool _rdpQuerying = false;
  bool _sshQuerying = false;
  bool _vulnScanning = false;
  String? _rdpUser;
  String? _rdpPass;

  // ── Raw NBNS UDP Node Status query (port 137) ────────────────────────────
  // Does NOT require admin rights. Works when NetBIOS over TCP/IP is enabled.
  // Returns map of {name: type} e.g. {"DESKTOP-PC": 0x00, "JOHN": 0x03}
  Future<Map<String, int>> _rawNbns(String ip) async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      // Node Status Request — wildcard '*' encoded as CKAA…AA
      final pkt = Uint8List.fromList([
        0xAB, 0xCD,             // Transaction ID
        0x00, 0x10,             // Flags: NB_STATUS query
        0x00, 0x01,             // QDCOUNT = 1
        0x00, 0x00,             // ANCOUNT
        0x00, 0x00,             // NSCOUNT
        0x00, 0x00,             // ARCOUNT
        0x20,                   // QNAME length = 32
        0x43, 0x4B,             // '*' (0x2A) half-byte encoded = 'C','K'
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, // null bytes × 15 → AA×15
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x00,                   // null terminator
        0x00, 0x21,             // QTYPE: NBSTAT (33)
        0x00, 0x01,             // QCLASS: IN
      ]);

      sock.send(pkt, InternetAddress(ip), 137);

      final completer = Completer<Datagram?>();
      Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      sock.listen((e) {
        if (e == RawSocketEvent.read) {
          final d = sock.receive();
          if (d != null && !completer.isCompleted) completer.complete(d);
        }
      }, onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      final dg = await completer.future;
      sock.close();
      if (dg == null || dg.data.length < 12) return {};

      final data = dg.data;
      // Parse dynamically — offset varies by Windows version / implementation
      int offset = 12; // skip 12-byte header

      // Skip question section (QDCOUNT from header bytes 4-5)
      final qdcount = (data[4] << 8) | data[5];
      for (int q = 0; q < qdcount && offset < data.length; q++) {
        // Skip QNAME: label sequence ends with null byte, or 2-byte compressed ptr
        while (offset < data.length) {
          final len = data[offset];
          if (len == 0) { offset++; break; }
          if ((len & 0xC0) == 0xC0) { offset += 2; break; }
          offset += 1 + len;
        }
        offset += 4; // QTYPE + QCLASS
      }

      // Check there is at least one answer (ANCOUNT bytes 6-7)
      final ancount = (data[6] << 8) | data[7];
      if (ancount == 0 || offset >= data.length) return {};

      // Skip answer RR NAME (same label/pointer format as above)
      while (offset < data.length) {
        final len = data[offset];
        if (len == 0) { offset++; break; }
        if ((len & 0xC0) == 0xC0) { offset += 2; break; }
        offset += 1 + len;
      }

      // Skip TYPE(2) + CLASS(2) + TTL(4) + RDLENGTH(2) = 10 bytes
      offset += 10;
      if (offset >= data.length) return {};

      // RDATA: NUM_NAMES (1 byte) then 18-byte entries
      // Each entry: 15-byte name + 1-byte type + 2-byte flags
      // Flags bit 15 (high byte bit 7 = 0x80): 1 = group name, 0 = unique name
      final numNames = data[offset++];
      final result = <String, int>{};
      for (int i = 0; i < numNames && offset + 18 <= data.length; i++) {
        final rawName = data.sublist(offset, offset + 15)
            .where((b) => b >= 0x21 && b <= 0x7E)
            .map(String.fromCharCode)
            .join()
            .trim();
        final type = data[offset + 15];
        final flagsHi = data[offset + 16]; // high byte of 2-byte flags field
        final isGroup = (flagsHi & 0x80) != 0;
        offset += 18;
        if (rawName.isNotEmpty) {
          // Encode group flag in high bit of stored value so callers can filter
          result[rawName] = isGroup ? (type | 0x100) : type;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  // ── Main per-device query ─────────────────────────────────────────────────
  Future<_RdpUserResult> _queryDevice(Device device) async {
    final openPorts = device.ports.where((p) => p.isOpen).map((p) => p.port).toSet();
    final hasRdp = openPorts.contains(3389);
    final hasSsh = openPorts.contains(22);
    final hasTelnet = openPorts.contains(23);

    String? computerName;
    final usernames = <String>[];
    String? banner;
    String? error;
    String portLabel = hasRdp ? 'RDP' : hasSsh ? 'SSH' : 'Telnet';

    // ── Windows (RDP port 3389) ───────────────────────────────────────────
    if (hasRdp) {
      // Method 1: raw NBNS UDP to port 137 — no admin rights needed
      final nbns = await _rawNbns(device.ip);
      if (nbns.isNotEmpty) {
        // Computer name = unique (not group) type 0x00 entry
        // Group names (workgroup) have 0x100 bit set — skip them
        computerName = nbns.entries
            .where((e) => e.value == 0x00) // unique type-00
            .map((e) => e.key)
            .firstOrNull;
        // Logged-in username = unique type 0x03 entry that isn't the computer name
        final u03 = nbns.entries
            .where((e) => e.value == 0x03 && e.key != computerName)
            .map((e) => e.key)
            .toList();
        usernames.addAll(u03);
      }

      // Method 2: wmic computersystem get username (works in same workgroup)
      if (usernames.isEmpty) {
        try {
          final wmicArgs = _rdpUser != null && _rdpPass != null
              ? ['/node:${device.ip}', '/user:$_rdpUser', '/password:$_rdpPass',
                 'computersystem', 'get', 'username']
              : ['/node:${device.ip}', 'computersystem', 'get', 'username'];
          final res = await Process.run('wmic', wmicArgs,
              stdoutEncoding: const SystemEncoding(),
              stderrEncoding: const SystemEncoding())
              .timeout(const Duration(seconds: 8));
          final out = res.stdout.toString();
          for (final line in out.split('\n').skip(1)) {
            final u = line.trim();
            // Output: "DOMAIN\username" or just "username"
            if (u.isNotEmpty && !u.toLowerCase().startsWith('username')) {
              final shortUser = u.contains(r'\') ? u.split(r'\').last : u;
              if (shortUser.isNotEmpty) usernames.add(shortUser);
            }
          }
        } catch (_) {}
      }

      // Method 3: query session /server — needs admin rights on remote
      if (usernames.isEmpty) {
        try {
          final qArgs = _rdpUser != null && _rdpPass != null
              ? ['session', '/server:${device.ip}']
              : ['session', '/server:${device.ip}'];
          final res = await Process.run('query', qArgs,
              stdoutEncoding: const SystemEncoding(),
              stderrEncoding: const SystemEncoding())
              .timeout(const Duration(seconds: 6));
          final out = res.stdout.toString();
          for (final line in out.split('\n')) {
            final m = RegExp(
                    r'^\s*>?\s*\S+\s{2,}(\S+)\s+\d+\s+Active',
                    caseSensitive: false)
                .firstMatch(line);
            if (m != null) {
              final u = m.group(1)?.trim() ?? '';
              if (u.isNotEmpty && u.toLowerCase() != 'username') {
                usernames.add(u);
              }
            }
          }
        } catch (_) {}
      }

      // Method 4: nbtstat -A fallback (older Windows / Messenger service)
      if (usernames.isEmpty) {
        try {
          final res = await Process.run('nbtstat', ['-A', device.ip],
              stdoutEncoding: const SystemEncoding())
              .timeout(const Duration(seconds: 5));
          final out = res.stdout.toString();
          if (computerName == null) {
            final m = RegExp(r'^\s*(\S+)\s+<00>\s+UNIQUE',
                    multiLine: true, caseSensitive: false)
                .firstMatch(out);
            computerName = m?.group(1)?.trim().toUpperCase();
          }
          final u03 = RegExp(r'^\s*(\S+)\s+<03>\s+UNIQUE',
                  multiLine: true, caseSensitive: false)
              .allMatches(out)
              .map((m) => m.group(1)!.trim().toUpperCase())
              .where((u) => u != computerName)
              .toList();
          usernames.addAll(u03);
        } catch (_) {}
      }

      if (usernames.isEmpty) {
        error = computerName != null && computerName!.isNotEmpty
            ? 'No user detected on $computerName (admin rights may be needed)'
            : 'No NetBIOS response — check firewall or NetBIOS over TCP/IP setting';
      }
    }

    // ── SSH (22) ─────────────────────────────────────────────────────────
    if (hasSsh) {
      try {
        final sock = await Socket.connect(device.ip, 22,
            timeout: const Duration(seconds: 3));
        final buf = StringBuffer();
        final done = Completer<void>();
        late StreamSubscription sub;
        sub = sock.listen((data) {
          buf.write(String.fromCharCodes(data));
          if (!done.isCompleted) done.complete();
        },
            onDone: () { if (!done.isCompleted) done.complete(); },
            onError: (_) { if (!done.isCompleted) done.complete(); });
        await done.future
            .timeout(const Duration(seconds: 2), onTimeout: () {});
        await sub.cancel();
        await sock.close();
        final raw = buf.toString().trim();
        if (raw.startsWith('SSH-')) {
          banner = raw.split('\n').first.trim();
          final osHint = _parseSshOs(banner!);
          if (osHint != null && usernames.isEmpty) usernames.add(osHint);
        } else {
          error ??= 'No SSH banner returned';
        }
      } catch (_) {
        error ??= 'SSH connection failed';
      }
      if (!hasRdp) portLabel = 'SSH';
    }

    // ── Telnet (23) ───────────────────────────────────────────────────────
    if (hasTelnet) {
      try {
        final sock = await Socket.connect(device.ip, 23,
            timeout: const Duration(seconds: 3));
        final buf = <int>[];
        final done = Completer<void>();
        Timer(const Duration(seconds: 2),
            () { if (!done.isCompleted) done.complete(); });
        late StreamSubscription sub;
        sub = sock.listen((data) {
          buf.addAll(data);
          if (buf.length > 512 && !done.isCompleted) done.complete();
        },
            onDone: () { if (!done.isCompleted) done.complete(); },
            onError: (_) { if (!done.isCompleted) done.complete(); });
        await done.future;
        await sub.cancel();
        await sock.close();
        // Strip IAC control bytes (0xFF + 2 following bytes)
        final cleaned = <int>[];
        int skip = 0;
        for (final b in buf) {
          if (skip > 0) { skip--; continue; }
          if (b == 0xFF) { skip = 2; continue; }
          if (b >= 32 && b < 127) cleaned.add(b);
        }
        final raw = String.fromCharCodes(cleaned).trim();
        if (raw.isNotEmpty) {
          banner = raw.length > 200 ? '${raw.substring(0, 200)}…' : raw;
          final hostMatch = RegExp(r'^(\S+)\s+(login|User Access)',
                  caseSensitive: false)
              .firstMatch(raw);
          if (hostMatch != null && computerName == null) {
            computerName = hostMatch.group(1);
          }
        } else {
          error ??= 'Empty telnet banner';
        }
      } catch (_) {
        if (!hasSsh && !hasRdp) error ??= 'Telnet connection failed';
      }
      if (!hasRdp && !hasSsh) portLabel = 'Telnet';
    }

    // ── net user \\<ip> — local accounts (Windows/RDP only) ──────────────
    // Only attempt on Windows machines (RDP port 3389 open) — SSH/Telnet
    // devices are not Windows and net user will just print its help text.
    final (localUsers, netUserError) =
        hasRdp ? await _queryNetUser(device.ip) : (<String>[], null as String?);

    return _RdpUserResult(
      ip: device.ip,
      name: device.name,
      computerName: computerName,
      usernames: usernames,
      localUsers: localUsers,
      netUserError: netUserError,
      banner: banner,
      portLabel: portLabel,
      error: usernames.isEmpty && banner == null && localUsers.isEmpty
          ? (error ?? netUserError ?? 'No info retrieved')
          : null,
    );
  }

  // Returns (users, errorNote)
  Future<(List<String>, String?)> _queryNetUser(String ip) async {
    // Method 1: net user \\<ip>
    try {
      final result = await Process.run(
        'net',
        ['user', r'\\' + ip],
        runInShell: true,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(const Duration(seconds: 6));
      final out = (result.stdout as String?) ?? '';
      final err = (result.stderr as String?) ?? '';

      final lines = out.split('\n');
      final users = <String>[];
      bool inAccounts = false;
      for (final line in lines) {
        final t = line.trim();
        if (t.startsWith('---')) { inAccounts = true; continue; }
        if (!inAccounts) continue;
        if (t.isEmpty || t.startsWith('The command')) break;
        users.addAll(t.split(RegExp(r'\s{2,}')).map((s) => s.trim()).where((s) => s.isNotEmpty));
      }
      if (users.isNotEmpty) return (users, null as String?);

      // Capture the error for display
      final errLine = err.split('\n').map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => '');
      final netErr = errLine.isNotEmpty ? errLine : null;

      // Method 2: wmic /node:<ip> useraccount list brief
      try {
        final wmic = await Process.run(
          'wmic',
          ['/node:$ip', 'useraccount', 'list', 'brief'],
          runInShell: true,
          stdoutEncoding: const SystemEncoding(),
          stderrEncoding: const SystemEncoding(),
        ).timeout(const Duration(seconds: 6));
        final wmicOut = (wmic.stdout as String?) ?? '';
        // Columns: AccountType  Description  Domain  FullName  Name  SID
        final wmicUsers = <String>[];
        for (final line in wmicOut.split('\n').skip(1)) {
          final cols = line.trim().split(RegExp(r'\s{2,}'));
          if (cols.length >= 5) {
            final name = cols[4].trim();
            if (name.isNotEmpty && name.toLowerCase() != 'name') {
              wmicUsers.add(name);
            }
          }
        }
        if (wmicUsers.isNotEmpty) return (wmicUsers, null as String?);
      } catch (_) {}

      return (<String>[], netErr != null ? 'net user: $netErr' : null);
    } catch (_) {
      return (<String>[], null);
    }
  }

  String? _parseSshOs(String banner) {
    final b = banner.toLowerCase();
    if (b.contains('ubuntu')) return 'Ubuntu Linux';
    if (b.contains('debian')) return 'Debian Linux';
    if (b.contains('centos')) return 'CentOS Linux';
    if (b.contains('fedora')) return 'Fedora Linux';
    if (b.contains('raspbian') || b.contains('raspberry')) return 'Raspberry Pi';
    if (b.contains('windows')) return 'Windows (OpenSSH)';
    if (b.contains('freebsd')) return 'FreeBSD';
    if (b.contains('openbsd')) return 'OpenBSD';
    if (b.contains('cisco')) return 'Cisco IOS';
    if (b.contains('fortinet') || b.contains('fortigate')) return 'Fortinet';
    return null;
  }

  Future<void> _showUserInfo(BuildContext context, List<Device> targets) async {
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No devices with port 22, 23, or 3389 open. Run a scan first.'),
        backgroundColor: Color(0xFF111927),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    // Ask for optional Windows credentials to authenticate wmic/net user
    final creds = await _askWindowsCreds(context);
    if (creds == null) return; // cancelled
    _rdpUser = creds.$1.isEmpty ? null : creds.$1;
    _rdpPass = creds.$2.isEmpty ? null : creds.$2;

    setState(() => _rdpQuerying = true);
    final results = await Future.wait(targets.map(_queryDevice));
    if (!mounted) return;
    setState(() => _rdpQuerying = false);

    showDialog(
      context: context,
      builder: (_) => _RdpUsersDialog(results: results),
    );
  }

  Future<(String, String)?> _askWindowsCreds(BuildContext context) async {
    final userCtrl = TextEditingController(text: _rdpUser ?? '');
    final passCtrl = TextEditingController(text: _rdpPass ?? '');
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111927),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1E2D45))),
        title: const Row(children: [
          Icon(Icons.lock_open, color: Color(0xFFAB6BFF), size: 18),
          SizedBox(width: 8),
          Text('Windows Credentials',
              style: TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Optional: provide admin credentials to query logged-in users via wmic.\n'
            'Leave blank to try without credentials.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: userCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Username (e.g. Administrator)',
              labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E2D45))),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFAB6BFF))),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E2D45))),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFAB6BFF))),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (userCtrl.text, passCtrl.text)),
            child: const Text('Query', style: TextStyle(color: Color(0xFFAB6BFF))),
          ),
        ],
      ),
    );
  }

  // ── SSH-only banner scan ────────────────────────────────────────────────
  Future<void> _showSshBanners(BuildContext context, List<Device> targets) async {
    setState(() => _sshQuerying = true);
    final results = <_SshBannerResult>[];
    await Future.wait(targets.map((d) async {
      final ports = d.ports.where((p) => (p.port == 22 || p.port == 23) && p.isOpen).toList();
      for (final port in ports) {
        String? banner;
        String? os;
        try {
          if (port.port == 22) {
            final sock = await Socket.connect(d.ip, 22,
                timeout: const Duration(seconds: 4));
            final bytes = <int>[];
            await sock.first.timeout(const Duration(seconds: 3)).then((chunk) {
              bytes.addAll(chunk);
            }).catchError((_) {});
            await sock.close();
            banner = String.fromCharCodes(
                bytes.where((b) => b >= 32 && b < 127)).trim();
            os = _parseSshOs(banner);
          } else {
            final sock = await Socket.connect(d.ip, 23,
                timeout: const Duration(seconds: 3));
            final buf = <int>[];
            bool done = false;
            final sub = sock.listen((chunk) {
              for (int i = 0; i < chunk.length; i++) {
                if (chunk[i] == 0xFF && i + 2 < chunk.length) { i += 2; continue; }
                if (chunk[i] >= 32 && chunk[i] < 127) buf.add(chunk[i]);
              }
              if (buf.length > 80) done = true;
            });
            await Future.delayed(const Duration(seconds: 2));
            await sub.cancel();
            await sock.close();
            banner = String.fromCharCodes(buf).trim();
            if (banner.isEmpty) banner = null;
          }
        } catch (_) {}
        results.add(_SshBannerResult(
          ip: d.ip, name: d.name, port: port.port,
          banner: banner, os: os,
        ));
      }
    }));
    if (!mounted) return;
    setState(() => _sshQuerying = false);
    showDialog(
      context: context,
      builder: (_) => _SshBannersDialog(results: results),
    );
  }

  // ── Device type detection helpers ─────────────────────────────────────
  static const _cameraKeywords = [
    'hikvision', 'dahua', 'axis', 'bosch', 'hanwha', 'amcrest', 'reolink',
    'foscam', 'uniview', 'vivotek', 'milesight', 'cp plus', 'provision',
    'camera', 'cam', 'dvr', 'nvr', 'ipcam', 'cctv',
  ];
  static const _routerKeywords = [
    'cisco', 'ubiquiti', 'mikrotik', 'tp-link', 'tplink', 'netgear', 'asus',
    'linksys', 'dlink', 'd-link', 'zyxel', 'fortinet', 'juniper', 'aruba',
    'huawei', 'router', 'gateway', 'modem', 'access point', 'unifi',
  ];
  static const _switchKeywords = [
    'switch', 'sg300', 'sg500', 'catalyst', 'procurve', 'powerconnect',
    'gs', 'tl-sg', 'tl-sl', 'smart switch',
  ];

  bool _isCamera(Device d) {
    final s = '${d.name} ${d.manufacturer ?? ''} ${d.hostname ?? ''}'.toLowerCase();
    return _cameraKeywords.any(s.contains) ||
        d.ports.any((p) => (p.port == 554 || p.port == 8000 || p.port == 37777) && p.isOpen);
  }

  bool _isRouter(Device d) {
    final s = '${d.name} ${d.manufacturer ?? ''} ${d.hostname ?? ''}'.toLowerCase();
    return _routerKeywords.any(s.contains);
  }

  bool _isSwitch(Device d) {
    final s = '${d.name} ${d.manufacturer ?? ''} ${d.hostname ?? ''}'.toLowerCase();
    return _switchKeywords.any(s.contains);
  }

  // ── Active probe helpers ────────────────────────────────────────────────

  // RTSP: sends OPTIONS without credentials. Returns true if server responds
  // 200 OK (stream accessible without auth).
  Future<bool> _rtspNoAuth(String ip, {int port = 554}) async {
    try {
      final sock = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 3));
      sock.write('OPTIONS rtsp://$ip:$port/ RTSP/1.0\r\nCSeq: 1\r\n\r\n');
      final chunks = <int>[];
      await for (final c in sock.timeout(const Duration(seconds: 2))) {
        chunks.addAll(c);
        if (chunks.length > 50) break;
      }
      sock.destroy();
      final resp = String.fromCharCodes(chunks);
      return resp.startsWith('RTSP/1.0 200');
    } catch (_) {
      return false;
    }
  }

  // HTTP GET: returns (statusCode, serverHeader, body100) or null on failure.
  Future<(int, String, String)?> _httpGet(String ip, int port,
      {String path = '/', bool https = false}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => true;
      final uri = Uri.parse('${https ? "https" : "http"}://$ip:$port$path');
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 2))
          .catchError((_) => '');
      final server = res.headers.value('server') ?? '';
      client.close();
      return (res.statusCode, server, body.length > 300 ? body.substring(0, 300) : body);
    } catch (_) {
      return null;
    }
  }

  // SNMP v1 GET with community "public" on UDP 161.
  // Returns true if the device responded (default community accepted).
  Future<bool> _snmpPublic(String ip) async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.timeout(const Duration(seconds: 3));
      // Minimal SNMP v1 GetRequest for sysDescr.0 (OID 1.3.6.1.2.1.1.1.0)
      final pkt = Uint8List.fromList([
        0x30, 0x26, // SEQUENCE
        0x02, 0x01, 0x00, // version: 0 (SNMPv1)
        0x04, 0x06, 0x70, 0x75, 0x62, 0x6c, 0x69, 0x63, // community: "public"
        0xa0, 0x19, // GetRequest-PDU
        0x02, 0x01, 0x01, // request-id: 1
        0x02, 0x01, 0x00, // error-status: 0
        0x02, 0x01, 0x00, // error-index: 0
        0x30, 0x0e, // variable-bindings
        0x30, 0x0c,
        0x06, 0x08, 0x2b, 0x06, 0x01, 0x02, 0x01, 0x01, 0x01, 0x00, // OID sysDescr.0
        0x05, 0x00, // null value
      ]);
      sock.send(pkt, InternetAddress(ip), 161);
      bool got = false;
      await for (final ev in sock) {
        if (ev == RawSocketEvent.read) {
          sock.receive();
          got = true;
          break;
        }
      }
      sock.close();
      return got;
    } catch (_) {
      return false;
    }
  }

  // ── Vulnerability scan ─────────────────────────────────────────────────
  Future<void> _runVulnScan(BuildContext context, List<Device> all) async {
    setState(() => _vulnScanning = true);
    await Future.delayed(const Duration(milliseconds: 100));

    final online = all.where((d) => d.status == DeviceStatus.online).toList();
    final findings = <_VulnFinding>[];

    // Run all device checks in parallel
    await Future.wait(online.map((d) async {
      final open = d.ports.where((p) => p.isOpen).map((p) => p.port).toSet();
      final isCamera  = _isCamera(d);
      final isRouter  = _isRouter(d);
      final isSwitch  = _isSwitch(d);

      void add(String title, String detail, _VulnSeverity sev, {String? badge}) {
        findings.add(_VulnFinding(
          device: d, title: title, detail: detail, severity: sev,
          badge: badge ?? (isCamera ? 'CAMERA' : isRouter ? 'ROUTER' : isSwitch ? 'SWITCH' : null),
        ));
      }

      // ── Generic port-based rules (all devices) ───────────────────────
      if (open.contains(23))   add('Telnet open', 'Port 23: plaintext credentials, trivially intercepted', _VulnSeverity.critical);
      if (open.contains(6379)) add('Redis exposed', 'Port 6379: Redis often has no authentication by default', _VulnSeverity.critical);
      if (open.contains(27017)) add('MongoDB exposed', 'Port 27017: MongoDB may allow unauthenticated access', _VulnSeverity.critical);
      if (open.contains(9200)) add('Elasticsearch exposed', 'Port 9200: may allow unauthenticated data reads', _VulnSeverity.critical);
      if (open.contains(21))   add('FTP open', 'Port 21: credentials sent in plaintext', _VulnSeverity.high);
      if (open.contains(445))  add('SMB exposed', 'Port 445: EternalBlue/ransomware risk if unpatched', _VulnSeverity.high);
      if (open.contains(5900) || open.contains(5901)) add('VNC exposed', 'Port 590x: remote desktop, weak/no auth risk', _VulnSeverity.high);
      if (open.contains(3306)) add('MySQL exposed', 'Port 3306: database reachable on network', _VulnSeverity.high);
      if (open.contains(1433)) add('MSSQL exposed', 'Port 1433: SQL Server reachable on network', _VulnSeverity.high);
      if (open.contains(5432)) add('PostgreSQL exposed', 'Port 5432: database reachable on network', _VulnSeverity.high);
      if (open.contains(3389)) add('RDP exposed', 'Port 3389: brute-force and BlueKeep risk if unpatched', _VulnSeverity.medium);
      if (open.contains(69))   add('TFTP open', 'Port 69: unauthenticated file transfer', _VulnSeverity.medium);
      if (open.contains(135))  add('RPC exposed', 'Port 135: MSRPC attack surface', _VulnSeverity.medium);
      if (open.contains(139))  add('NetBIOS open', 'Port 139: legacy NetBIOS SMB', _VulnSeverity.medium);
      if (open.contains(80) && !open.contains(443)) add('HTTP only', 'Port 80 with no HTTPS — traffic is unencrypted', _VulnSeverity.medium);
      if (open.contains(4444) || open.contains(4445)) add('Suspicious port', 'Port 444x: often used by malware/reverse shells', _VulnSeverity.low);

      // ── SNMP active probe (routers, switches, cameras) ───────────────
      if (open.contains(161)) {
        final snmpOpen = await _snmpPublic(d.ip);
        if (snmpOpen) {
          add('SNMP default community', 'Responded to SNMP "public" community — device info accessible without credentials', _VulnSeverity.high, badge: isCamera ? 'CAMERA' : isRouter ? 'ROUTER' : isSwitch ? 'SWITCH' : null);
        } else {
          add('SNMP port open', 'Port 161 open — verify community string is not "public" or "private"', _VulnSeverity.medium);
        }
      }

      // ── Camera-specific checks ────────────────────────────────────────
      if (isCamera) {
        // RTSP unauthenticated stream
        if (open.contains(554)) {
          final noAuth = await _rtspNoAuth(d.ip);
          if (noAuth) {
            add('RTSP stream open (no auth)', 'Camera RTSP feed accessible without credentials — live video exposed', _VulnSeverity.critical, badge: 'CAMERA');
          } else {
            add('RTSP requires auth', 'Port 554 open, RTSP requests authentication ✓', _VulnSeverity.low, badge: 'CAMERA');
          }
        }

        // HTTP management interface
        for (final port in [80, 8080, 8000]) {
          if (!open.contains(port)) continue;
          final res = await _httpGet(d.ip, port);
          if (res == null) continue;
          final (code, server, body) = res;
          final bodyL = body.toLowerCase();
          final hasLogin = bodyL.contains('login') || bodyL.contains('password') ||
              bodyL.contains('username') || code == 401 || code == 302;

          if (code == 200 && !hasLogin) {
            add('Camera web UI — no login', 'HTTP $port returned 200 without login page — management interface may be open', _VulnSeverity.critical, badge: 'CAMERA');
          }
          // Hikvision default path check
          if (server.toLowerCase().contains('hikvision') ||
              bodyL.contains('hikvision') || bodyL.contains('webs erver')) {
            add('Hikvision device detected', 'Hikvision cameras (CVE-2021-36260) — update firmware immediately if version < V5.5.800', _VulnSeverity.high, badge: 'CAMERA');
          }
          // Dahua check
          if (server.toLowerCase().contains('dahua') || bodyL.contains('dahua') ||
              bodyL.contains('/RPC2') || open.contains(37777)) {
            add('Dahua device detected', 'Dahua cameras (CVE-2021-33044/33045) — check firmware version and disable P2P if unused', _VulnSeverity.high, badge: 'CAMERA');
          }
        }

        // Dahua SDK port
        if (open.contains(37777)) {
          add('Dahua SDK port open', 'Port 37777: Dahua proprietary protocol — restrict to trusted IPs', _VulnSeverity.high, badge: 'CAMERA');
        }
        // Hikvision SDK port
        if (open.contains(8000)) {
          add('Hikvision SDK port', 'Port 8000: Hikvision ISAPI/SDK — limit to trusted IPs only', _VulnSeverity.medium, badge: 'CAMERA');
        }
        // Telnet on camera is especially dangerous
        if (open.contains(23)) {
          add('Camera Telnet root shell', 'Telnet on a camera often gives unauthenticated root shell access', _VulnSeverity.critical, badge: 'CAMERA');
        }
      }

      // ── Router/Switch-specific checks ────────────────────────────────
      if (isRouter || isSwitch) {
        final label = isRouter ? 'ROUTER' : 'SWITCH';

        // HTTP management
        for (final port in [80, 8080, 8443, 443]) {
          if (!open.contains(port)) continue;
          final https = port == 443 || port == 8443;
          final res = await _httpGet(d.ip, port, https: https);
          if (res == null) continue;
          final (code, server, body) = res;
          final bodyL = body.toLowerCase();

          if (code == 200 && !bodyL.contains('login') && !bodyL.contains('password') &&
              !bodyL.contains('username') && body.isNotEmpty) {
            add('$label web UI — no login', 'HTTP $port returned 200 without login page — management may be unprotected', _VulnSeverity.critical, badge: label);
          }
          // MikroTik
          if (bodyL.contains('mikrotik') || bodyL.contains('routeros')) {
            if (open.contains(23)) add('MikroTik Telnet open', 'MikroTik with Telnet: disable Telnet, use SSH + strong password (CVE-2018-14847)', _VulnSeverity.critical, badge: label);
          }
          // Ubiquiti
          if (bodyL.contains('ubiquiti') || bodyL.contains('unifi') || server.toLowerCase().contains('lighttpd')) {
            if (open.contains(22)) add('Ubiquiti SSH default creds risk', 'Ubiquiti devices: verify SSH password is not default "ubnt/ubnt"', _VulnSeverity.high, badge: label);
          }
          // Cisco
          if (bodyL.contains('cisco') || server.toLowerCase().contains('cisco')) {
            add('Cisco device — verify IOS version', 'Cisco: check for CVE-2018-0171 (Smart Install) if port 4786 open', _VulnSeverity.medium, badge: label);
          }
        }

        // Cisco Smart Install
        if (open.contains(4786)) {
          add('Cisco Smart Install exposed', 'Port 4786 (CVE-2018-0171): remote unauthenticated code execution — disable Smart Install', _VulnSeverity.critical, badge: label);
        }
        // MikroTik Winbox
        if (open.contains(8291)) {
          add('MikroTik Winbox exposed', 'Port 8291 (CVE-2018-14847): credential disclosure — update RouterOS, restrict access', _VulnSeverity.high, badge: label);
        }
        // Telnet on router
        if (open.contains(23)) {
          add('$label Telnet open', 'Telnet gives plaintext CLI access — disable and use SSH only', _VulnSeverity.critical, badge: label);
        }
        // HTTP-only management
        if (open.contains(80) && !open.contains(443)) {
          add('$label HTTP management (no HTTPS)', 'Management page served over HTTP — credentials visible on network', _VulnSeverity.high, badge: label);
        }
      }
    }));

    // Sort: critical first, then high, medium, low; deduplicate same title+ip
    final seen = <String>{};
    final deduped = findings.where((f) {
      final key = '${f.device.ip}|${f.title}';
      return seen.add(key);
    }).toList()
      ..sort((a, b) => a.severity.index.compareTo(b.severity.index));

    if (!mounted) return;
    setState(() => _vulnScanning = false);
    showDialog(
      context: context,
      builder: (_) => _VulnScanDialog(findings: deduped, total: online.length),
    );
  }

  Future<void> _exportCsv(List<Device> devices) async {
    final buf = StringBuffer();
    buf.writeln('Name,IP,Status,Latency (ms),MAC,Hostname,Manufacturer,Open Ports,Last Seen');
    for (final d in devices) {
      final openPorts = d.ports.where((p) => p.isOpen).map((p) => p.port).join(' ');
      final lastSeen = d.lastSeen?.toLocal().toString().split('.').first ?? '';
      String csv(String? s) {
        if (s == null || s.isEmpty) return '';
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }
      buf.writeln([
        csv(d.name), csv(d.ip), csv(d.statusLabel),
        d.latencyMs?.toStringAsFixed(1) ?? '',
        csv(d.macAddress), csv(d.hostname), csv(d.manufacturer),
        csv(openPorts), csv(lastSeen),
      ].join(','));
    }

    final dir = Directory(
        '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.'}'
        '\\Documents');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateTime.now().toString().replaceAll(RegExp(r'[: ]'), '-').split('.').first;
    final file = File('${dir.path}\\UnifyNetMonitor_Devices_$ts.csv');
    await file.writeAsString(buf.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported to ${file.path}'),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF111927),
        action: SnackBarAction(
          label: 'Open Folder',
          textColor: const Color(0xFF00D4FF),
          onPressed: () => Process.run('explorer.exe', [dir.path]),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DeviceManager>();
    final all = dm.devices.toList()
      ..sort((a, b) {
        // online first, then by latency
        if (a.status == DeviceStatus.online && b.status != DeviceStatus.online) return -1;
        if (b.status == DeviceStatus.online && a.status != DeviceStatus.online) return 1;
        return (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999);
      });
    final displayed = _showAll ? all : all.where((d) => d.status == DeviceStatus.online).toList();
    final onlineCount = all.where((d) => d.status == DeviceStatus.online).length;
    final rdpDevices = all.where((d) =>
        d.ports.any((p) => p.port == 3389 && p.isOpen)).toList();
    final sshDevices = all.where((d) =>
        d.ports.any((p) => (p.port == 22 || p.port == 23) && p.isOpen)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MonitorHeader(dm: dm),
      Expanded(
        child: dm.devices.isEmpty && !dm.isScanning
            ? const _EmptyState()
            : Padding(
                padding: const EdgeInsets.all(12),
                child: _Panel(
                  title: _showAll ? 'All Devices' : 'Active Devices',
                  count: _showAll ? all.length : onlineCount,
                  accent: const Color(0xFF00FF88), icon: Icons.wifi,
                  isEmpty: displayed.isEmpty,
                  emptyMsg: dm.isScanning ? 'Scanning…'
                      : 'No active devices.\nClick Scan Network to discover.',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // ── RDP Users ──────────────────────────────────────────
                    _ToolbarBtn(
                      label: _rdpQuerying ? 'Querying…'
                          : 'RDP Users${rdpDevices.isNotEmpty ? " (${rdpDevices.length})" : ""}',
                      icon: Icons.desktop_windows,
                      color: const Color(0xFFAB6BFF),
                      busy: _rdpQuerying,
                      onTap: rdpDevices.isEmpty || _rdpQuerying ? null
                          : () => _showUserInfo(context, rdpDevices),
                    ),
                    const SizedBox(width: 6),
                    // ── SSH Banners ─────────────────────────────────────────
                    _ToolbarBtn(
                      label: _sshQuerying ? 'Scanning…'
                          : 'SSH Banners${sshDevices.isNotEmpty ? " (${sshDevices.length})" : ""}',
                      icon: Icons.terminal,
                      color: const Color(0xFF4ECDC4),
                      busy: _sshQuerying,
                      onTap: sshDevices.isEmpty || _sshQuerying ? null
                          : () => _showSshBanners(context, sshDevices),
                    ),
                    const SizedBox(width: 6),
                    // ── Vulnerability Scan ──────────────────────────────────
                    _ToolbarBtn(
                      label: _vulnScanning ? 'Scanning…' : 'Vuln Scan',
                      icon: Icons.security,
                      color: const Color(0xFFFF6B6B),
                      busy: _vulnScanning,
                      onTap: all.isEmpty || _vulnScanning ? null
                          : () => _runVulnScan(context, all),
                    ),
                    const SizedBox(width: 8),
                    // Show all toggle
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _showAll = !_showAll),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showAll
                              ? const Color(0xFF00D4FF).withValues(alpha: 0.15)
                              : const Color(0xFF1E2D45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _showAll
                                ? const Color(0xFF00D4FF).withValues(alpha: 0.4)
                                : const Color(0xFF2A3F5F),
                          ),
                        ),
                        child: Text(
                          _showAll ? 'Online only' : 'Show all',
                          style: TextStyle(
                            color: _showAll ? const Color(0xFF00D4FF) : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Export CSV
                    if (all.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _exportCsv(_showAll ? all : displayed),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2D45),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2A3F5F)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.download, color: Colors.white54, size: 13),
                            SizedBox(width: 5),
                            Text('Export CSV',
                                style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ]),
                        ),
                      ),
                  ]),
                  child: _DeviceTable(devices: displayed, showLatency: true),
                ),
              ),
      ),
    ]);
  }
}


class _MonitorHeader extends StatelessWidget {
  const _MonitorHeader({required this.dm});
  final DeviceManager dm;

  String _ago(DateTime? dt) {
    if (dt == null) return 'never';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final lastChecked = context.watch<DeviceManager>().devices
        .map((d) => d.lastChecked).whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
      child: Row(children: [
        const Text('Device Monitor', style: TextStyle(color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (dm.isScanning)
          Row(children: [
            const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFF00D4FF))),
            const SizedBox(width: 8),
            Text('Scanning ${dm.scanProgress}/${dm.scanTotal}',
                style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
          ])
        else if (lastChecked != null)
          Text('Last scan: ${_ago(lastChecked)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.radar, size: 64,
          color: const Color(0xFF00D4FF).withOpacity(0.2)),
      const SizedBox(height: 20),
      const Text('No devices yet', style: TextStyle(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Click "Scan Network" in the sidebar\nto discover devices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6)),
    ]),
  );
}

// ─── Panel ─────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.count, required this.accent,
    required this.icon, required this.child,
    required this.isEmpty, required this.emptyMsg, this.trailing});

  final String title, emptyMsg;
  final int count;
  final Color accent;
  final IconData icon;
  final Widget child;
  final bool isEmpty;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF111827), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2D45))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: accent.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            border: Border(bottom: BorderSide(color: accent.withOpacity(0.15)))),
        child: Row(children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 7),
          Text(title, style: TextStyle(color: accent, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const Spacer(),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: TextStyle(color: accent, fontSize: 10,
                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
        ]),
      ),
      Expanded(
        child: isEmpty
            ? Center(child: Text(emptyMsg, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24,
                    fontSize: 12, height: 1.6)))
            : child,
      ),
    ]),
  );
}

// ─── Device Table ──────────────────────────────────────────────────────────

class _DeviceTable extends StatelessWidget {
  const _DeviceTable({required this.devices, required this.showLatency});
  final List<Device> devices;
  final bool showLatency;

  @override
  Widget build(BuildContext context) => Column(children: [
    _TableHeader(showLatency: showLatency),
    Expanded(child: ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, color: Color(0xFF181F2E), indent: 12, endIndent: 12),
      itemBuilder: (_, i) =>
          _DeviceRow(device: devices[i], showLatency: showLatency),
    )),
  ]);
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.showLatency});
  final bool showLatency;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
    child: Row(children: [
      const SizedBox(width: 14),
      const Expanded(flex: 5, child: _Hdr('DEVICE / IP')),
      const Expanded(flex: 4, child: _Hdr('HOSTNAME / MAC')),
      const Expanded(flex: 3, child: _Hdr('OPEN PORTS')),
      SizedBox(width: 76,
          child: _Hdr(showLatency ? 'LATENCY' : 'LAST SEEN', right: true)),
    ]),
  );
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.text, {this.right = false});
  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: Colors.white24, fontSize: 9,
          letterSpacing: 0.7, fontWeight: FontWeight.w600));
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.showLatency});
  final Device device;
  final bool showLatency;

  Color get _dotColor => switch (device.status) {
    DeviceStatus.online   => const Color(0xFF00FF88),
    DeviceStatus.offline  => const Color(0xFFFF4466),
    DeviceStatus.checking => const Color(0xFFFFAA00),
    DeviceStatus.unknown  => Colors.white24,
  };

  Color get _latencyColor {
    final ms = device.latencyMs;
    if (ms == null) return Colors.white38;
    if (ms < 10) return const Color(0xFF00FF88);
    if (ms < 50) return const Color(0xFF80FF44);
    if (ms < 150) return const Color(0xFFFFAA00);
    return const Color(0xFFFF4466);
  }

  String _ago(DateTime? dt) {
    if (dt == null) return '—';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final openPorts = device.ports.where((p) => p.isOpen).toList();
    final name = device.manufacturer != null &&
            (device.name.startsWith('Device ') ||
                device.name.contains(device.ip.split('.').last))
        ? '${device.manufacturer} (${device.ip.split('.').last})'
        : device.name;

    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DeviceDetailScreen(deviceIp: device.ip))),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Status dot
        Container(width: 7, height: 7,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle,
                boxShadow: device.status == DeviceStatus.online
                    ? [BoxShadow(color: _dotColor.withOpacity(0.5), blurRadius: 4)]
                    : null)),
        const SizedBox(width: 7),

        // Name + IP
        Expanded(flex: 5, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
          Text(device.ip, style: const TextStyle(color: Colors.white38,
              fontSize: 10, fontFamily: 'monospace')),
        ])),

        // Hostname + MAC
        Expanded(flex: 4, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.hostname ?? '—', style: const TextStyle(
              color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
          if (device.macAddress != null)
            Text(device.macAddress!, style: const TextStyle(
                color: Colors.white24, fontSize: 9, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis)
          else
            const Text('—', style: TextStyle(color: Colors.white24, fontSize: 9)),
        ])),

        // Open ports
        Expanded(flex: 3, child: openPorts.isEmpty
            ? const Text('—', style: TextStyle(color: Colors.white24, fontSize: 10))
            : Wrap(spacing: 3, runSpacing: 3, children: [
                for (final p in openPorts.take(5))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.25))),
                    child: Text(p.port.toString(),
                        style: const TextStyle(color: Color(0xFF00D4FF),
                            fontSize: 9, fontFamily: 'monospace')),
                  ),
                if (openPorts.length > 5)
                  Text('+${openPorts.length - 5}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 9)),
              ])),

        // Latency / Last seen
        SizedBox(width: 76, child: Text(
          showLatency ? device.latencyLabel : _ago(device.lastSeen),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: showLatency ? _latencyColor : Colors.white38,
            fontSize: 11, fontFamily: 'monospace',
            fontWeight: showLatency ? FontWeight.w600 : FontWeight.normal),
        )),
      ]),
    ));
  }
}

// ─── RDP User Result ───────────────────────────────────────────────────────

class _RdpUserResult {
  final String ip;
  final String name;
  final String? computerName;
  final List<String> usernames;
  final List<String> localUsers;
  final String? netUserError;
  final String? banner;
  final String portLabel;
  final String? error;

  const _RdpUserResult({
    required this.ip,
    required this.name,
    required this.computerName,
    required this.usernames,
    this.localUsers = const [],
    this.netUserError,
    this.banner,
    this.portLabel = 'RDP',
    required this.error,
  });
}

class _RdpUsersDialog extends StatelessWidget {
  const _RdpUsersDialog({required this.results});
  final List<_RdpUserResult> results;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111927),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E2D45))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Icon(Icons.person_search, color: Color(0xFFAB6BFF), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RDP Usernames', style: TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Logged-in users + local accounts via net user',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          // Results list
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFF1A2438)),
              itemBuilder: (_, i) {
                final r = results[i];
                final hasUser = r.usernames.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Status dot
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasUser
                            ? const Color(0xFF00FF88)
                            : r.error != null
                                ? const Color(0xFF6B7280)
                                : const Color(0xFFFFAA00),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Text(r.name,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Text(r.ip,
                              style: const TextStyle(color: Colors.white38,
                                  fontSize: 11, fontFamily: 'monospace')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2D45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(r.portLabel,
                                style: const TextStyle(color: Color(0xFF4A6480),
                                    fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        if (r.computerName != null) ...[
                          const SizedBox(height: 3),
                          Text('Computer: ${r.computerName}',
                              style: const TextStyle(color: Color(0xFF7A96B8),
                                  fontSize: 11)),
                        ],
                        const SizedBox(height: 6),
                        if (hasUser)
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final u in r.usernames)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAB6BFF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFAB6BFF).withValues(alpha: 0.35)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.person, color: Color(0xFFAB6BFF), size: 12),
                                  const SizedBox(width: 5),
                                  Text(u,
                                      style: const TextStyle(
                                          color: Color(0xFFAB6BFF),
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: u));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Username copied'),
                                            duration: Duration(seconds: 2),
                                            backgroundColor: Color(0xFF111927)));
                                    },
                                    child: const Icon(Icons.copy,
                                        color: Color(0xFF4A6480), size: 12),
                                  ),
                                ]),
                              ),
                          ]),
                        if (r.localUsers.isNotEmpty) ...[
                          if (hasUser) const SizedBox(height: 8),
                          Text('Local accounts',
                              style: const TextStyle(
                                  color: Color(0xFF4ECDC4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final u in r.localUsers)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.30)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.manage_accounts,
                                      color: Color(0xFF4ECDC4), size: 11),
                                  const SizedBox(width: 4),
                                  Text(u,
                                      style: const TextStyle(
                                          color: Color(0xFF4ECDC4),
                                          fontSize: 11,
                                          fontFamily: 'monospace')),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: u));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Username copied'),
                                            duration: Duration(seconds: 2),
                                            backgroundColor: Color(0xFF111927)));
                                    },
                                    child: const Icon(Icons.copy,
                                        color: Color(0xFF2A5A58), size: 11),
                                  ),
                                ]),
                              ),
                          ]),
                        ],
                        if (r.banner != null) ...[
                          if (hasUser || r.localUsers.isNotEmpty) const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1321),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E2D45)),
                            ),
                            child: Text(r.banner!,
                                style: const TextStyle(color: Color(0xFF7A96B8),
                                    fontSize: 10, fontFamily: 'monospace')),
                          ),
                        ],
                        if (!hasUser && r.banner == null && r.localUsers.isEmpty)
                          Text(r.error ?? 'No info retrieved',
                              style: const TextStyle(
                                  color: Color(0xFF4A6480), fontSize: 11))
                        else if (r.localUsers.isEmpty && r.netUserError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(r.netUserError!,
                                style: const TextStyle(
                                    color: Color(0xFF2A5A58), fontSize: 10,
                                    fontFamily: 'monospace')),
                          ),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
          // Footer note
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E2D45)))),
            child: const Text(
              'Purple = logged-in user (RDP/NBNS). Cyan = local accounts (net user). '
              'SSH/Telnet show server banner.',
              style: TextStyle(color: Color(0xFF2A3F5F), fontSize: 10),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Toolbar button helper ─────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.label, required this.icon, required this.color,
    required this.busy, required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onTap == null ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: onTap == null ? 0.15 : 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        busy
            ? SizedBox(width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
            : Icon(icon, color: onTap == null ? color.withValues(alpha: 0.35) : color, size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: onTap == null ? color.withValues(alpha: 0.35) : color,
                fontSize: 11)),
      ]),
    ),
  );
}

// ─── SSH Banner Result & Dialog ────────────────────────────────────────────

class _SshBannerResult {
  final String ip;
  final String name;
  final int port;
  final String? banner;
  final String? os;
  const _SshBannerResult({required this.ip, required this.name,
      required this.port, this.banner, this.os});
}

class _SshBannersDialog extends StatelessWidget {
  const _SshBannersDialog({required this.results});
  final List<_SshBannerResult> results;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111927),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E2D45))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Icon(Icons.terminal, color: Color(0xFF4ECDC4), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SSH / Telnet Banners',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Server version banners from SSH (22) and Telnet (23) devices',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1A2438)),
              itemBuilder: (_, i) {
                final r = results[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.circle, color: Color(0xFF4ECDC4), size: 8),
                      const SizedBox(width: 8),
                      Text(r.name, style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text(r.ip, style: const TextStyle(color: Colors.white38,
                          fontSize: 11, fontFamily: 'monospace')),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFF1E2D45),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(r.port == 22 ? 'SSH' : 'Telnet',
                            style: const TextStyle(color: Color(0xFF4ECDC4),
                                fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                      if (r.os != null) ...[
                        const SizedBox(width: 6),
                        Text(r.os!, style: const TextStyle(color: Color(0xFF7A96B8), fontSize: 11)),
                      ],
                    ]),
                    if (r.banner != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF0D1321),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1E2D45))),
                        child: Text(r.banner!, style: const TextStyle(
                            color: Color(0xFF4ECDC4), fontSize: 10, fontFamily: 'monospace')),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 16),
                        child: Text('No banner received', style: TextStyle(
                            color: Color(0xFF4A6480), fontSize: 11)),
                      ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Vulnerability Scan ─────────────────────────────────────────────────────

enum _VulnSeverity { critical, high, medium, low }

class _VulnFinding {
  final Device device;
  final String title;
  final String detail;
  final _VulnSeverity severity;
  final String? badge; // e.g. 'CAMERA', 'ROUTER', 'SWITCH'
  const _VulnFinding({required this.device, required this.title,
      required this.detail, required this.severity, this.badge});
}

class _VulnScanDialog extends StatefulWidget {
  const _VulnScanDialog({required this.findings, required this.total});
  final List<_VulnFinding> findings;
  final int total;

  @override
  State<_VulnScanDialog> createState() => _VulnScanDialogState();
}

class _VulnScanDialogState extends State<_VulnScanDialog> {
  _VulnSeverity? _filter;
  String? _badgeFilter; // 'CAMERA', 'ROUTER', 'SWITCH', or null = all

  Color _sevColor(_VulnSeverity s) => switch (s) {
    _VulnSeverity.critical => const Color(0xFFFF4757),
    _VulnSeverity.high     => const Color(0xFFFF8C42),
    _VulnSeverity.medium   => const Color(0xFFFFD93D),
    _VulnSeverity.low      => const Color(0xFF6BCB77),
  };

  String _sevLabel(_VulnSeverity s) => switch (s) {
    _VulnSeverity.critical => 'CRITICAL',
    _VulnSeverity.high     => 'HIGH',
    _VulnSeverity.medium   => 'MEDIUM',
    _VulnSeverity.low      => 'LOW',
  };

  Widget _filterChip(String label, Color color, bool active, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: active ? 0.6 : 0.3)),
        ),
        child: Text(label,
            style: TextStyle(color: active ? color : color.withValues(alpha: 0.6),
                fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );

  @override
  Widget build(BuildContext context) {
    var shown = widget.findings;
    if (_filter != null) shown = shown.where((f) => f.severity == _filter).toList();
    if (_badgeFilter != null) shown = shown.where((f) => f.badge == _badgeFilter).toList();

    final counts = {
      for (final s in _VulnSeverity.values)
        s: widget.findings.where((f) => f.severity == s).length,
    };

    return Dialog(
      backgroundColor: const Color(0xFF111927),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E2D45))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Icon(Icons.security, color: Color(0xFFFF6B6B), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vulnerability Report — ${widget.findings.length} finding${widget.findings.length == 1 ? "" : "s"}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Scanned ${widget.total} online device${widget.total == 1 ? "" : "s"} for exposed services and risks',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          // Filter chips — severity + device type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Severity row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('All', Colors.white54, _filter == null && _badgeFilter == null,
                      () => setState(() { _filter = null; _badgeFilter = null; })),
                  for (final s in _VulnSeverity.values)
                    if (counts[s]! > 0)
                      _filterChip('${_sevLabel(s)} (${counts[s]})', _sevColor(s), _filter == s,
                          () => setState(() => _filter = _filter == s ? null : s)),
                ]),
              ),
              // Device type row
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final badge in ['CAMERA', 'ROUTER', 'SWITCH'])
                    if (widget.findings.any((f) => f.badge == badge))
                      _filterChip(badge,
                          badge == 'CAMERA' ? const Color(0xFF4ECDC4)
                              : badge == 'ROUTER' ? const Color(0xFFFFAA00)
                              : const Color(0xFF6B7FFF),
                          _badgeFilter == badge,
                          () => setState(() => _badgeFilter = _badgeFilter == badge ? null : badge)),
                ]),
              ),
            ]),
          ),
          // Findings list
          Flexible(
            child: widget.findings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_user, color: Color(0xFF00FF88), size: 40),
                        SizedBox(height: 12),
                        Text('No vulnerabilities detected',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 6),
                        Text('Based on open ports and known risky services.',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1A2438)),
                    itemBuilder: (_, i) {
                      final f = shown[i];
                      final c = _sevColor(f.severity);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: c.withValues(alpha: 0.4)),
                              ),
                              child: Text(_sevLabel(f.severity),
                                  style: TextStyle(color: c, fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (f.badge != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2D45),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(f.badge!,
                                    style: TextStyle(
                                        color: f.badge == 'CAMERA'
                                            ? const Color(0xFF4ECDC4)
                                            : f.badge == 'ROUTER'
                                                ? const Color(0xFFFFAA00)
                                                : const Color(0xFF6B7FFF),
                                        fontSize: 8, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(f.title, style: const TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text('${f.device.name}  ${f.device.ip}',
                                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ]),
                              const SizedBox(height: 3),
                              Text(f.detail, style: const TextStyle(
                                  color: Color(0xFF7A96B8), fontSize: 11)),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E2D45)))),
            child: const Text(
              'Combines port-based rules with active probes (RTSP auth, SNMP community, HTTP login). '
              'Does not exploit. Patch devices and restrict firewall access for flagged services.',
              style: TextStyle(color: Color(0xFF2A3F5F), fontSize: 10),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── SSH Launcher ──────────────────────────────────────────────────────────

class _SshLauncher extends StatefulWidget {
  const _SshLauncher();

  @override
  State<_SshLauncher> createState() => _SshLauncherState();
}

class _SshLauncherState extends State<_SshLauncher> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'root');
  final _portCtrl = TextEditingController(text: '22');
  bool _launched = false;
  String? _host;
  int _port = 22;

  @override
  void dispose() {
    _hostCtrl.dispose(); _userCtrl.dispose(); _portCtrl.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    setState(() { _launched = true; _host = host;
      _port = int.tryParse(_portCtrl.text) ?? 22; });
  }

  @override
  Widget build(BuildContext context) {
    if (_launched && _host != null) {
      return SshScreen(host: _host!, port: _port);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SSH Terminal')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.3))),
                  child: const Icon(Icons.terminal,
                      color: Color(0xFF00D4FF), size: 26)),
                const SizedBox(width: 14),
                const Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('SSH Terminal', style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Connect to a remote host',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              ]),
              const SizedBox(height: 28),
              _F('Host / IP', _hostCtrl, Icons.computer, '192.168.1.100',
                  onSubmit: _connect),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _F('Username', _userCtrl,
                    Icons.person_outline, 'root')),
                const SizedBox(width: 12),
                Expanded(child: _F('Port', _portCtrl,
                    Icons.settings_ethernet, '22',
                    keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: _connect,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: const Color(0xFF0A0E1A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.login, size: 17),
                  label: const Text('Connect',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                for (final h in ['192.168.1.1', '10.0.0.1', 'localhost'])
                  ActionChip(
                    label: Text(h, style: const TextStyle(
                        color: Color(0xFF00D4FF), fontSize: 11,
                        fontFamily: 'monospace')),
                    backgroundColor: const Color(0xFF00D4FF).withOpacity(0.08),
                    side: const BorderSide(
                        color: Color(0xFF00D4FF), width: 0.5),
                    onPressed: () { _hostCtrl.text = h; _connect(); },
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── In-app Update Dialog ──────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.info,
    required this.ignoreCount,
    required this.maxIgnores,
    required this.onIgnore,
  });
  final UpdateInfo info;
  final int ignoreCount;
  final int maxIgnores;
  final VoidCallback onIgnore;
  @override State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;
  bool _cancelRequested = false;
  bool _uacTimeout = false;
  bool _defenderBlocked = false;

  bool get _forceInstall => widget.ignoreCount >= widget.maxIgnores;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    _cancelRequested = false;
    _uacTimeout = false;
    setState(() { _phase = _Phase.downloading; _progress = 0; _error = null; _defenderBlocked = false; });
    String? path;
    try {
      path = await UpdateService.downloadUpdate(
        widget.info.downloadUrl,
        (p) { if (mounted) setState(() => _progress = p); },
      );
      if (!mounted || _cancelRequested) {
        if (path != null) File(path).deleteSync(recursive: false);
        return;
      }
      setState(() { _phase = _Phase.installing; _uacTimeout = false; });
      await UpdateService.runInstaller(path);
      await Future.delayed(const Duration(seconds: 20));
      if (mounted) setState(() => _uacTimeout = true);
    } catch (e) {
      final msg = e.toString();
      final isDefender = msg.toLowerCase().contains('virus') ||
          msg.toLowerCase().contains('unwanted') ||
          msg.toLowerCase().contains('access is denied');
      if (mounted) setState(() {
        _phase = _Phase.idle;
        _error = isDefender
            ? 'Windows Defender blocked the download.\nTemporarily disable real-time protection and try again.'
            : msg;
        _defenderBlocked = isDefender;
      });
    }
  }

  void _cancel() {
    _cancelRequested = true;
    widget.onIgnore();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1321),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E2D45))),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00D4FF).withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.system_update_alt, color: Color(0xFF00D4FF), size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Update Available', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('v${UpdateService.currentVersion}  →  v${widget.info.latestVersion}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 20),

            if (_phase == _Phase.idle) ...[
              const Text('A new version of Unify Net Monitor is ready to install.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              // Warning when close to forced install
              if (!_forceInstall && widget.ignoreCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'You\'ve skipped this ${widget.ignoreCount}x. '
                      'After ${widget.maxIgnores - widget.ignoreCount} more skip(s), '
                      'it will install automatically.',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                    )),
                  ]),
                ),
              ],
              if (_forceInstall) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Color(0xFFF87171), size: 14),
                    SizedBox(width: 6),
                    Expanded(child: Text(
                      'Update is installing automatically — you\'ve skipped it too many times.',
                      style: TextStyle(color: Color(0xFFF87171), fontSize: 11),
                    )),
                  ]),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: .1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: .3))),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
                if (_defenderBlocked) ...[
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Process.run('cmd', ['/c', 'start', '', 'https://github.com/kiabeak-blip/unify-net-monitor/releases/latest'], runInShell: false);
                      },
                      icon: const Icon(Icons.open_in_browser, size: 15),
                      label: const Text('Open GitHub releases page'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2D45),
                        foregroundColor: const Color(0xFF00D4FF),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )),
                ],
              ],
              const SizedBox(height: 20),
              Row(children: [
                // Hide "Later" once max ignores reached
                if (!_forceInstall)
                  TextButton(
                    onPressed: () {
                      widget.onIgnore();
                      Navigator.pop(context);
                    },
                    child: Text(
                      widget.ignoreCount == 0 ? 'Later' : 'Skip again (${widget.maxIgnores - widget.ignoreCount} left)',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download & Install'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ],

            if (_phase == _Phase.downloading) ...[
              Row(children: [
                const Text('Downloading...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Text('${(_progress * 100).round()}%', style: const TextStyle(color: Color(0xFF00D4FF), fontFamily: 'monospace', fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  color: const Color(0xFF00D4FF),
                  backgroundColor: const Color(0xFF1E2D45))),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight,
                child: TextButton(onPressed: _cancel,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white38)))),
            ],

            if (_phase == _Phase.installing) ...[
              Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF))),
                const SizedBox(width: 12),
                Text(_uacTimeout ? 'Waiting for UAC approval...' : 'Launching installer...',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              if (!_uacTimeout)
                const Text('Click Yes on the UAC prompt to complete the install.',
                    style: TextStyle(color: Colors.white38, fontSize: 11))
              else ...[
                const Text('A permission prompt (UAC) is waiting for your approval.',
                    style: TextStyle(color: Color(0xFFFFCC00), fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Check the taskbar for a flashing shield icon and click Yes.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => exit(0),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF00D4FF))),
                    child: const Text('Close app & approve UAC prompt', style: TextStyle(color: Color(0xFF00D4FF))),
                  )),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

enum _Phase { idle, downloading, installing }

class _F extends StatelessWidget {
  const _F(this.label, this.ctrl, this.icon, this.hint,
      {this.keyboardType, this.onSubmit});
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
        style: const TextStyle(color: Colors.white,
            fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white38, size: 17),
          filled: true, fillColor: const Color(0xFF1A2235),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF00D4FF), width: 1.5)),
        ),
      ),
    ],
  );
}
