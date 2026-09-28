import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // App identity card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/icon.jpeg',
                      width: 80, height: 80,
                      errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.radar,
                                color: Color(0xFF00D4FF), size: 40),
                          )),
                ),
                const SizedBox(height: 14),
                const Text('HN-Network',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Version 1.0.0',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Professional Network Monitor',
                    style: TextStyle(
                        color: Color(0xFF00D4FF), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionHeader('Features'),
          const SizedBox(height: 10),
          _FeatureCard(children: [
            _FeatureRow(Icons.radar, const Color(0xFF00D4FF), 'LAN Scanner',
                'Discover all devices on your network subnet'),
            _FeatureRow(Icons.wifi_tethering, const Color(0xFF00D4FF), 'Ping Tool',
                'Real-time ICMP ping with latency graphs'),
            _FeatureRow(Icons.route, const Color(0xFF00D4FF), 'Traceroute',
                'Trace network hops to any destination'),
            _FeatureRow(Icons.dns_outlined, const Color(0xFFFFAA00), 'DNS Lookup',
                'Forward and reverse DNS resolution'),
            _FeatureRow(Icons.hub_outlined, const Color(0xFF00FF88), 'ARP Table',
                'View neighboring devices from ARP cache'),
            _FeatureRow(Icons.terminal, const Color(0xFF00FF88), 'SSH Client',
                'Built-in interactive SSH terminal'),
            _FeatureRow(Icons.desktop_windows_outlined, const Color(0xFF00D4FF),
                'RDP Client', 'Launch Remote Desktop sessions (Windows)'),
            _FeatureRow(Icons.info_outline, const Color(0xFFFFAA00), 'Network Info',
                'Gateway, DNS, IP, SSID and more',
                isLast: true),
          ]),
          const SizedBox(height: 16),

          _SectionHeader('Platform'),
          const SizedBox(height: 10),
          _FeatureCard(children: [
            _FeatureRow(Icons.desktop_windows, const Color(0xFF00D4FF),
                'Windows', 'Full feature support'),
            _FeatureRow(Icons.android, const Color(0xFF00FF88), 'Android',
                'Core tools — ARP, Ping, Traceroute, DNS, SSH',
                isLast: true),
          ]),
        ],
      ),
    );
  }
}

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

class _FeatureCard extends StatelessWidget {
  final List<Widget> children;
  const _FeatureCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLast;

  const _FeatureRow(this.icon, this.color, this.title, this.subtitle,
      {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
