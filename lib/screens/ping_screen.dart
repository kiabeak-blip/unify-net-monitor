import 'dart:async';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PingScreen extends StatefulWidget {
  final String? initialHost;
  const PingScreen({super.key, this.initialHost});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final _hostCtrl = TextEditingController();


  bool _running = false;
  Timer? _timer;
  bool _pinging = false; // guard against overlapping pings

  final List<_PingResult> _results = [];
  int _sent = 0;
  int _received = 0;
  double? _minMs;
  double? _maxMs;
  double _sumMs = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialHost != null) {
      _hostCtrl.text = widget.initialHost!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _running = true;
      _results.clear();
      _sent = 0;
      _received = 0;
      _minMs = null;
      _maxMs = null;
      _sumMs = 0;
    });

    // Fire immediately, then every second
    _pingOnce(host);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running) _pingOnce(host);
    });
  }

  Future<void> _pingOnce(String host) async {
    if (_pinging || !_running) return;
    _pinging = true;
    try {
      final ping = Ping(host, count: 1, timeout: 2);
      await for (final event in ping.stream) {
        if (!mounted || !_running) break;
        // Skip summary events (no response and no error means it's a summary)
        if (event.response == null && event.error == null) continue;
        setState(() {
          _sent++;
          if (event.response?.time != null) {
            final ms = event.response!.time!.inMicroseconds / 1000.0;
            _received++;
            _sumMs += ms;
            if (_minMs == null || ms < _minMs!) _minMs = ms;
            if (_maxMs == null || ms > _maxMs!) _maxMs = ms;
            _results.add(_PingResult(
              seq: _sent, host: host, latency: ms,
              success: true, time: DateTime.now(),
            ));
          } else {
            _results.add(_PingResult(
              seq: _sent, host: host, latency: null,
              success: false, time: DateTime.now(),
            ));
          }
          if (_results.length > 100) _results.removeAt(0);
        });
      }
    } catch (_) {
      if (mounted && _running) {
        setState(() {
          _sent++;
          _results.add(_PingResult(
            seq: _sent, host: host, latency: null,
            success: false, time: DateTime.now(),
          ));
        });
      }
    } finally {
      _pinging = false;
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    if (mounted) setState(() {});
  }

  double get _avgMs => _received > 0 ? _sumMs / _received : 0;
  double get _lossPercent =>
      _sent > 0 ? ((_sent - _received) / _sent * 100) : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ping'),
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _results.clear();
                _sent = 0;
                _received = 0;
                _minMs = null;
                _maxMs = null;
                _sumMs = 0;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_sent > 0) _buildStats(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _hostCtrl,
              enabled: !_running,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Host or IP (e.g. 8.8.8.8)',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.wifi_tethering, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A2235),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF00D4FF), width: 1.5),
                ),
              ),
              onSubmitted: (_) => _running ? _stop() : _start(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _running ? _stop : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: _running
                    ? const Color(0xFFFF4466)
                    : const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                _running ? Icons.stop : Icons.play_arrow,
                size: 18,
              ),
              label: Text(
                _running ? 'Stop' : 'Ping',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final lossColor = _lossPercent == 0
        ? const Color(0xFF00FF88)
        : _lossPercent < 20
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFF4466);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          _StatChip(
            label: 'Sent',
            value: '$_sent',
            color: const Color(0xFF00D4FF),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Recv',
            value: '$_received',
            color: const Color(0xFF00FF88),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Loss',
            value: '${_lossPercent.toStringAsFixed(0)}%',
            color: lossColor,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Min',
            value: _minMs != null ? '${_minMs!.toStringAsFixed(1)}ms' : '—',
            color: Colors.white54,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Avg',
            value: _received > 0 ? '${_avgMs.toStringAsFixed(1)}ms' : '—',
            color: Colors.white54,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Max',
            value: _maxMs != null ? '${_maxMs!.toStringAsFixed(1)}ms' : '—',
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty && !_running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_tethering,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('Ping Tool',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Enter a host or IP and press Ping\nto test connectivity',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _QuickChip('8.8.8.8'),
                _QuickChip('1.1.1.1'),
                _QuickChip('google.com'),
                _QuickChip('192.168.1.1'),
              ],
            ),
          ],
        ),
      );
    }

    final reversed = _results.reversed.toList();
    return Container(
      color: const Color(0xFF050A0F),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: reversed.length,
        itemBuilder: (_, i) => _PingRow(result: reversed[i]),
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
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
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Ping result row ───────────────────────────────────────────────────────────

class _PingRow extends StatelessWidget {
  final _PingResult result;
  const _PingRow({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success
        ? result.latency! < 50
            ? const Color(0xFF00FF88)
            : result.latency! < 150
                ? const Color(0xFFFFAA00)
                : const Color(0xFFFF4466)
        : const Color(0xFFFF4466);

    final timeStr =
        '${result.time.hour.toString().padLeft(2, '0')}:${result.time.minute.toString().padLeft(2, '0')}:${result.time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1)
              ],
            ),
          ),
          // Seq
          SizedBox(
            width: 36,
            child: Text(
              '#${result.seq}',
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          // Host
          Expanded(
            child: Text(
              result.success
                  ? 'Reply from ${result.host}'
                  : 'Request timeout for ${result.host}',
              style: TextStyle(
                  color: result.success ? Colors.white70 : Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ),
          // Latency bar
          if (result.success && result.latency != null) ...[
            Container(
              width: (result.latency!.clamp(0, 300) / 300 * 60).toDouble(),
              height: 4,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                'time=${result.latency!.toStringAsFixed(1)}ms',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            const SizedBox(
              width: 80,
              child: Text('timeout',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Color(0xFFFF4466),
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
          const SizedBox(width: 10),
          Text(timeStr,
              style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// ── Quick chip ────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  const _QuickChip(this.label);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 12,
              fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF00D4FF).withOpacity(0.08),
      side: const BorderSide(color: Color(0xFF00D4FF), width: 0.5),
      onPressed: () {
        final state =
            context.findAncestorStateOfType<_PingScreenState>();
        if (state != null) {
          state._hostCtrl.text = label;
          state._start();
        }
      },
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _PingResult {
  final int seq;
  final String host;
  final double? latency;
  final bool success;
  final DateTime time;

  _PingResult({
    required this.seq,
    required this.host,
    required this.latency,
    required this.success,
    required this.time,
  });
}
