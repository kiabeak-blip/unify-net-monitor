import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetworkConnectionsScreen extends StatefulWidget {
  const NetworkConnectionsScreen({super.key});
  @override State<NetworkConnectionsScreen> createState() => _State();
}

class _State extends State<NetworkConnectionsScreen> {
  Timer? _timer;
  bool _running = false, _loading = false;
  List<_Connection> _connections = [];
  String _filter = '';
  String _sortBy = 'state';
  final _filterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  void _stop() { _timer?.cancel(); setState(() => _running = false); }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await Process.run('powershell', ['-NoProfile', '-Command', r'''
$conns = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
$udpConns = Get-NetUDPEndpoint | Select-Object LocalAddress, LocalPort, OwningProcess
$procs = @{}
Get-Process | ForEach-Object { $procs[$_.Id] = $_.Name }
foreach ($c in $conns) {
  $pname = if ($procs.ContainsKey($c.OwningProcess)) { $procs[$c.OwningProcess] } else { "?" }
  Write-Output "TCP|$($c.LocalAddress)|$($c.LocalPort)|$($c.RemoteAddress)|$($c.RemotePort)|$($c.State)|$($c.OwningProcess)|$pname"
}
foreach ($u in $udpConns) {
  $pname = if ($procs.ContainsKey($u.OwningProcess)) { $procs[$u.OwningProcess] } else { "?" }
  Write-Output "UDP|$($u.LocalAddress)|$($u.LocalPort)|||Listening|$($u.OwningProcess)|$pname"
}
''']);
      final lines = res.stdout.toString().trim().split('\n').where((l) => l.contains('|')).toList();
      final conns = <_Connection>[];
      for (final line in lines) {
        final p = line.trim().split('|');
        if (p.length < 8) continue;
        conns.add(_Connection(proto: p[0], localAddr: p[1], localPort: int.tryParse(p[2]) ?? 0,
          remoteAddr: p[3], remotePort: int.tryParse(p[4]) ?? 0, state: p[5], pid: int.tryParse(p[6]) ?? 0, process: p[7]));
      }
      if (mounted) setState(() { _connections = conns; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<_Connection> get _filtered {
    var list = _connections.where((c) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return c.localAddr.toLowerCase().contains(q) || c.remoteAddr.toLowerCase().contains(q) ||
        c.process.toLowerCase().contains(q) || '${c.localPort}'.contains(q) || '${c.remotePort}'.contains(q) ||
        c.state.toLowerCase().contains(q) || c.proto.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      switch (_sortBy) {
        case 'process': return a.process.compareTo(b.process);
        case 'pid': return a.pid.compareTo(b.pid);
        case 'port': return a.localPort.compareTo(b.localPort);
        default: return a.state.compareTo(b.state);
      }
    });
    return list;
  }

  Color _stateColor(String s) {
    switch (s.toLowerCase()) {
      case 'established': return const Color(0xFF00FF88);
      case 'listen': case 'listening': return const Color(0xFF00D4FF);
      case 'time_wait': return Colors.orangeAccent;
      case 'close_wait': return Colors.yellowAccent;
      case 'syn_sent': case 'syn_received': return Colors.purpleAccent;
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final established = filtered.where((c) => c.state.toLowerCase() == 'established').length;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Network Connections', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _running ? const Color(0xFF00FF88) : Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(_running ? 'Live' : 'Paused', style: TextStyle(color: _running ? const Color(0xFF00FF88) : Colors.redAccent, fontSize: 12)),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _running ? _stop : _start,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              child: Text(_running ? 'Pause' : 'Resume', style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 6),
            OutlinedButton.icon(onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 14), label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('${filtered.length} connections', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(width: 12),
            Text('$established established', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
            const SizedBox(width: 12),
            if (_loading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00D4FF))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _filterCtrl, onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(hintText: 'Filter by process, address, port, state...', hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 16),
                filled: true, fillColor: const Color(0xFF1A2035), isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
            const SizedBox(width: 10),
            const Text('Sort:', style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(width: 6),
            ...[('State', 'state'), ('Process', 'process'), ('Port', 'port'), ('PID', 'pid')].map((e) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(onTap: () => setState(() => _sortBy = e.$2),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _sortBy == e.$2 ? const Color(0xFF00D4FF).withOpacity(.15) : const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _sortBy == e.$2 ? const Color(0xFF00D4FF) : const Color(0xFF2A3F5F))),
                  child: Text(e.$1, style: TextStyle(color: _sortBy == e.$2 ? const Color(0xFF00D4FF) : Colors.white38, fontSize: 11)))))),
          ]),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFF0D1321), border: Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
            child: const Row(children: [
              SizedBox(width: 40, child: Text('Proto', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))),
              SizedBox(width: 170, child: Text('Local', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))),
              SizedBox(width: 170, child: Text('Remote', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))),
              SizedBox(width: 110, child: Text('State', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(child: Text('Process (PID)', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))),
            ])),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final c = filtered[i];
              return GestureDetector(
                onSecondaryTap: () => Clipboard.setData(ClipboardData(text: '${c.proto}  ${c.localAddr}:${c.localPort}  ${c.remoteAddr.isNotEmpty ? "${c.remoteAddr}:${c.remotePort}" : ""}  ${c.state}  ${c.process} (${c.pid})')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: i % 2 == 0 ? Colors.transparent : const Color(0xFF0D1321).withOpacity(.4),
                    border: const Border(bottom: BorderSide(color: Color(0xFF1E2D45), width: 0.5))),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text(c.proto, style: TextStyle(color: c.proto == 'UDP' ? Colors.purpleAccent : const Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
                    SizedBox(width: 170, child: Text('${c.localAddr}:${c.localPort}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 170, child: Text(c.remoteAddr.isNotEmpty ? '${c.remoteAddr}:${c.remotePort}' : '—', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 110, child: Text(c.state, style: TextStyle(color: _stateColor(c.state), fontSize: 11, fontFamily: 'monospace'))),
                    Expanded(child: Text('${c.process} (${c.pid})', style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

class _Connection {
  final String proto, localAddr, remoteAddr, state, process;
  final int localPort, remotePort, pid;
  const _Connection({required this.proto, required this.localAddr, required this.localPort, required this.remoteAddr, required this.remotePort, required this.state, required this.pid, required this.process});
}
