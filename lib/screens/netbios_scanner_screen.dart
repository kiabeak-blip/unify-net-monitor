import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_scanner.dart';

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
  bool _lastWasSingleHost = false; // tracks empty-state message without mutating _scanRange
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
    if (_loading) return; // prevent concurrent scans
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() { _loading = true; _cancelled = false; _scanned = false; _error = null; _results = []; _progress = 0; _total = 0; _liveHosts = 0; _lastWasSingleHost = false; });
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
    if (mounted) setState(() => _lastWasSingleHost = true);
    var result = await _queryNbtstat(target);
    // Fallback: DNS reverse lookup + ARP cache when NetBIOS gives nothing
    result ??= await _queryFallback(target);
    if (mounted) setState(() => _results = result != null ? [result] : []);
  }

  Future<void> _scanSubnet(String subnet) async {
    var base = subnet.replaceAll(RegExp(r'/\d+$'), '').trim();
    final parts = base.split('.');

    // If a full IP was entered (4 octets), treat as single-host — don't mutate _scanRange
    if (parts.length == 4 && int.tryParse(parts[3]) != null) {
      if (mounted) setState(() => _lastWasSingleHost = true);
      var result = await _queryNbtstat(base);
      result ??= await _queryFallback(base);
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

    // Phase 1: ping sweep to find live hosts quickly
    final liveHosts = <String>[];
    const pingBatch = 15;
    for (var i = 0; i < ips.length && !_cancelled; i += pingBatch) {
      final batch = ips.sublist(i, (i + pingBatch).clamp(0, ips.length));
      final hits = await Future.wait(batch.map(_pingHost));
      for (var j = 0; j < batch.length; j++) {
        if (hits[j]) liveHosts.add(batch[j]);
      }
      if (mounted) setState(() => _progress = i + batch.length);
      if (i + pingBatch < ips.length && !_cancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (_cancelled) return;

    // If ping sweep found nothing, some networks block ICMP — query all IPs directly
    final nbtTargets = liveHosts.isNotEmpty ? liveHosts : ips;
    if (mounted) setState(() { _liveHosts = liveHosts.length; _total = nbtTargets.length; _progress = 0; });

    // Phase 2: nbtstat on targets in batches of 20
    const nbtBatch = 20;
    for (var i = 0; i < nbtTargets.length && !_cancelled; i += nbtBatch) {
      final batch = nbtTargets.sublist(i, (i + nbtBatch).clamp(0, nbtTargets.length));
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

  Future<_NetBiosResult?> _queryFallback(String ip) async {
    String hostname = '';
    String mac = '';

    // DNS reverse lookup
    try {
      final res = await Process.run('nslookup', [ip], runInShell: false)
          .timeout(const Duration(seconds: 3));
      final out = res.stdout.toString();
      for (final line in out.split('\n')) {
        final l = line.trim().toLowerCase();
        if (l.startsWith('name:')) {
          hostname = line.trim().substring(5).trim();
          break;
        }
      }
    } catch (_) {}

    // ARP cache lookup
    try {
      final res = await Process.run('arp', ['-a', ip], runInShell: false)
          .timeout(const Duration(seconds: 2));
      final out = res.stdout.toString();
      final m = RegExp(r'([0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2}[-:][0-9a-f]{2})',
          caseSensitive: false).firstMatch(out);
      if (m != null) mac = m.group(1)!.toUpperCase().replaceAll('-', ':');
    } catch (_) {}

    if (hostname.isEmpty && mac.isEmpty) return null;
    final source = hostname.isNotEmpty && mac.isNotEmpty ? 'DNS + ARP'
        : hostname.isNotEmpty ? 'DNS' : 'ARP';
    final vendor = mac.isNotEmpty ? (NetworkScanner.lookupManufacturer(mac) ?? '') : '';
    return _NetBiosResult(ip: ip, hostname: hostname, mac: mac, entries: [], source: source, vendor: vendor);
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
    final vendor = macAddr.isNotEmpty ? (NetworkScanner.lookupManufacturer(macAddr) ?? '') : '';
    return _NetBiosResult(ip: ip, hostname: hostname, mac: macAddr, entries: entries, vendor: vendor);
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
            Text(_progress < _total && _liveHosts == 0 && _results.isEmpty
                ? 'Phase 1 — Ping sweep, finding live hosts...'
                : _liveHosts == 0 && _results.isEmpty
                    ? 'Ping found no hosts — querying all IPs directly...'
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
                  size: 48, color: _scanned ? Colors.white24 : Colors.white12),
              const SizedBox(height: 16),
              Text(
                _scanned
                  ? (_lastWasSingleHost
                      ? 'No NetBIOS response from ${_targetCtrl.text.trim()}'
                      : (_liveHosts == 0
                          ? 'No live hosts with NetBIOS found'
                          : 'Found $_liveHosts live host${_liveHosts == 1 ? "" : "s"} — none had NetBIOS names'))
                  : 'Enter a host or subnet to scan',
                style: TextStyle(
                    color: _scanned ? Colors.white60 : Colors.white24,
                    fontSize: 14, fontWeight: _scanned ? FontWeight.w500 : FontWeight.normal)),
              if (_scanned) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A3F5F)),
                  ),
                  child: Column(children: [
                    const Text('Common reasons NetBIOS is unavailable:',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('• NetBIOS disabled on Windows 10/11 (common default)\n'
                        '• Device is not a Windows PC (Linux, Mac, camera, router)\n'
                        '• Firewall blocking UDP port 137\n'
                        '• Device is offline or unreachable',
                        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.6)),
                  ]),
                ),
              ],
            ])))
          else
            Expanded(child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => _NetBiosDetailDialog(result: r),
                  ),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D45))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8), child: Row(children: [
                      const Icon(Icons.computer, color: Color(0xFF00D4FF), size: 15),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.hostname.isNotEmpty ? r.hostname : r.vendor.isNotEmpty ? r.vendor : '(unknown)', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Row(children: [
                          Text(r.ip, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: r.source == 'NetBIOS'
                                  ? const Color(0xFF00D4FF).withValues(alpha: 0.12)
                                  : const Color(0xFFFFAA00).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: r.source == 'NetBIOS'
                                  ? const Color(0xFF00D4FF).withValues(alpha: 0.3)
                                  : const Color(0xFFFFAA00).withValues(alpha: 0.3)),
                            ),
                            child: Text(r.source,
                              style: TextStyle(
                                color: r.source == 'NetBIOS' ? const Color(0xFF00D4FF) : const Color(0xFFFFAA00),
                                fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ]),
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
                              color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88).withValues(alpha: .1) : const Color(0xFF1A2035),
                              borderRadius: BorderRadius.circular(4)),
                            child: Text(e.status, style: TextStyle(color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88) : Colors.white38, fontSize: 9))),
                        ]))),
                    ],
                    // Tap hint
                    const Divider(height: 1, color: Color(0xFF1E2D45)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(children: [
                        Icon(Icons.touch_app, size: 11, color: Colors.white24),
                        SizedBox(width: 5),
                        Text('Tap for full details — ports, vendor, HTTP, DNS',
                            style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ]),
                    ),
                  ]),
                  )); // end InkWell + Container
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
  final String source; // 'NetBIOS', 'DNS', 'ARP'
  final String vendor;
  const _NetBiosResult({required this.ip, required this.hostname, required this.mac, required this.entries, this.source = 'NetBIOS', this.vendor = ''});
}

