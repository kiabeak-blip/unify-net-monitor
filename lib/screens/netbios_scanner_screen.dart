import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetBiosScannerScreen extends StatefulWidget {
  const NetBiosScannerScreen({super.key});
  @override State<NetBiosScannerScreen> createState() => _State();
}

class _State extends State<NetBiosScannerScreen> {
  final _targetCtrl = TextEditingController();
  bool _loading = false;
  bool _cancelled = false;
  bool _scanned = false;
  String? _error;
  List<_NetBiosResult> _results = [];
  bool _scanRange = false;
  int _progress = 0;
  int _total = 0;
  int _liveHosts = 0;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  void _cancel() => setState(() => _cancelled = true);

  Future<void> _scan() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() { _loading = true; _cancelled = false; _scanned = false; _error = null; _results = []; _progress = 0; _total = 0; _liveHosts = 0; });
    try {
      if (_scanRange) {
        await _scanSubnet(target);
      } else {
        await _scanHost(target);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() { _loading = false; _scanned = true; });
  }

  Future<void> _scanHost(String target) async {
    final result = await _queryNbtstat(target);
    if (mounted && result != null) setState(() => _results = [result]);
  }

  Future<void> _scanSubnet(String subnet) async {
    var base = subnet.replaceAll(RegExp(r'/\d+$'), '').trim();
    final parts = base.split('.');

    // If a full IP was entered (4 octets), just scan that one host directly
    if (parts.length == 4 && int.tryParse(parts[3]) != null) {
      final result = await _queryNbtstat(base);
      if (mounted) setState(() => _results = result != null ? [result] : []);
      return;
    }

    // Strip trailing .0 for subnet prefix
    final lastDot = base.lastIndexOf('.');
    if (lastDot > 0 && base.substring(lastDot + 1) == '0') base = base.substring(0, lastDot);
    final subParts = base.split('.');
    if (subParts.length < 3) {
      setState(() => _error = 'Enter a subnet like 192.168.1 or 192.168.1.0/24');
      return;
    }
    final prefix = subParts.take(3).join('.');
    final ips = List.generate(254, (i) => '$prefix.${i + 1}');
    setState(() { _total = ips.length; _progress = 0; });

    // First: ping sweep — smaller batches to avoid Windows ICMP rate limiting
    final liveHosts = <String>[];
    const pingBatch = 15;
    for (var i = 0; i < ips.length && !_cancelled; i += pingBatch) {
      final batch = ips.sublist(i, (i + pingBatch).clamp(0, ips.length));
      final hits = await Future.wait(batch.map(_pingHost));
      for (var j = 0; j < batch.length; j++) {
        if (hits[j]) liveHosts.add(batch[j]);
      }
      if (mounted) setState(() => _progress = i + batch.length);
      // Brief pause between batches so Windows ICMP rate limiter clears
      if (i + pingBatch < ips.length && !_cancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (_cancelled) return;
    if (mounted) setState(() => _liveHosts = liveHosts.length);
    if (liveHosts.isEmpty) return;

    // Second: run nbtstat only on live hosts, in parallel batches of 20
    if (mounted) setState(() { _total = liveHosts.length; _progress = 0; });
    const nbtBatch = 20;
    for (var i = 0; i < liveHosts.length && !_cancelled; i += nbtBatch) {
      final batch = liveHosts.sublist(i, (i + nbtBatch).clamp(0, liveHosts.length));
      final results = await Future.wait(batch.map(_queryNbtstat));
      for (final r in results) {
        if (r != null && mounted) {
          setState(() => _results = [..._results, r]);
        }
      }
      if (mounted) setState(() => _progress = i + batch.length);
    }
  }

  Future<bool> _pingHost(String ip) async {
    try {
      final res = await Process.run('ping', ['-n', '1', '-w', '800', ip], runInShell: false)
          .timeout(const Duration(milliseconds: 1200));
      return res.exitCode == 0;
    } catch (_) { return false; }
  }

  Future<_NetBiosResult?> _queryNbtstat(String ip) async {
    try {
      final res = await Process.run('nbtstat', ['-A', ip], runInShell: false)
          .timeout(const Duration(seconds: 3));
      final lines = res.stdout.toString().split('\n');
      final result = _parseNbtstat(ip, lines);
      // Return if we got any info at all
      if (result.hostname.isEmpty && result.entries.isEmpty && result.mac.isEmpty) return null;
      return result;
    } catch (_) { return null; }
  }

  _NetBiosResult _parseNbtstat(String ip, List<String> lines) {
    String hostname = '';
    String macAddr = '';
    final entries = <_NbtEntry>[];
    for (final line in lines) {
      final l = line.trim();
      if (l.toLowerCase().startsWith('mac address')) {
        final idx = l.indexOf('=');
        if (idx > 0) macAddr = l.substring(idx + 1).trim();
      }
      final match = RegExp(r'^(\S[\w\s.-]{0,14}?)\s+<([0-9A-Fa-f]{2})>\s+(\w+)\s+(\w+)').firstMatch(l);
      if (match != null) {
        final name = match.group(1)!.trim();
        final hex = int.parse(match.group(2)!, radix: 16);
        final type = match.group(3)!;
        final status = match.group(4)!;
        if (hex == 0x00 && type.toLowerCase() == 'unique' && hostname.isEmpty) hostname = name;
        entries.add(_NbtEntry(name: name, code: hex, type: type, status: status));
      }
    }
    return _NetBiosResult(ip: ip, hostname: hostname, mac: macAddr, entries: entries);
  }

  String _codeDesc(int code) {
    const m = {0x00: 'Workstation', 0x03: 'Messenger', 0x06: 'RAS Server',
      0x1B: 'Domain Master Browser', 0x1C: 'Domain Controller',
      0x1D: 'Master Browser', 0x1E: 'Browser Elections',
      0x20: 'File Server', 0x21: 'RAS Client'};
    return m[code] ?? '0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NetBIOS Scanner', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Fast parallel NetBIOS name table query via nbtstat', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_scanRange ? 'Subnet (e.g. 192.168.1)' : 'Target Host / IP', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: _targetCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _scanRange ? '192.168.1 or 192.168.1.0/24' : 'e.g. 192.168.1.50 or hostname',
                  hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF1A2035),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                onSubmitted: (_) => _loading ? null : _scan()),
            ])),
            const SizedBox(width: 12),
            _loading
              ? OutlinedButton.icon(onPressed: _cancel,
                  icon: const Icon(Icons.stop, size: 14, color: Colors.redAccent),
                  label: const Text('Stop', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)))
              : ElevatedButton(onPressed: _scan,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                  child: const Text('Scan')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: _scanRange, onChanged: (v) => setState(() { _scanRange = v ?? false; _results = []; }),
              checkColor: Colors.black, fillColor: WidgetStateProperty.all(const Color(0xFF00D4FF)), side: const BorderSide(color: Color(0xFF2A3F5F))),
            const Text('Scan entire subnet', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 8),
            const Text('(ping sweep first, then nbtstat on live hosts only)', style: TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
          if (_loading) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _progress / _total : null,
                  minHeight: 6, color: const Color(0xFF00D4FF), backgroundColor: const Color(0xFF1E2D45)))),
              const SizedBox(width: 10),
              Text(_total > 0 ? '$_progress / $_total' : 'Scanning...',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 4),
            Text(_liveHosts == 0 && _results.isEmpty
                ? 'Phase 1 — Ping sweep, finding live hosts...'
                : 'Phase 2 — Querying NetBIOS on $_liveHosts live host${_liveHosts == 1 ? "" : "s"}...',
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ],
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          const SizedBox(height: 10),
          if (_results.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('${_results.length} NetBIOS host${_results.length == 1 ? '' : 's'} found',
                style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.w600))),
          if (!_loading && _results.isEmpty && _error == null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(_scanned ? Icons.search_off : Icons.manage_search,
                  size: 40, color: Colors.white12),
              const SizedBox(height: 12),
              Text(
                _scanned
                  ? (_liveHosts == 0
                      ? 'No hosts responded to ping on this subnet'
                      : 'Found $_liveHosts live host${_liveHosts == 1 ? "" : "s"} but none had NetBIOS names')
                  : 'Enter a host or subnet to scan',
                style: const TextStyle(color: Colors.white24, fontSize: 13)),
              if (_scanned && _liveHosts > 0) ...[
                const SizedBox(height: 8),
                const Text('NetBIOS may be disabled on those devices (common on Windows 10/11)',
                  style: TextStyle(color: Colors.white12, fontSize: 11)),
              ],
            ])))
          else
            Expanded(child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D45))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8), child: Row(children: [
                      const Icon(Icons.computer, color: Color(0xFF00D4FF), size: 15),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.hostname.isNotEmpty ? r.hostname : '(unknown)', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(r.ip, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
                      ]),
                      const Spacer(),
                      if (r.mac.isNotEmpty) ...[
                        const Icon(Icons.settings_ethernet, color: Colors.white24, size: 12),
                        const SizedBox(width: 4),
                        Text(r.mac, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 10)),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: '${r.ip}\t${r.hostname}\t${r.mac}')),
                        child: const Icon(Icons.copy, size: 13, color: Colors.white24)),
                    ])),
                    if (r.entries.isNotEmpty) ...[
                      const Divider(height: 1, color: Color(0xFF1E2D45)),
                      ...r.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 36, child: Text('0x${e.code.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                            style: const TextStyle(color: Color(0xFF00D4FF), fontFamily: 'monospace', fontSize: 10))),
                          const SizedBox(width: 8),
                          SizedBox(width: 130, child: Text(e.name, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_codeDesc(e.code), style: const TextStyle(color: Colors.white38, fontSize: 10))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88).withOpacity(.1) : const Color(0xFF1A2035),
                              borderRadius: BorderRadius.circular(4)),
                            child: Text(e.status, style: TextStyle(color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88) : Colors.white38, fontSize: 9))),
                        ]))),
                    ],
                  ]),
                );
              },
            )),
        ]),
      ),
    );
  }
}

class _NetBiosResult {
  final String ip, hostname, mac;
  final List<_NbtEntry> entries;
  const _NetBiosResult({required this.ip, required this.hostname, required this.mac, required this.entries});
}

class _NbtEntry {
  final String name, type, status;
  final int code;
  const _NbtEntry({required this.name, required this.code, required this.type, required this.status});
}
