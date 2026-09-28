// lib/widgets/device_list_tile.dart
import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(
                  device.status == DeviceStatus.online ? 0.25 : 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Status dot
              _StatusIndicator(status: device.status),
              const SizedBox(width: 14),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.ip,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                    if (device.macAddress != null || device.manufacturer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (device.manufacturer != null) device.manufacturer!,
                            if (device.macAddress != null) device.macAddress!,
                          ].join(' · '),
                          style: const TextStyle(
                              color: Color(0xFF00D4FF),
                              fontSize: 10,
                              fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
              ),

              // Latency badge
              if (device.isOnline)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    device.latencyLabel,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),

              // Open ports count
              if (device.ports.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${device.openPortsCount} ports',
                    style: const TextStyle(
                        color: Color(0xFF00D4FF), fontSize: 11),
                  ),
                ),

              // Refresh button
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: device.status == DeviceStatus.checking
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white38),
                        )
                      : const Icon(Icons.refresh,
                          color: Colors.white38, size: 16),
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor() {
    switch (device.status) {
      case DeviceStatus.online:
        return const Color(0xFF00FF88);
      case DeviceStatus.offline:
        return const Color(0xFFFF4466);
      case DeviceStatus.checking:
        return const Color(0xFF00D4FF);
      case DeviceStatus.unknown:
        return Colors.white24;
    }
  }
}

class _StatusIndicator extends StatelessWidget {
  final DeviceStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _color() {
    switch (status) {
      case DeviceStatus.online:
        return const Color(0xFF00FF88);
      case DeviceStatus.offline:
        return const Color(0xFFFF4466);
      case DeviceStatus.checking:
        return const Color(0xFF00D4FF);
      case DeviceStatus.unknown:
        return Colors.white24;
    }
  }
}