class _NbtEntry {
  final String name, type, status;
  final int code;
  const _NbtEntry({required this.name, required this.code, required this.type, required this.status});
}

// ─── Detail Dialog ──────────────────────────────────────────────────────────

class _NetBiosDetailDialog extends StatefulWidget {
  const _NetBiosDetailDialog({required this.result});
  final _NetBiosResult result;

  @override
  State<_NetBiosDetailDialog> createState() => _NetBiosDetailDialogState();
}

class _NetBiosDetailDialogState extends State<_NetBiosDetailDialog> {
  bool _loading = true;
  String? _vendor;
  String? _dns;
  int? _pingMs;
  String? _httpBanner;   // from port 80
  String? _httpsBanner;  // from port 443
  String? _sshBanner;
  String? _nbnsName;     // from raw NBNS UDP
  List<int> _openPorts = [];

  static const _commonPorts = [
    21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 161, 443, 445, 554,
    3306, 3389, 5900, 8080, 8443, 8000, 37777,
  ];

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final ip = widget.result.ip;

    await Future.wait([
      _probePing(ip),
      _probeDns(ip),
      _probeVendor(),
      _probePorts(ip),
      _probeNbns(ip),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _probePing(String ip) async {
    try {
      final sw = Stopwatch()..start();
      final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip])
          .timeout(const Duration(seconds: 2));
      sw.stop();
      if (res.exitCode == 0 && mounted) {
        // Try to parse actual RTT from ping output
        final m = RegExp(r'time[=<](\d+)ms', caseSensitive: false)
            .firstMatch(res.stdout.toString());
        final ms = m != null ? int.tryParse(m.group(1)!) : sw.elapsedMilliseconds;
        if (mounted) setState(() => _pingMs = ms);
      }
    } catch (_) {}
  }

