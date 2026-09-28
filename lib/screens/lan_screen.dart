import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';
import '../widgets/device_list_tile.dart';
import '../widgets/scan_progress_bar.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';

class LanScreen extends StatelessWidget {
  const LanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, manager, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LAN'),
            centerTitle: true,
            actions: [
              if (manager.totalCount > 0)
                IconButton(
                  tooltip: 'Add device',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddDeviceScreen())),
                ),
              // Scan button in app bar
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: manager.isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: manager.scanNetwork,
                        child: Text('Scan',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            )),
                      ),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: manager.refreshAllDevices,
            child: CustomScrollView(
              slivers: [
                // Stats row
                SliverToBoxAdapter(
                  child: _StatsRow(manager: manager),
                ),

                // Scan progress
                if (manager.isScanning)
                  SliverToBoxAdapter(
                    child: ScanProgressBar(
                      progress: manager.scanProgress,
                      total: manager.scanTotal,
                    ),
                  ),

                // Device list
                if (manager.devices.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyState(manager: manager),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final device = manager.devices[i];
                          return DeviceListTile(
                            device: device,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeviceDetailScreen(deviceIp: device.ip),
                              ),
                            ),
                            onRefresh: () =>
                                manager.checkSingleDevice(device.ip),
                          );
                        },
                        childCount: manager.devices.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DeviceManager manager;
  const _StatsRow({required this.manager});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: '${manager.totalCount}',
            icon: Icons.devices,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Online',
            value: '${manager.onlineCount}',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF00FF88),
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Offline',
            value: '${manager.offlineCount}',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFFF4466),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DeviceManager manager;
  const _EmptyState({required this.manager});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_find,
              size: 72,
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(0.25)),
          const SizedBox(height: 20),
          Text('No Devices Found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tap Scan to discover devices\non your network',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed:
                manager.isScanning ? null : manager.scanNetwork,
            icon: manager.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar, size: 18),
            label: Text(manager.isScanning ? 'Scanning…' : 'Scan Network'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
