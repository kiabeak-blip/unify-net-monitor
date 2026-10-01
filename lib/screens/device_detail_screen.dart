// lib/screens/device_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/device_manager.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String deviceIp;
  const DeviceDetailScreen({super.key, required this.deviceIp});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, manager, _) {
        final device =
            manager.devices.firstWhere((d) => d.ip == deviceIp,
                orElse: () => Device(
                    id: deviceIp,
                    name: 'Unknown',
                    ip: deviceIp));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, device, manager),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusHero(device: device),
                      const SizedBox(height: 24),
                      _LatencyChart(device: device),
                      const SizedBox(height: 24),
                      _PortsGrid(device: device),
                      const SizedBox(height: 24),
                      _InfoSection(device: device),
                      const SizedBox(height: 40),
                      _DangerZone(device: device, manager: manager),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, Device device, DeviceManager manager) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          Text(device.ip,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white38)),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => manager.checkSingleDevice(device.ip),
        ),
        IconButton(
          tooltip: 'Rename',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showRenameDialog(context, device, manager),
        ),
      ],
    );
  }

  void _showRenameDialog(
      BuildContext context, Device device, DeviceManager manager) {
    final ctrl = TextEditingController(text: device.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Rename Device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Device name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              manager.renameDevice(device.ip, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }
}

class _StatusHero extends StatelessWidget {
  final Device device;
  const _StatusHero({required this.device});

  @override
  Widget build(BuildContext context) {
    final color = device.isOnline
        ? const Color(0xFF00FF88)
        : device.status == DeviceStatus.checking
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFFFF4466);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Animated status indicator
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                device.isOnline
                    ? Icons.check_circle
                    : device.status == DeviceStatus.checking
                        ? Icons.sync
                        : Icons.cancel,
                color: color,
                size: 28,
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.statusLabel,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Latency: ${device.latencyLabel}',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 14),
                ),
                if (device.lastChecked != null)
                  Text(
                    'Checked: ${_formatTime(device.lastChecked!)}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
              ],
            ),
          ),
          // Quality badge
          if (device.isOnline)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _qualityColor(device.latencyQuality)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                device.latencyQuality.toUpperCase(),
                style: TextStyle(
                  color: _qualityColor(device.latencyQuality),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _qualityColor(String q) {
    switch (q) {
      case 'excellent':
        return const Color(0xFF00FF88);
      case 'good':
        return const Color(0xFF88FF00);
      case 'fair':
        return const Color(0xFFFFAA00);
      default:
        return const Color(0xFFFF4466);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _LatencyChart extends StatelessWidget {
  final Device device;
  const _LatencyChart({required this.device});

  @override
  Widget build(BuildContext context) {
    if (device.latencyHistory.isEmpty) return const SizedBox();

    final spots = device.latencyHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final maxY = (device.latencyHistory
                .reduce((a, b) => a > b ? a : b) *
            1.3)
        .clamp(10.0, 1000.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latency History',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: Colors.white12, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}ms',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF00D4FF),
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF00D4FF),
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF00D4FF).withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortsGrid extends StatelessWidget {
  final Device device;
  const _PortsGrid({required this.device});

  @override
  Widget build(BuildContext context) {
    if (device.ports.isEmpty) {
      return const SizedBox();
    }

    final openPorts = device.ports.where((p) => p.isOpen).toList();
    final closedPorts = device.ports.where((p) => !p.isOpen).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ports', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${device.openPortsCount} open',
              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...openPorts.map((p) => _PortChip(port: p, isOpen: true)),
            ...closedPorts.map((p) => _PortChip(port: p, isOpen: false)),
          ],
        ),
      ],
    );
  }
}

class _PortChip extends StatelessWidget {
  final PortInfo port;
  final bool isOpen;
  const _PortChip({required this.port, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? const Color(0xFF00FF88) : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ':${port.port}',
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace'),
          ),
          Text(
            port.serviceName,
            style: TextStyle(
                color: color.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Device device;
  const _InfoSection({required this.device});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Device Info',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'IP Address', value: device.ip),
              if (device.macAddress != null)
                _InfoRow(
                    label: 'MAC Address',
                    value: device.macAddress!,
                    mono: true),
              if (device.manufacturer != null)
                _InfoRow(
                    label: 'Manufacturer', value: device.manufacturer!),
              if (device.hostname != null)
                _InfoRow(label: 'Hostname', value: device.hostname!),
              _InfoRow(label: 'Type',
                  value: device.isManuallyAdded
                      ? 'Manual Entry'
                      : 'Auto-Discovered'),
              if (device.lastSeen != null)
                _InfoRow(
                    label: 'Last Seen',
                    value: _formatDateTime(device.lastSeen!)),
              if (device.lastChecked != null)
                _InfoRow(
                    label: 'Last Checked',
                    value: _formatDateTime(device.lastChecked!),
                    isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool mono;
  const _InfoRow(
      {required this.label,
      required this.value,
      this.isLast = false,
      this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom:
                    BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final Device device;
  final DeviceManager manager;
  const _DangerZone({required this.device, required this.manager});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF4466),
          side: const BorderSide(color: Color(0xFFFF4466), width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Remove Device',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A2235),
              title: const Text('Remove Device'),
              content:
                  Text('Remove ${device.name} from your list?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4466)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            manager.removeDevice(device.ip);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