  Future<void> _probeDns(String ip) async {
    try {
      final res = await Process.run('nslookup', [ip])
          .timeout(const Duration(seconds: 3));
      final out = res.stdout.toString();
      for (final line in out.split('\n')) {
        final l = line.trim().toLowerCase();
        if (l.startsWith('name:')) {
          final name = line.trim().substring(5).trim();
          if (mounted) setState(() => _dns = name);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _probeVendor() async {
    final mac = widget.result.mac;
    if (mac.isEmpty) return;
    final v = NetworkScanner.lookupManufacturer(mac);
    if (v != null && mounted) setState(() => _vendor = v);
  }

  Future<void> _probePorts(String ip) async {
    final open = <int>[];
    await Future.wait(_commonPorts.map((port) async {
      try {
        final sock = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 800));
        open.add(port);

        // Grab banners while socket is open
        if (port == 80 || port == 8080) {
          try {
            sock.write('GET / HTTP/1.0\r\nHost: $ip\r\n\r\n');
            final data = await sock.first.timeout(const Duration(seconds: 1));
            final s = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));
            final m = RegExp(r'Server:\s*(.+)', caseSensitive: false).firstMatch(s);
            if (m != null && mounted) setState(() => _httpBanner = m.group(1)!.trim());
          } catch (_) {}
        }
        if (port == 443 || port == 8443) {
          if (mounted) setState(() => _httpsBanner = 'HTTPS available');
        }
        if (port == 22) {
          try {
            final data = await sock.first.timeout(const Duration(seconds: 1));
            final s = String.fromCharCodes(data.where((b) => b >= 32 && b < 127)).trim();
            if (s.isNotEmpty && mounted) setState(() => _sshBanner = s);
          } catch (_) {}
        }
        await sock.close();
      } catch (_) {}
    }));
    open.sort();
    if (mounted) setState(() => _openPorts = open);
  }

