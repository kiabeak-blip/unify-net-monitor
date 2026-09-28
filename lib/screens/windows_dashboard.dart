// lib/screens/windows_dashboard.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  netbios('NetBIOS Scanner', Icons.lan_outlined);

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
    _NavItem.netbios      => const NetBiosScannerScreen(),
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

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (mounted) setState(() { _updateInfo = info; _checking = false; });
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final hasUpdate = _updateInfo?.hasUpdate == true;

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
                  _NavItem.snmp, _NavItem.netbios])
                  _NavTile(item: item, selected: widget.selected == item,
                      onTap: () => widget.onSelect(item)),
              ],
            ),
          ),
          // ── Fixed footer ──
          const Divider(height: 1, color: Color(0xFF1E2D45)),
          // Update button (shown when update available)
          if (hasUpdate)
            InkWell(
              onTap: () => _showUpdateDialog(context, _updateInfo!),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                color: const Color(0xFF00D4FF).withOpacity(0.12),
                child: Row(children: [
                  const Icon(Icons.system_update_alt,
                      color: Color(0xFF00D4FF), size: 13),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                      'Update v${_updateInfo!.latestVersion} available',
                      style: const TextStyle(
                          color: Color(0xFF00D4FF), fontSize: 10,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
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
                  child: Tooltip(
                    message: 'Check for updates',
                    child: Icon(
                      hasUpdate ? Icons.upgrade : Icons.refresh,
                      color: hasUpdate
                          ? const Color(0xFF00D4FF) : Colors.white24,
                      size: 14),
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
  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DeviceManager>();
    final active = dm.devices
        .where((d) => d.status == DeviceStatus.online).toList()
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MonitorHeader(dm: dm),
      Expanded(
        child: dm.devices.isEmpty && !dm.isScanning
            ? const _EmptyState()
            : Padding(
                padding: const EdgeInsets.all(12),
                child: _Panel(
                  title: 'Active Devices', count: active.length,
                  accent: const Color(0xFF00FF88), icon: Icons.wifi,
                  isEmpty: active.isEmpty,
                  emptyMsg: dm.isScanning ? 'Scanning…'
                      : 'No active devices.\nClick Scan Network to discover.',
                  child: _DeviceTable(devices: active, showLatency: true),
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

    return Padding(
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
  const _UpdateDialog({required this.info});
  final UpdateInfo info;
  @override State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;
  bool _cancelRequested = false;

  Future<void> _download() async {
    _cancelRequested = false;
    setState(() { _phase = _Phase.downloading; _progress = 0; _error = null; });
    String? path;
    try {
      path = await UpdateService.downloadUpdate(
        widget.info.downloadUrl,
        (p) { if (mounted) setState(() => _progress = p); },
      );
      if (!mounted || _cancelRequested) {
        // Clean up downloaded file if cancel was requested mid-download
        if (path != null) File(path).deleteSync(recursive: false);
        return;
      }
      setState(() => _phase = _Phase.installing);
      await UpdateService.runInstaller(path);
      // Inno Setup's InitializeSetup() runs taskkill to close this app.
      // Just show "installing" and wait — the installer will kill us.
    } catch (e) {
      if (mounted) setState(() { _phase = _Phase.idle; _error = e.toString(); });
    }
  }

  void _cancel() {
    _cancelRequested = true;
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(.3))),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
              ],
              const SizedBox(height: 20),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('Later', style: TextStyle(color: Colors.white38))),
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
              const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF))),
                SizedBox(width: 12),
                Text('Launching installer...', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              const Text('The installer will open. You can close the app now.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
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
