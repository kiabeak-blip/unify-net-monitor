import 'package:flutter/material.dart';
import 'arp_screen.dart';
import 'dns_lookup_screen.dart';
import 'nmap_screen.dart';
import 'ping_screen.dart';
import 'qr_screen.dart';
import 'rdp_screen.dart';
import 'ssh_screen.dart';
import 'traceroute_screen.dart';
import 'wifi_analyzer_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionHeader('Network Diagnostics'),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.manage_search,
            color: const Color(0xFFFF4466),
            title: 'Nmap Scanner',
            subtitle: 'Deep port scan, service & OS detection on any target',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NmapScreen())),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.wifi_tethering,
            color: const Color(0xFF00D4FF),
            title: 'Ping',
            subtitle: 'Test connectivity & measure latency to any host',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PingScreen())),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.route,
            color: const Color(0xFF00D4FF),
            title: 'Traceroute',
            subtitle: 'Trace the network path hop-by-hop to a destination',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TracerouteScreen())),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.dns_outlined,
            color: const Color(0xFFFFAA00),
            title: 'DNS Lookup',
            subtitle: 'Resolve hostnames and reverse-lookup IP addresses',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DnsLookupScreen())),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.hub_outlined,
            color: const Color(0xFF00FF88),
            title: 'ARP Table',
            subtitle: 'View neighboring devices from the ARP cache',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArpScreen())),
          ),
          const SizedBox(height: 20),
          _SectionHeader('WiFi Analysis'),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.wifi_tethering,
            color: const Color(0xFFAA00FF),
            title: 'WiFi Analyzer',
            subtitle: 'Signal strength, band, encryption & rogue AP detection',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WifiAnalyzerScreen())),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.qr_code,
            color: const Color(0xFF00D4FF),
            title: 'QR Utilities',
            subtitle: 'Generate WiFi QR codes to share your network',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QrScreen())),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Remote Access'),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.terminal,
            color: const Color(0xFF00FF88),
            title: 'SSH Client',
            subtitle: 'Connect to remote devices via Secure Shell',
            onTap: () => _showSshDialog(context),
          ),
          const SizedBox(height: 10),
          _ToolCard(
            icon: Icons.desktop_windows_outlined,
            color: const Color(0xFF00D4FF),
            title: 'RDP Client',
            subtitle: 'Launch Remote Desktop connections (Windows)',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RdpScreen())),
          ),
        ],
      ),
    );
  }

  void _showSshDialog(BuildContext context) {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Row(children: [
          Icon(Icons.terminal, color: Color(0xFF00FF88), size: 20),
          SizedBox(width: 10),
          Text('SSH Connect'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Host / IP',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: hostCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '192.168.1.1',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0A0E1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF00FF88), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Port',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0A0E1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF00FF88), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Connect',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              final host = hostCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 22;
              if (host.isEmpty) return;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SshScreen(host: host, port: port)),
              );
            },
          ),
        ],
      ),
    ).whenComplete(() {
      hostCtrl.dispose();
      portCtrl.dispose();
    });
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

// ── Tool card ─────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2235),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
