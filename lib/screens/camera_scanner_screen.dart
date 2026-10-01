// lib/screens/camera_scanner_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

// Common IP camera ports
const _cameraPorts = [554, 8554, 8080, 8000, 8888, 37777, 34567, 80, 443, 2020];

// OUI prefix → brand name (first 6 hex chars of MAC, uppercase no colons)
const _ouiBrands = {
  'ACDCAA': 'Hikvision', 'D074DF': 'Hikvision', '000000': 'Hikvision',
  'D46A35': 'Dahua',     '3C1B86': 'Dahua',     '705A9E': 'Dahua',
  '00E091': 'Axis',      '00408C': 'Axis',
  'B4A2EB': 'Reolink',   '6C29B5': 'Reolink',
  'E0CC7A': 'Amcrest',   'D466CE': 'Amcrest',
  '00408F': 'Bosch',
  'D80404': 'Hanwha',
};

// Port → default RTSP path
const _rtspPaths = {
  554:   '/stream1',
  8554:  '/stream1',
  8080:  '/video.mjpg',
  37777: '/cam/realmonitor?channel=1&subtype=0',
  34567: '/h264Preview_01_main',
};

class CameraDevice {
  final String ip;
  final List<int> openPorts;
  final String? brand;
  final String? mac;

  const CameraDevice({
    required this.ip,
    required this.openPorts,
    this.brand,
    this.mac,
  });

  String rtspUrl() {
    final port = openPorts.firstWhere(
        (p) => _rtspPaths.containsKey(p), orElse: () => openPorts.first);
    final path = _rtspPaths[port] ?? '/stream1';
    return 'rtsp://<user>:<pass>@$ip:$port$path';
  }
}

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final _subnetCtrl = TextEditingController();
  bool _scanning = false;
  int _progress = 0;
  int _total = 254;
  List<CameraDevice> _found = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill subnet from DeviceManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subnet = context.read<DeviceManager>().subnet;
      if (subnet != null && _subnetCtrl.text.isEmpty) {
        _subnetCtrl.text = subnet;
      }
    });
  }

  @override
  void dispose() {
    _subnetCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final subnet = _subnetCtrl.text.trim();
    if (subnet.isEmpty) {
      setState(() => _error = 'Enter a subnet prefix (e.g. 192.168.1)');
      return;
    }
    // Normalise: strip trailing dot/zero
    final base = subnet.replaceAll(RegExp(r'\.$'), '').replaceAll(RegExp(r'\.0$'), '');
    if (base.split('.').length != 3) {
      setState(() => _error = 'Use a /24 prefix like 192.168.1');
      return;
    }

    setState(() {
      _scanning = true;
      _progress = 0;
      _total = 254;
      _found = [];
      _error = null;
    });

    final results = <CameraDevice>[];

    // Scan in batches of 16 to avoid socket exhaustion
    const batchSize = 16;
    for (var i = 1; i <= 254 && _scanning; i += batchSize) {
      final end = (i + batchSize - 1).clamp(1, 254);
      final ips = List.generate(end - i + 1, (j) => '$base.${i + j}');

      await Future.wait(ips.map((ip) async {
        final openPorts = await _checkCameraPorts(ip);
        if (openPorts.isNotEmpty) {
          final mac = await _getMac(ip);
          final brand = _guessBrand(mac);
          results.add(CameraDevice(ip: ip, openPorts: openPorts, brand: brand, mac: mac));
          if (mounted) setState(() => _found = List.from(results));
        }
      }));

      if (mounted) setState(() => _progress = end);
    }

    if (mounted) setState(() => _scanning = false);
  }

  void _stop() => setState(() => _scanning = false);

  Future<List<int>> _checkCameraPorts(String ip) async {
    final open = <int>[];
    await Future.wait(_cameraPorts.map((port) async {
      try {
        final sock = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 400));
        await sock.close();
        open.add(port);
      } catch (_) {}
    }));
    return open;
  }

  Future<String?> _getMac(String ip) async {
    try {
      // Ping first to populate ARP cache
      await Process.run('ping', ['-n', '1', '-w', '200', ip]);
      final res = await Process.run('arp', ['-a', ip],
          stdoutEncoding: const SystemEncoding());
      final lines = res.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains(ip)) {
          final match = RegExp(r'([0-9a-f]{2}[:-]){5}[0-9a-f]{2}',
              caseSensitive: false).firstMatch(line);
          if (match != null) return match.group(0);
        }
      }
    } catch (_) {}
    return null;
  }

  String? _guessBrand(String? mac) {
    if (mac == null) return null;
    final oui = mac.replaceAll(RegExp(r'[:\-]'), '').toUpperCase();
    if (oui.length >= 6) return _ouiBrands[oui.substring(0, 6)];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Header(
        subnetCtrl: _subnetCtrl,
        scanning: _scanning,
        progress: _progress,
        total: _total,
        found: _found.length,
        onScan: _scan,
        onStop: _stop,
        error: _error,
      ),
      Expanded(
        child: _found.isEmpty
            ? _EmptyState(scanning: _scanning, progress: _progress, total: _total)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _found.length,
                itemBuilder: (ctx, i) => _CameraCard(camera: _found[i]),
              ),
      ),
    ]);
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.subnetCtrl,
    required this.scanning,
    required this.progress,
    required this.total,
    required this.found,
    required this.onScan,
    required this.onStop,
    required this.error,
  });

  final TextEditingController subnetCtrl;
  final bool scanning;
  final int progress, total, found;
  final VoidCallback onScan, onStop;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.videocam, color: Color(0xFF00D4FF), size: 20),
          const SizedBox(width: 8),
          const Text('Camera Scanner',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (found > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.3)),
              ),
              child: Text('$found found',
                  style: const TextStyle(
                      color: Color(0xFF00D4FF), fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: subnetCtrl,
              enabled: !scanning,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '192.168.1',
                hintStyle: const TextStyle(color: Color(0xFF4A6480)),
                labelText: 'Subnet prefix (/24)',
                labelStyle: const TextStyle(color: Color(0xFF7A96B8), fontSize: 12),
                prefixIcon: const Icon(Icons.lan_outlined,
                    color: Color(0xFF4A6480), size: 17),
                filled: true,
                fillColor: const Color(0xFF111927),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E2D45))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E2D45))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                errorText: error,
                errorStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 40,
            child: scanning
                ? OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop, size: 15),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFFF87171))),
                  )
                : ElevatedButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.search, size: 15),
                    label: const Text('Scan'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18)),
                  ),
          ),
        ]),
        if (scanning) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? progress / total : 0,
                  backgroundColor: const Color(0xFF1E2D45),
                  color: const Color(0xFF00D4FF),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$progress / $total',
                style: const TextStyle(
                    color: Color(0xFF7A96B8), fontSize: 11,
                    fontVariations: [FontVariation('wght', 500)])),
          ]),
        ],
      ]),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.scanning, required this.progress, required this.total});
  final bool scanning;
  final int progress, total;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          scanning ? Icons.radar : Icons.videocam_off_outlined,
          size: 56,
          color: const Color(0xFF1E2D45),
        ),
        const SizedBox(height: 14),
        Text(
          scanning
              ? 'Scanning for IP cameras…'
              : 'Enter a subnet and press Scan',
          style: const TextStyle(color: Color(0xFF4A6480), fontSize: 14),
        ),
        if (scanning) ...[
          const SizedBox(height: 6),
          Text('$progress of $total hosts checked',
              style: const TextStyle(color: Color(0xFF2A3F5F), fontSize: 12)),
        ],
      ]),
    );
  }
}

