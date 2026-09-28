import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget _notAvailableOnAndroid(String tool) => Scaffold(
  appBar: AppBar(title: Text(tool)),
  body: Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.android, color: Colors.white24, size: 56),
          const SizedBox(height: 20),
          Text(tool, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('$tool is not available on Android.\nUse on Windows desktop for full functionality.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.5)),
        ],
      ),
    ),
  ),
);

class TracerouteScreen extends StatefulWidget {
  final String? initialHost;
  const TracerouteScreen({super.key, this.initialHost});

  @override
  State<TracerouteScreen> createState() => _TracerouteScreenState();
}

class _TracerouteScreenState extends State<TracerouteScreen> {
  final _hostCtrl = TextEditingController();
  bool _running = false;
  bool _stopped = false;
  Process? _process;
  final List<_HopResult> _hops = [];
  String? _header;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialHost != null) _hostCtrl.text = widget.initialHost!;
  }

  @override
  void dispose() {
    _process?.kill();
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;

    _stopped = false;
    setState(() {
      _running = true;
      _hops.clear();
      _header = null;
      _complete = false;
    });

    try {
      final args = Platform.isWindows
          ? ['-h', '30', '-w', '2000', host]
          : ['-m', '30', '-w', '2', host];
      _process = await Process.start(
          Platform.isWindows ? 'tracert' : 'traceroute', args);

      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen(_parseLine, onDone: () {
        if (!_stopped && mounted) setState(() { _running = false; _complete = true; });
      });

      _process!.stderr.transform(const SystemEncoding().decoder).listen((_) {});
    } catch (e) {
      if (mounted) setState(() => _running = false);
    }
  }

  void _stop() {
    _stopped = true;
    _process?.kill();
    _process = null;
    if (mounted) setState(() => _running = false);
  }

  static double? _parseRtt(String s) {
    s = s.trim();
    if (s == '*') return null;
    if (s.startsWith('<')) return 0.5;
    final m = RegExp(r'(\d+)\s*ms').firstMatch(s);
    return m != null ? double.tryParse(m.group(1)!) : null;
  }

  void _parseLine(String line) {
    if (!mounted) return;
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('Tracing')) {
      setState(() => _header = trimmed);
      return;
    }
    if (trimmed.startsWith('Trace complete')) {
      setState(() => _complete = true);
      return;
    }

    final firstNum = RegExp(r'^(\d+)\s+').firstMatch(trimmed);
    if (firstNum == null) return;
    final hop = int.parse(firstNum.group(1)!);
    final rest = trimmed.substring(firstNum.end);

    final rttPattern = RegExp(r'(<\d+\s+ms|\d+\s+ms|\*)');
    final rttMatches = rttPattern.allMatches(rest).toList();

    String address = '';
    double? avgMs;
    bool isTimeout = false;

    if (rttMatches.length >= 3) {
      address = rest.substring(rttMatches.last.end).trim();
      final rtts = rttMatches.take(3).map((m) => _parseRtt(m.group(0)!)).toList();
      final valid = rtts.whereType<double>().toList();
      if (valid.isNotEmpty) avgMs = valid.reduce((a, b) => a + b) / valid.length;
      isTimeout = address.contains('timed out') || valid.isEmpty;
    }

    final result = _HopResult(hop: hop, address: isTimeout ? '' : address, avgMs: avgMs, isTimeout: isTimeout);
    setState(() {
      final idx = _hops.indexWhere((h) => h.hop == hop);
      if (idx >= 0) _hops[idx] = result; else _hops.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return _notAvailableOnAndroid('Traceroute');
    return Scaffold(
      appBar: AppBar(title: const Text('Traceroute')),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(_header!,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
            ),
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
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.route, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A2235),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF00D4FF), width: 1.5)),
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
                backgroundColor:
                    _running ? const Color(0xFFFF4466) : const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 18),
              label: Text(_running ? 'Stop' : 'Trace',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_hops.isEmpty && !_running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route,
                size: 64,
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('Traceroute',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Enter a host or IP to trace\nthe network path',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _QuickChip('8.8.8.8'),
                _QuickChip('1.1.1.1'),
                _QuickChip('google.com'),
              ],
            ),
          ],
        ),
      );
    }

    final extra = (_running ? 1 : 0) + (_complete ? 1 : 0);
    return Container(
      color: const Color(0xFF050A0F),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _hops.length + extra,
        itemBuilder: (_, i) {
          if (i < _hops.length) return _HopRow(hop: _hops[i]);
          if (_running && !_complete) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF00D4FF))),
                SizedBox(width: 12),
                Text('Probing next hop…',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ]),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Trace complete.',
                style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontFamily: 'monospace')),
          );
        },
      ),
    );
  }
}

// ── Hop row ───────────────────────────────────────────────────────────────────

class _HopRow extends StatelessWidget {
  final _HopResult hop;
  const _HopRow({super.key, required this.hop});

  @override
  Widget build(BuildContext context) {
    final color = hop.isTimeout
        ? Colors.white24
        : hop.avgMs == null
            ? Colors.white24
            : hop.avgMs! < 50
                ? const Color(0xFF00FF88)
                : hop.avgMs! < 150
                    ? const Color(0xFFFFAA00)
                    : const Color(0xFFFF4466);

    return InkWell(
      onTap: hop.isTimeout || hop.address.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: hop.address));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copied ${hop.address}'),
                  duration: const Duration(seconds: 1)));
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${hop.hop}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 8),
            Container(width: 16, height: 1, color: color.withOpacity(0.4)),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: hop.isTimeout
                    ? []
                    : [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hop.isTimeout ? 'Request timed out' : hop.address,
                style: TextStyle(
                    color: hop.isTimeout ? Colors.white24 : Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ),
            if (!hop.isTimeout && hop.avgMs != null) ...[
              Container(
                width: (hop.avgMs!.clamp(0, 300) / 300 * 60).toDouble(),
                height: 4,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  hop.avgMs! < 1
                      ? '<1 ms'
                      : '${hop.avgMs!.toStringAsFixed(0)} ms',
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
                width: 68,
                child: Text('* * *',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ),
          ],
        ),
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
              color: Color(0xFF00D4FF), fontSize: 12, fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF00D4FF).withOpacity(0.08),
      side: const BorderSide(color: Color(0xFF00D4FF), width: 0.5),
      onPressed: () {
        final state =
            context.findAncestorStateOfType<_TracerouteScreenState>();
        if (state != null) {
          state._hostCtrl.text = label;
          state._start();
        }
      },
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _HopResult {
  final int hop;
  final String address;
  final double? avgMs;
  final bool isTimeout;

  const _HopResult({
    required this.hop,
    required this.address,
    required this.avgMs,
    required this.isTimeout,
  });
}
