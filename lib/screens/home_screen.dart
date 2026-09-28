// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';
import '../widgets/stat_card.dart';
import '../widgets/device_list_tile.dart';
import '../widgets/scan_progress_bar.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<DeviceManager>(
        builder: (context, manager, _) {
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: manager.refreshAllDevices,
            child: CustomScrollView(
              slivers: [
                // Network info banner
                SliverToBoxAdapter(
                  child: _NetworkInfoBanner(manager: manager),
                ),

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

                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Devices',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${manager.totalCount} found',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                // Device list
                if (manager.devices.isEmpty)
                  SliverFillRemaining(child: _EmptyState(manager: manager))
                else
                  SliverList(
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
                          onRefresh: () => manager.checkSingleDevice(device.ip),
                        );
                      },
                      childCount: manager.devices.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFABs(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.radar,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text('NetWatch'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildFABs(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, manager, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add device button
            FloatingActionButton.small(
              heroTag: 'add',
              backgroundColor:
                  Theme.of(context).colorScheme.surface,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
              ),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            // Scan network button
            FloatingActionButton.extended(
              heroTag: 'scan',
              backgroundColor: manager.isScanning
                  ? Colors.grey.shade800
                  : Theme.of(context).colorScheme.primary,
              onPressed: manager.isScanning ? null : manager.scanNetwork,
              icon: manager.isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.wifi_find, color: Colors.black),
              label: Text(
                manager.isScanning ? 'Scanning...' : 'Scan Network',
                style: TextStyle(
                    color: manager.isScanning ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NetworkInfoBanner extends StatelessWidget {
  final DeviceManager manager;
  const _NetworkInfoBanner({required this.manager});

  @override
  Widget build(BuildContext context) {
    if (manager.localIP == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _WarningBanner(
          message: 'No network detected. Connect to Wi-Fi to scan.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.router_outlined,
                color: Theme.of(context).colorScheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your IP: ${manager.localIP ?? "—"}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Subnet: ${manager.subnet ?? "—"}.0/24',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF88),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text('Connected',
                style: TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DeviceManager manager;
  const _StatsRow({required this.manager});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'Total',
              value: '${manager.totalCount}',
              icon: Icons.devices,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: 'Online',
              value: '${manager.onlineCount}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF00FF88),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: 'Offline',
              value: '${manager.offlineCount}',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFFF4466),
            ),
          ),
        ],
      ),
    );
  }
}

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
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.3)),
          const SizedBox(height: 20),
          Text('No devices yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap "Scan Network" to discover\ndevices on your Wi-Fi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