// ─── Camera card ───────────────────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});
  final CameraDevice camera;

  @override
  Widget build(BuildContext context) {
    final rtsp = camera.rtspUrl();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111927),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2D45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.videocam,
                  color: Color(0xFF00D4FF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(camera.brand ?? 'IP Camera',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(camera.ip,
                    style: const TextStyle(
                        color: Color(0xFF7A96B8), fontSize: 12,
                        fontFamily: 'monospace')),
              ]),
            ),
            if (camera.mac != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D45),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(camera.mac!,
                    style: const TextStyle(
                        color: Color(0xFF4A6480), fontSize: 10,
                        fontFamily: 'monospace')),
              ),
          ]),
          const SizedBox(height: 10),
          // Open ports
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final port in camera.openPorts)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DD68C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: const Color(0xFF3DD68C).withValues(alpha: 0.3)),
                ),
                child: Text(
                  port == 554 || port == 8554
                      ? '$port/RTSP'
                      : port == 80
                          ? '$port/HTTP'
                          : port == 443
                              ? '$port/HTTPS'
                              : '$port',
                  style: const TextStyle(
                      color: Color(0xFF3DD68C), fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          // RTSP URL row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1321),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E2D45)),
            ),
            child: Row(children: [
              const Icon(Icons.link, color: Color(0xFF4A6480), size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(rtsp,
                    style: const TextStyle(
                        color: Color(0xFF7A96B8), fontSize: 11,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: rtsp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('RTSP URL copied to clipboard'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF111927),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, color: Color(0xFF4A6480), size: 13),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
