import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BandwidthMonitorScreen extends StatefulWidget {
  const BandwidthMonitorScreen({super.key});
  @override State<BandwidthMonitorScreen> createState() => _State();
}

class _State extends State<BandwidthMonitorScreen> {
  Timer? _timer;
  bool _running = false;
  String? _pollError;
  List<_IfaceStats> _ifaces = [];
  final Map<String, List<FlSpot>> _rxHistory = {};
  final Map<String, List<FlSpot>> _txHistory = {};
  final Map<String, int> _lastRx = {}, _lastTx = {};
  int _tick = 0;
  static const _maxPoints = 60;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  Future<void> _poll() async {
    try {
      final res = await Process.run('powershell', ['-NoProfile', '-Command', r'''
Get-NetAdapterStatistics | Where-Object { $_.ReceivedBytes -gt 0 -or $_.SentBytes -gt 0 } | ForEach-Object {
  $name = $_.Name
  $rx = $_.ReceivedBytes
  $tx = $_.SentBytes
  Write-Output "$name|$rx|$tx"
}
''']);
      final lines = res.stdout.toString().trim().split('\n').where((l) => l.contains('|')).toList();
      final ifaces = <_IfaceStats>[];
      for (final line in lines) {
        final parts = line.trim().split('|');
        if (parts.length < 3) continue;
        final name = parts[0].trim();
        final rx = int.tryParse(parts[1].trim()) ?? 0;
        final tx = int.tryParse(parts[2].trim()) ?? 0;
        final rxRate = _lastRx.containsKey(name) ? ((rx - _lastRx[name]!) / 2).clamp(0, double.infinity).toDouble() : 0.0;
        final txRate = _lastTx.containsKey(name) ? ((tx - _lastTx[name]!) / 2).clamp(0, double.infinity).toDouble() : 0.0;
        _lastRx[name] = rx;
        _lastTx[name] = tx;
        _rxHistory.putIfAbsent(name, () => []);
        _txHistory.putIfAbsent(name, () => []);
        _rxHistory[name]!.add(FlSpot(_tick.toDouble(), rxRate / 1024));
        _txHistory[name]!.add(FlSpot(_tick.toDouble(), txRate / 1024));
        if (_rxHistory[name]!.length > _maxPoints) _rxHistory[name]!.removeAt(0);
        if (_txHistory[name]!.length > _maxPoints) _txHistory[name]!.removeAt(0);
        ifaces.add(_IfaceStats(name: name, rxTotal: rx, txTotal: tx, rxRate: rxRate, txRate: txRate));
      }
      _tick++;
      if (mounted) setState(() => _ifaces = ifaces);
    } catch (e) {
      if (mounted) setState(() => _pollError = e.toString());
    }
  }

  String _fmt(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(2)} MB/s';
  }

  String _fmtTotal(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Bandwidth Monitor', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _running ? const Color(0xFF00FF88) : Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(_running ? 'Live' : 'Stopped', style: TextStyle(color: _running ? const Color(0xFF00FF88) : Colors.redAccent, fontSize: 12)),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _running ? _stop : _start,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              child: Text(_running ? 'Pause' : 'Resume')),
          ]),
          const SizedBox(height: 4),
          const Text('Real-time network interface traffic (updated every 2s)', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          if (_pollError != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
              const SizedBox(height: 10),
              Text('Failed to read adapter stats:\n$_pollError', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ])))
          else if (_ifaces.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF))))
          else
            Expanded(child: ListView.builder(
              itemCount: _ifaces.length,
              itemBuilder: (_, i) => _IfaceCard(
                iface: _ifaces[i],
                rxHistory: List.from(_rxHistory[_ifaces[i].name] ?? []),
                txHistory: List.from(_txHistory[_ifaces[i].name] ?? []),
                fmt: _fmt, fmtTotal: _fmtTotal,
              ),
            )),
        ]),
      ),
    );
  }
}

class _IfaceCard extends StatelessWidget {
  const _IfaceCard({required this.iface, required this.rxHistory, required this.txHistory, required this.fmt, required this.fmtTotal});
  final _IfaceStats iface;
  final List<FlSpot> rxHistory, txHistory;
  final String Function(double) fmt;
  final String Function(int) fmtTotal;

  @override
  Widget build(BuildContext context) {
    final maxY = [...rxHistory.map((s) => s.y), ...txHistory.map((s) => s.y), 1.0].reduce((a, b) => a > b ? a : b) * 1.2;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cable, color: Color(0xFF00D4FF), size: 16),
          const SizedBox(width: 8),
          Text(iface.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          _Rate(label: 'RX', value: fmt(iface.rxRate), color: const Color(0xFF00FF88)),
          const SizedBox(width: 16),
          _Rate(label: 'TX', value: fmt(iface.txRate), color: const Color(0xFFFF6B6B)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text('Total RX: ${fmtTotal(iface.rxTotal)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 16),
          Text('Total TX: ${fmtTotal(iface.txTotal)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: rxHistory.length < 2 ? const Center(child: Text('Collecting data...', style: TextStyle(color: Colors.white24, fontSize: 11))) :
          LineChart(LineChartData(
            minY: 0, maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF1E2D45), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            clipData: const FlClipData.all(),
            lineBarsData: [
              LineChartBarData(spots: rxHistory, isCurved: true, color: const Color(0xFF00FF88), barWidth: 1.5, dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFF00FF88).withOpacity(.08))),
              LineChartBarData(spots: txHistory, isCurved: true, color: const Color(0xFFFF6B6B), barWidth: 1.5, dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFFFF6B6B).withOpacity(.06))),
            ],
          )),
        ),
        const SizedBox(height: 4),
        Row(children: [
          _Legend(color: const Color(0xFF00FF88), label: 'Download'),
          const SizedBox(width: 12),
          _Legend(color: const Color(0xFFFF6B6B), label: 'Upload'),
        ]),
      ]),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    const SizedBox(width: 4),
    Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
  ]);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color; final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 2, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
  ]);
}

class _IfaceStats {
  final String name;
  final int rxTotal, txTotal;
  final double rxRate, txRate;
  const _IfaceStats({required this.name, required this.rxTotal, required this.txTotal, required this.rxRate, required this.txRate});
}
