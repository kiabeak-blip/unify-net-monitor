import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class FirewallTesterScreen extends StatefulWidget {
  const FirewallTesterScreen({super.key});
  @override State<FirewallTesterScreen> createState() => _State();
}

class _State extends State<FirewallTesterScreen> {
  final _hostCtrl = TextEditingController();
  final _customPortCtrl = TextEditingController();
  bool _loading = false;
  List<_PortResult> _results = [];
  int _progress = 0;
  int _totalPorts = 0;

  static const _presets = <String, List<int>>{
    'Web': [80, 443, 8080, 8443],
    'Email': [25, 465, 587, 110, 995, 143, 993],
    'Remote': [22, 23, 3389, 5900],
    'Database': [1433, 1521, 3306, 5432, 6379, 27017],
    'Common': [21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3389, 8080],
    'Top 100': [1,7,9,13,17,19,20,21,22,23,25,26,37,53,79,80,81,88,106,110,111,113,119,135,139,143,144,179,199,389,427,443,444,445,465,513,514,515,543,544,548,554,587,631,646,873,990,993,995,1080,1194,1433,1723,1900,2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,6000,6646,7070,8000,8008,8080,8443,8888,9100,9999,10000,32768,49152,49153,49154,49155,49156,49157],
  };

  String _selectedPreset = 'Common';

  Future<void> _test() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    List<int> ports;
    if (_customPortCtrl.text.trim().isNotEmpty) {
      ports = _customPortCtrl.text.trim().split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((p) => p > 0 && p <= 65535).toList();
    } else {
      ports = _presets[_selectedPreset] ?? [];
    }
    if (ports.isEmpty) return;
    setState(() { _loading = true; _results = []; _progress = 0; _totalPorts = ports.length; });
    final results = <_PortResult>[];
    const batchSize = 20;
    for (var i = 0; i < ports.length; i += batchSize) {
      final batch = ports.sublist(i, (i + batchSize).clamp(0, ports.length));
      await Future.wait(batch.map((port) async {
        final sw = Stopwatch()..start();
        try {
          final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1500));
          sw.stop();
          await socket.close();
          results.add(_PortResult(port: port, open: true, latency: sw.elapsedMilliseconds));
        } catch (_) {
          results.add(_PortResult(port: port, open: false, latency: null));
        }
      }));
      if (mounted) setState(() { _results = List.from(results)..sort((a, b) => a.port.compareTo(b.port)); _progress = i + batch.length; });
    }
    if (mounted) setState(() { _loading = false; _results.sort((a, b) => a.port.compareTo(b.port)); });
  }

  String _serviceName(int port) {
    const m = {21:'FTP',22:'SSH',23:'Telnet',25:'SMTP',53:'DNS',80:'HTTP',110:'POP3',135:'RPC',139:'NetBIOS',143:'IMAP',443:'HTTPS',445:'SMB',465:'SMTPS',587:'SMTP',993:'IMAPS',995:'POP3S',1433:'MSSQL',1723:'PPTP',3306:'MySQL',3389:'RDP',5432:'PostgreSQL',5900:'VNC',6379:'Redis',8080:'HTTP Alt',8443:'HTTPS Alt',27017:'MongoDB'};
    return m[port] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final open = _results.where((r) => r.open).length;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Firewall / Port Tester', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _field(_hostCtrl, 'Target Host / IP', 'e.g. 192.168.1.1 or google.com')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Preset:', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 8),
            ..._presets.keys.map((k) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(onTap: () => setState(() => _selectedPreset = k),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _selectedPreset == k ? const Color(0xFF00D4FF).withOpacity(.15) : const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _selectedPreset == k ? const Color(0xFF00D4FF) : const Color(0xFF2A3F5F))),
                  child: Text(k, style: TextStyle(color: _selectedPreset == k ? const Color(0xFF00D4FF) : Colors.white54, fontSize: 12)))))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_customPortCtrl, 'Custom Ports (overrides preset)', 'e.g. 80,443,8080,3000')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _test,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Test Ports')),
          ]),
          if (_loading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _totalPorts == 0 ? null : _progress / _totalPorts,
              color: const Color(0xFF00D4FF), backgroundColor: const Color(0xFF1E2D45)),
            const SizedBox(height: 4),
            Text('Testing port $_progress...', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text('$open open', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text('${_results.length - open} closed/filtered', style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Expanded(child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                final svc = _serviceName(r.port);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: r.open ? const Color(0xFF00FF88).withOpacity(.08) : const Color(0xFF0D1321),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: r.open ? const Color(0xFF00FF88).withOpacity(.3) : const Color(0xFF1E2D45))),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: r.open ? const Color(0xFF00FF88) : Colors.white12, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${r.port}', style: TextStyle(color: r.open ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      if (svc.isNotEmpty) Text(svc, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ])),
                    if (r.open && r.latency != null) Text('${r.latency}ms', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                );
              },
            )),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Enter a host to test its ports', style: TextStyle(color: Colors.white24)))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 4),
    TextField(controller: c, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF1A2035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      onSubmitted: (_) => _test()),
  ]);
}

class _PortResult { final int port; final bool open; final int? latency; const _PortResult({required this.port, required this.open, required this.latency}); }
