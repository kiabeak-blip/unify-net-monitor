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
  String? _error;
  List<_NetBiosResult> _results = [];
  bool _scanRange = false;

  Future<void> _scan() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      if (_scanRange) {
        await _scanSubnet(target);
      } else {
        await _scanHost(target);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _scanHost(String target) async {
    final res = await Process.run('powershell', ['-NoProfile', '-Command', '''
try {
  \$nbtout = nbtstat -A "$target" 2>&1
  Write-Output "HOST=$target"
  Write-Output "OUTPUT=\$(\$nbtout -join '|NL|')"
} catch {
  Write-Output "ERROR=\$_"
}
''']);
    final out = res.stdout.toString().trim();
    if (out.startsWith('ERROR=')) {
      setState(() { _error = out.substring(6); _loading = false; }); return;
    }
    final map = <String, String>{};
    for (final line in out.split('\n')) {
      final idx = line.indexOf('=');
      if (idx > 0) map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    final rawOutput = (map['OUTPUT'] ?? '').split('|NL|');
    final result = _parseNbtstat(target, rawOutput);
    if (mounted) setState(() { _results = [result]; _loading = false; });
  }

  Future<void> _scanSubnet(String subnet) async {
    // Extract base e.g. "192.168.1" from "192.168.1.0/24" or "192.168.1"
    var base = subnet.replaceAll(RegExp(r'/\d+$'), '').trim();
    final lastDot = base.lastIndexOf('.');
    if (lastDot > 0 && base.substring(lastDot + 1) == '0') base = base.substring(0, lastDot);
    final parts = base.split('.');
    if (parts.length < 3) { setState(() { _error = 'Enter a subnet like 192.168.1 or 192.168.1.0/24'; _loading = false; }); return; }
    final prefix = parts.take(3).join('.');
    final results = <_NetBiosResult>[];
    for (var i = 1; i <= 254; i++) {
      final ip = '$prefix.$i';
      final res = await Process.run('nbtstat', ['-A', ip], runInShell: true);
      final lines = res.stdout.toString().split('\n');
      final result = _parseNbtstat(ip, lines);
      if (result.hostname.isNotEmpty || result.entries.isNotEmpty) {
        results.add(result);
        if (mounted) setState(() => _results = List.from(results));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  _NetBiosResult _parseNbtstat(String ip, List<String> lines) {
    String hostname = '';
    String macAddr = '';
    final entries = <_NbtEntry>[];
    for (final line in lines) {
      final l = line.trim();
      // MAC address
      if (l.toLowerCase().startsWith('mac address')) {
        final idx = l.indexOf('=');
        if (idx > 0) macAddr = l.substring(idx + 1).trim();
      }
      // Name table entries: <Name>           <XX>  <Type>   <Status>
      final match = RegExp(r'^(\S+)\s+<([0-9A-Fa-f]{2})>\s+(\w+)\s+(\w+)').firstMatch(l);
      if (match != null) {
        final name = match.group(1)!.trim();
        final hex = int.parse(match.group(2)!, radix: 16);
        final type = match.group(3)!;
        final status = match.group(4)!;
        if (hex == 0x00 && type.toLowerCase() == 'unique') hostname = name;
        entries.add(_NbtEntry(name: name, code: hex, type: type, status: status));
      }
    }
    return _NetBiosResult(ip: ip, hostname: hostname, mac: macAddr, entries: entries);
  }

  String _codeDesc(int code) {
    const m = {0x00:'Workstation/Hostname', 0x01:'Messenger Service', 0x03:'Messenger Service', 0x06:'RAS Server', 0x1B:'Domain Master Browser', 0x1C:'Domain Controller', 0x1D:'Master Browser', 0x1E:'Browser Elections', 0x20:'File Server', 0x21:'RAS Client'};
    return m[code] ?? 'Service 0x${code.toRadixString(16).padLeft(2, '0').toUpperCase()}';
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
          const Text('Query NetBIOS name table via nbtstat', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_scanRange ? 'Subnet (e.g. 192.168.1)' : 'Target Host / IP', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: _targetCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _scanRange ? '192.168.1 or 192.168.1.0/24' : 'e.g. 192.168.1.50 or hostname',
                  hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF1A2035),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                onSubmitted: (_) => _scan()),
            ])),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _scan,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Scan')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: _scanRange, onChanged: (v) => setState(() { _scanRange = v ?? false; _results = []; }),
              checkColor: Colors.black, fillColor: WidgetStateProperty.all(const Color(0xFF00D4FF)), side: const BorderSide(color: Color(0xFF2A3F5F))),
            const Text('Scan entire subnet (slow — pings all 254 hosts)', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_loading && _results.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF))))
          else if (_results.isEmpty && !_loading)
            const Expanded(child: Center(child: Text('Enter a host or subnet to scan', style: TextStyle(color: Colors.white24))))
          else ...[
            const SizedBox(height: 12),
            if (_loading) Row(children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF))), const SizedBox(width: 8), Text('Found ${_results.length} hosts...', style: const TextStyle(color: Colors.white54, fontSize: 12))]),
            Expanded(child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D45))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Row(children: [
                      const Icon(Icons.computer, color: Color(0xFF00D4FF), size: 16),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.hostname.isNotEmpty ? r.hostname : '(unknown)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(r.ip, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 12)),
                      ]),
                      const Spacer(),
                      if (r.mac.isNotEmpty) ...[
                        const Icon(Icons.settings_ethernet, color: Colors.white24, size: 13),
                        const SizedBox(width: 4),
                        Text(r.mac, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: '${r.ip}\t${r.hostname}\t${r.mac}')),
                        icon: const Icon(Icons.copy, size: 14, color: Colors.white24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ])),
                    if (r.entries.isNotEmpty) ...[
                      const Divider(height: 1, color: Color(0xFF1E2D45)),
                      ...r.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        child: Row(children: [
                          Container(width: 40, child: Text('0x${e.code.toRadixString(16).padLeft(2, '0').toUpperCase()}', style: const TextStyle(color: Color(0xFF00D4FF), fontFamily: 'monospace', fontSize: 11))),
                          const SizedBox(width: 8),
                          SizedBox(width: 140, child: Text(e.name, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(codeDesc(e.code), style: const TextStyle(color: Colors.white38, fontSize: 11))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88).withOpacity(.1) : const Color(0xFF1A2035), borderRadius: BorderRadius.circular(4)),
                            child: Text(e.status, style: TextStyle(color: e.status.toLowerCase() == 'registered' ? const Color(0xFF00FF88) : Colors.white38, fontSize: 10))),
                        ])),
                      ),
                    ],
                  ]),
                );
              },
            )),
          ],
        ]),
      ),
    );
  }

  String codeDesc(int code) => _codeDesc(code);
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
