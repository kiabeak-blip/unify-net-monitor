// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<DeviceManager>(
        builder: (context, manager, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Section(title: 'Auto Refresh', children: [
                _ToggleTile(
                  icon: Icons.autorenew,
                  title: 'Auto-refresh devices',
                  subtitle: 'Periodically check all devices',
                  value: manager.autoRefreshEnabled,
                  onChanged: (v) => manager.setAutoRefresh(v),
                ),
                if (manager.autoRefreshEnabled)
                  _IntervalPicker(manager: manager),
              ]),
              const SizedBox(height: 20),
              _Section(title: 'Notifications', children: [
                _InfoTile(
                  icon: Icons.notifications_outlined,
                  title: 'Device Down Alerts',
                  subtitle: 'Notified when a device goes offline',
                  trailing: const Icon(Icons.check_circle,
                      color: Color(0xFF00FF88), size: 18),
                ),
                _InfoTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Device Recovery Alerts',
                  subtitle: 'Notified when a device comes back online',
                  trailing: const Icon(Icons.check_circle,
                      color: Color(0xFF00FF88), size: 18),
                ),
              ]),
              const SizedBox(height: 20),
              _Section(title: 'About', children: [
                _InfoTile(
                  icon: Icons.info_outline,
                  title: 'NetWatch',
                  subtitle: 'Version 1.0.0',
                ),
                _InfoTile(
                  icon: Icons.security_outlined,
                  title: 'Permissions',
                  subtitle:
                      'Local network access, notifications',
                ),
              ]),
              const SizedBox(height: 20),
              _Section(title: 'Data', children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4466).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_sweep_outlined,
                        color: Color(0xFFFF4466), size: 20),
                  ),
                  title: const Text('Clear all devices',
                      style: TextStyle(
                          color: Color(0xFFFF4466),
                          fontWeight: FontWeight.w500)),
                  subtitle: const Text('Remove all monitored devices',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  onTap: () => _confirmClear(context, manager),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, DeviceManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Clear All Devices'),
        content:
            const Text('This will remove all devices from your list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4466)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ips =
          manager.devices.map((d) => d.ip).toList();
      for (final ip in ips) {
        await manager.removeDevice(ip);
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _InfoTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _IntervalPicker extends StatelessWidget {
  final DeviceManager manager;
  const _IntervalPicker({required this.manager});

  @override
  Widget build(BuildContext context) {
    final options = [15, 30, 60, 120, 300];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Refresh interval',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: options.map((secs) {
              final isSelected = manager.autoRefreshInterval == secs;
              final label = secs < 60
                  ? '${secs}s'
                  : '${secs ~/ 60}m';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => manager.setAutoRefresh(
                    true,
                    intervalSeconds: secs),
                selectedColor:
                    Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFF0A0E1A),
                side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white12),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
