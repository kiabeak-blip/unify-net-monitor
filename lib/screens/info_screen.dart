import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icon.jpeg',
                width: 28, height: 28,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.radar, color: Theme.of(context).colorScheme.primary, size: 24)),
            const SizedBox(width: 10),
            const Text('HN-Network'),
          ],
        ),
      ),
      body: Consumer<DeviceManager>(
        builder: (context, manager, _) {
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: manager.refreshAllDevices,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Connection status banner
                _ConnectionBanner(manager: manager),
                const SizedBox(height: 16),

                // Connection section
                _SectionHeader(title: 'Connection'),
                _InfoCard(children: [
                  _InfoRow(
                    label: 'Local IP',
                    value: manager.localIP ?? '—',
                    icon: Icons.router_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    copyable: true,
                  ),
                  _InfoRow(
                    label: 'Subnet Mask',
                    value: manager.subnetMask ?? '—',
                    icon: Icons.grid_3x3,
                    color: Colors.white38,
                  ),
                  _InfoRow(
                    label: 'Default Gateway',
                    value: manager.gateway ?? '—',
                    icon: Icons.device_hub,
                    color: const Color(0xFF00FF88),
                    copyable: true,
                  ),
                  _InfoRow(
                    label: 'DNS Servers',
                    value: manager.dnsServers.isEmpty
                        ? '—'
                        : manager.dnsServers.join('\n'),
                    icon: Icons.dns_outlined,
                    color: const Color(0xFFFFAA00),
                    copyable: true,
                  ),
                  _InfoRow(
                    label: 'External IP',
                    value: manager.publicIP ?? 'Fetching…',
                    icon: Icons.public,
                    color: const Color(0xFF00FF88),
                    copyable: true,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),

                // Wi-Fi section
                _SectionHeader(title: 'Wi-Fi Information'),
                _InfoCard(children: [
                  _InfoRow(
                    label: 'Network Connected',
                    value: manager.localIP != null ? 'Yes' : 'No',
                    icon: Icons.wifi,
                    color: manager.localIP != null
                        ? const Color(0xFF00FF88)
                        : const Color(0xFFFF4466),
                    trailing: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: manager.localIP != null
                            ? const Color(0xFF00FF88)
                            : const Color(0xFFFF4466),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  _InfoRow(
                    label: 'SSID',
                    value: _cleanSsid(manager.ssid) ?? '—',
                    icon: Icons.wifi_tethering,
                    color: Theme.of(context).colorScheme.primary,
                    copyable: true,
                  ),
                  _InfoRow(
                    label: 'BSSID',
                    value: manager.bssid ?? '—',
                    icon: Icons.router,
                    color: Colors.white54,
                    copyable: true,
                  ),
                  _InfoRow(
                    label: 'Subnet',
                    value: manager.subnet != null ? '${manager.subnet}.0/24' : '—',
                    icon: Icons.lan_outlined,
                    color: Colors.white54,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),

                // Devices summary
                _SectionHeader(title: 'Network Devices'),
                _InfoCard(children: [
                  _InfoRow(
                    label: 'Total Discovered',
                    value: '${manager.totalCount}',
                    icon: Icons.devices,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _InfoRow(
                    label: 'Online',
                    value: '${manager.onlineCount}',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF00FF88),
                  ),
                  _InfoRow(
                    label: 'Offline',
                    value: '${manager.offlineCount}',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFFF4466),
                    isLast: true,
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _cleanSsid(String? ssid) {
    if (ssid == null) return null;
    // Remove surrounding quotes that some platforms add
    if (ssid.startsWith('"') && ssid.endsWith('"')) {
      return ssid.substring(1, ssid.length - 1);
    }
    return ssid;
  }
}

// ── Connection banner ─────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  final DeviceManager manager;
  const _ConnectionBanner({required this.manager});

  @override
  Widget build(BuildContext context) {
    final connected = manager.localIP != null;
    final color =
        connected ? const Color(0xFF00FF88) : const Color(0xFFFF4466);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Network Connected' : 'No Network',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                if (connected)
                  Text(manager.ssid != null
                      ? 'Connected to ${_cleanSsid(manager.ssid)}'
                      : 'IP: ${manager.localIP}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Icon(connected ? Icons.wifi : Icons.wifi_off, color: color, size: 22),
        ],
      ),
    );
  }

  String? _cleanSsid(String? ssid) {
    if (ssid == null) return null;
    if (ssid.startsWith('"') && ssid.endsWith('"')) {
      return ssid.substring(1, ssid.length - 1);
    }
    return ssid;
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

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

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool copyable;
  final bool isLast;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.copyable = false,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14))
          : BorderRadius.zero,
      onTap: copyable && value != '—'
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Copied $label'),
                duration: const Duration(seconds: 1),
              ));
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: value == '—' || value == 'N/A'
                          ? Colors.white24
                          : Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500)),
            ),
            if (copyable && value != '—') ...[
              const SizedBox(width: 6),
              const Icon(Icons.copy, size: 12, color: Colors.white24),
            ],
          ],
        ),
      ),
    );
  }
}