  Future<void> _probeNbns(String ip) async {
    // Raw NBNS Node Status UDP query
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final pkt = Uint8List.fromList([
        0xAB, 0xCD, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x20, 0x43, 0x4B,
        0x41,0x41,0x41,0x41,0x41,0x41,0x41,0x41,
        0x41,0x41,0x41,0x41,0x41,0x41,0x41,0x41,
        0x41,0x41,0x41,0x41,0x41,0x41,0x41,0x41,
        0x41,0x41,0x41,0x41,0x41,0x41,
        0x00, 0x00, 0x21, 0x00, 0x01,
      ]);
      sock.send(pkt, InternetAddress(ip), 137);
      String? name;
      await sock.timeout(const Duration(seconds: 2)).firstWhere((e) {
        if (e != RawSocketEvent.read) return false;
        final dg = sock.receive();
        if (dg == null || dg.data.length < 12) return false;
        final data = dg.data;
        int offset = 12;
        final qdcount = (data[4] << 8) | data[5];
        for (int q = 0; q < qdcount && offset < data.length; q++) {
          while (offset < data.length) {
            final len = data[offset];
            if (len == 0) { offset++; break; }
            if ((len & 0xC0) == 0xC0) { offset += 2; break; }
            offset += 1 + len;
          }
          offset += 4;
        }
        if ((data[6] << 8 | data[7]) == 0) return true;
        while (offset < data.length) {
          final len = data[offset];
          if (len == 0) { offset++; break; }
          if ((len & 0xC0) == 0xC0) { offset += 2; break; }
          offset += 1 + len;
        }
        offset += 10; // TYPE+CLASS+TTL+RDLEN
        if (offset >= data.length) return true;
        final numNames = data[offset++];
        for (int i = 0; i < numNames && offset + 18 <= data.length; i++) {
          final rawName = data.sublist(offset, offset + 15)
              .where((b) => b >= 0x21 && b <= 0x7E)
              .map(String.fromCharCode).join().trim();
          final type = data[offset + 15];
          final flagsHi = data[offset + 16];
          final isGroup = (flagsHi & 0x80) != 0;
          offset += 18;
          if (rawName.isNotEmpty && type == 0x00 && !isGroup) { name = rawName; break; }
        }
        return true;
      }).catchError((_) {});
      sock.close();
      if (name != null && mounted) setState(() => _nbnsName = name);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final displayName = _nbnsName ?? (r.hostname.isNotEmpty ? r.hostname : null);

    return Dialog(
      backgroundColor: const Color(0xFF0D1321),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E2D45))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.computer, color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName ?? '(unknown)',
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(r.ip, style: const TextStyle(color: Colors.white38,
                    fontFamily: 'monospace', fontSize: 12)),
              ])),
              if (_loading)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5,
                        color: Color(0xFF00D4FF))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          // ── Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Identity
                _section('Identity', [
                  _row('IP Address', r.ip),
                  if (displayName != null) _row('Hostname / Name', displayName),
                  if (_dns != null && _dns != displayName) _row('DNS Reverse', _dns!),
                  if (r.mac.isNotEmpty) _row('MAC Address', r.mac),
                  if (_vendor != null) _row('Vendor', _vendor!),
                  _row('Discovery', r.source),
                ]),
                const SizedBox(height: 14),
                // Connectivity
                _section('Connectivity', [
                  _row('Ping', _loading && _pingMs == null
                      ? 'measuring…'
                      : _pingMs != null ? '$_pingMs ms' : 'no response'),
                  if (_sshBanner != null) _row('SSH Banner', _sshBanner!),
                  if (_httpBanner != null) _row('HTTP Server', _httpBanner!),
                  if (_httpsBanner != null) _row('HTTPS', _httpsBanner!),
                ]),
                const SizedBox(height: 14),
                // Open ports
                _section('Open Ports', []),
                if (_loading && _openPorts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 4),
                    child: Text('Probing common ports…',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                else if (_openPorts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 4),
                    child: Text('No common ports open',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in _openPorts)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.30)),
                        ),
                        child: Text('$p  ${_portName(p)}',
                            style: const TextStyle(color: Color(0xFF00D4FF),
                                fontSize: 11, fontFamily: 'monospace')),
                      ),
                  ]),
                // NetBIOS entries
                if (r.entries.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _section('NetBIOS Name Table', []),
                  const SizedBox(height: 6),
                  for (final e in r.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        SizedBox(width: 40, child: Text(
                            '0x${e.code.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                            style: const TextStyle(color: Color(0xFF00D4FF),
                                fontFamily: 'monospace', fontSize: 10))),
                        SizedBox(width: 120, child: Text(e.name,
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'monospace', fontSize: 11),
                            overflow: TextOverflow.ellipsis)),
                        Expanded(child: Text(_nbtDesc(e.code),
                            style: const TextStyle(color: Colors.white38, fontSize: 10))),
                        Text(e.type,
                            style: const TextStyle(color: Colors.white24, fontSize: 9)),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E2D45)))),
            child: Row(children: [
              Expanded(child: Text(
                  _loading ? 'Probing ports and services…' : 'Scan complete',
                  style: const TextStyle(color: Colors.white24, fontSize: 10))),
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(
                    text: '${r.ip}\t${displayName ?? ""}\t${r.mac}\t${_vendor ?? ""}'
                        '\t${_openPorts.join(",")}')),
                child: const Text('Copy', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: Color(0xFF00D4FF),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      ...rows,
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 11))),
      Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 11,
              fontFamily: 'monospace'))),
    ]),
  );

  String _portName(int p) => const {
    21: 'FTP', 22: 'SSH', 23: 'Telnet', 25: 'SMTP', 53: 'DNS',
    80: 'HTTP', 110: 'POP3', 135: 'RPC', 139: 'NetBIOS', 143: 'IMAP',
    161: 'SNMP', 443: 'HTTPS', 445: 'SMB', 554: 'RTSP',
    3306: 'MySQL', 3389: 'RDP', 5900: 'VNC', 8080: 'HTTP-alt',
    8443: 'HTTPS-alt', 8000: 'HTTP-dev', 37777: 'Dahua',
  }[p] ?? '';

  String _nbtDesc(int code) => const {
    0x00: 'Workstation / Computer name',
    0x03: 'Messenger (logged-in user)',
    0x06: 'RAS Server',
    0x1B: 'Domain Master Browser',
    0x1C: 'Domain Controller',
    0x1D: 'Master Browser',
    0x1E: 'Browser Elections',
    0x20: 'File Server',
    0x21: 'RAS Client',
  }[code] ?? '0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}
