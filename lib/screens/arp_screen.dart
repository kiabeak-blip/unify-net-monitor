import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Android reads ARP from the kernel proc file; other platforms use the arp CLI.

class ArpScreen extends StatefulWidget {
  const ArpScreen({super.key});

  @override
  State<ArpScreen> createState() => _ArpScreenState();
}

class _ArpScreenState extends State<ArpScreen> {
  bool _loading = false;
  final List<_ArpInterface> _interfaces = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (Platform.isAndroid) {
        await _refreshAndroid();
      } else {
        await _refreshDesktop();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Android: try 'ip neigh show' first, fall back to /proc/net/arp
  Future<void> _refreshAndroid() async {
    final entries = await _readIpNeigh() ?? await _readProcArp();
    final fakeIface = _ArpInterface(ip: 'local', id: '—', entries: entries ?? []);
    if (mounted) {
      setState(() {
        _interfaces..clear()..add(fakeIface);
        _loading = false;
      });
    }
  }

  Future<List<_ArpEntry>?> _readIpNeigh() async {
    try {
      final result = await Process.run('ip', ['neigh', 'show'],
          stdoutEncoding: const SystemEncoding());
      final lines = result.stdout.toString().split('\n');
      final entries = <_ArpEntry>[];
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 5) continue;
        final ip = parts[0];
        final macIdx = parts.indexOf('lladdr');
        if (macIdx < 0 || macIdx + 1 >= parts.length) continue;
        final mac = parts[macIdx + 1];
        final state = parts.last.toLowerCase();
        if (state == 'failed' || state == 'incomplete') continue;
        final type = (state == 'reachable' || state == 'stale') ? 'dynamic' : 'static';
        entries.add(_ArpEntry(ip: ip, mac: mac, type: type));
      }
      if (entries.isEmpty) return null;
      return entries;
    } catch (_) {
      return null;
    }
  }

  Future<List<_ArpEntry>?> _readProcArp() async {
    try {
      final file = File('/proc/net/arp');
      final lines = await file.readAsLines();
      final entries = <_ArpEntry>[];
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 6) continue;
        final ip = parts[0];
        final mac = parts[3];
        final flags = int.tryParse(parts[2], radix: 16) ?? 0;
        if (mac == '00:00:00:00:00:00') continue;
        final type = (flags & 0x4) != 0 ? 'dynamic' : 'static';
        entries.add(_ArpEntry(ip: ip, mac: mac, type: type));
      }
      return entries.isEmpty ? null : entries;
    } catch (_) {
      return null;
    }
  }

  // Windows/Linux/macOS: use arp CLI
  Future<void> _refreshDesktop() async {
    final result = await Process.run(
      'arp', ['-a'],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    );

    final interfaces = <_ArpInterface>[];
    _ArpInterface? current;

    for (final line in result.stdout.toString().split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // "Interface: 192.168.1.100 --- 0x4"
      final ifaceMatch =
          RegExp(r'^Interface:\s+([\d.]+)\s+---\s+(.+)$').firstMatch(trimmed);
      if (ifaceMatch != null) {
        current = _ArpInterface(
            ip: ifaceMatch.group(1)!, id: ifaceMatch.group(2)!.trim(), entries: []);
        interfaces.add(current);
        continue;
      }

      // "192.168.1.1    aa-bb-cc-dd-ee-ff    dynamic"
      final entryMatch =
          RegExp(r'^([\d.]+)\s+([\w-]+)\s+(\w+)$').firstMatch(trimmed);
      if (entryMatch != null && current != null) {
        final ip = entryMatch.group(1)!;
        if (ip == 'Internet') continue;
        current.entries.add(_ArpEntry(
          ip: ip,
          mac: entryMatch.group(2)!,
          type: entryMatch.group(3)!,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _interfaces..clear()..addAll(interfaces);
        _loading = false;
      });
    }
  }

  List<({_ArpInterface iface, _ArpEntry entry})> get _allEntries => [
        for (final iface in _interfaces)
          for (final e in iface.entries) (iface: iface, entry: e)
      ];

  @override
  Widget build(BuildContext context) {
    final entries = _allEntries;
    final dynamic_ = entries.where((p) => p.entry.type == 'dynamic').length;
    final static_ = entries.where((p) => p.entry.type == 'static').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARP Table'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading && _interfaces.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFFF4466))))
              : entries.isEmpty
                  ? const Center(
                      child: Text('No ARP entries found.',
                          style: TextStyle(color: Colors.white38)))
                  : Column(
                      children: [
                        _buildSummary(entries.length, dynamic_, static_),
                        _buildHeader(),
                        Expanded(child: _buildList(entries)),
                      ],
                    ),
    );
  }

  Widget _buildSummary(int total, int dyn, int sta) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _SummaryChip(label: 'Neighbors', value: '$total', color: const Color(0xFF00D4FF)),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Dynamic', value: '$dyn', color: const Color(0xFF00FF88)),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Static', value: '$sta', color: const Color(0xFFFFAA00)),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Interfaces',
              value: '${_interfaces.length}',
              color: Colors.white38),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1A2235),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: const Row(
        children: [
          SizedBox(width: 14),
          SizedBox(
              width: 128,
              child: Text('IP Address',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          SizedBox(
              width: 160,
              child: Text('MAC Address',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          Expanded(
              child: Text('Via Interface',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          SizedBox(
              width: 64,
              child: Text('Type',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildList(List<({_ArpInterface iface, _ArpEntry entry})> entries) {
    return Container(
      color: const Color(0xFF050A0F),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final (:iface, :entry) = entries[i];
          return _ArpRow(entry: entry, ifaceIp: iface.ip);
        },
      ),
    );
  }
}

// ── ARP row ───────────────────────────────────────────────────────────────────

class _ArpRow extends StatelessWidget {
  final _ArpEntry entry;
  final String ifaceIp;
  const _ArpRow({super.key, required this.entry, required this.ifaceIp});

  @override
  Widget build(BuildContext context) {
    final isBroadcast = entry.mac == 'ff-ff-ff-ff-ff-ff';
    final isDynamic = entry.type == 'dynamic';
    final color = isBroadcast
        ? Colors.white24
        : isDynamic
            ? const Color(0xFF00FF88)
            : const Color(0xFFFFAA00);

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: entry.ip));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copied ${entry.ip}'),
            duration: const Duration(seconds: 1)));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 128,
              child: Text(entry.ip,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
            SizedBox(
              width: 160,
              child: Text(entry.mac,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
            Expanded(
              child: Text(ifaceIp,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
            SizedBox(
              width: 64,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(entry.type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _ArpInterface {
  final String ip;
  final String id;
  final List<_ArpEntry> entries;
  _ArpInterface({required this.ip, required this.id, required this.entries});
}

class _ArpEntry {
  final String ip;
  final String mac;
  final String type;
  _ArpEntry({required this.ip, required this.mac, required this.type});
}
