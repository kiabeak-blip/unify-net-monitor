import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BannerGrabberScreen extends StatefulWidget {
  const BannerGrabberScreen({super.key});
  @override State<BannerGrabberScreen> createState() => _State();
}

class _State extends State<BannerGrabberScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '80');
  bool _loading = false;
  String? _banner, _error;
  List<_CommonPort> _results = [];

  @override
  void dispose() { _hostCtrl.dispose(); _portCtrl.dispose(); super.dispose(); }

  static const _commonPorts = [
    (21, 'FTP'), (22, 'SSH'), (23, 'Telnet'), (25, 'SMTP'),
    (80, 'HTTP'), (110, 'POP3'), (143, 'IMAP'), (443, 'HTTPS'),
    (3306, 'MySQL'), (3389, 'RDP'), (5432, 'PostgreSQL'), (6379, 'Redis'),
    (8080, 'HTTP Alt'), (27017, 'MongoDB'),
  ];

  Future<void> _grab() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());
    if (host.isEmpty || port == null) return;
    setState(() { _loading = true; _banner = null; _error = null; _results = []; });
    try {
      final banner = await _grabPort(host, port);
      setState(() { _banner = banner ?? '(no banner returned — port open but silent)'; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _scanCommon() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    setState(() { _loading = true; _banner = null; _error = null; _results = []; });
    final results = <_CommonPort>[];
    await Future.wait(_commonPorts.map((p) async {
      try {
        final banner = await _grabPort(host, p.$1, timeout: const Duration(seconds: 3));
        results.add(_CommonPort(port: p.$1, service: p.$2, banner: banner, open: true));
      } catch (_) {
        results.add(_CommonPort(port: p.$1, service: p.$2, banner: null, open: false));
      }
    }));
    results.sort((a, b) => a.port.compareTo(b.port));
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  Future<String?> _grabPort(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final buf = StringBuffer();
    final comp = Completer<void>();
    final sub = socket.listen((data) {
      buf.write(utf8.decode(data, allowMalformed: true));
      if (!comp.isCompleted) comp.complete();
    }, onDone: () { if (!comp.isCompleted) comp.complete(); });
    // For HTTP, send a request
    // Port 443 uses TLS — sending plaintext HTTP would corrupt the handshake.
    // Only send HTTP request on plain HTTP ports.
    if (port == 80 || port == 8080) {
      socket.write('HEAD / HTTP/1.0\r\nHost: $host\r\n\r\n');
    }
    await comp.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    await sub.cancel();
    await socket.close();
    final result = buf.toString().trim();
    return result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Banner Grabber', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Connect to a port and read its service banner for version/fingerprint info', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(flex: 3, child: _field(_hostCtrl, 'Host / IP', 'e.g. 192.168.1.1')),
            const SizedBox(width: 12),
            Expanded(child: _field(_portCtrl, 'Port', '22')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _grab,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
              child: const Text('Grab')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _loading ? null : _scanCommon,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18)),
              child: const Text('Scan Common')),
          ]),
          if (_loading) ...[const SizedBox(height: 16), const LinearProgressIndicator(color: Color(0xFF00D4FF), backgroundColor: Color(0xFF1E2D45))],
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_banner != null) ...[
            const SizedBox(height: 16),
            Row(children: [const Text('Banner', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)), const Spacer(),
              TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _banner!)), icon: const Icon(Icons.copy, size: 13), label: const Text('Copy'), style: TextButton.styleFrom(foregroundColor: Colors.white38))]),
            const SizedBox(height: 4),
            Expanded(child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
              child: SingleChildScrollView(child: SelectableText(_banner!, style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'monospace', fontSize: 12, height: 1.6))))),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Common Ports', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(itemCount: _results.length, itemBuilder: (_, i) {
              final r = _results[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E2D45))),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: r.open ? const Color(0xFF00FF88) : Colors.red.withOpacity(.5), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  SizedBox(width: 50, child: Text('${r.port}', style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600))),
                  SizedBox(width: 90, child: Text(r.service, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                  Expanded(child: Text(r.banner != null ? r.banner!.split('\n').first.substring(0, r.banner!.split('\n').first.length.clamp(0, 80)) : r.open ? 'Open (no banner)' : 'Closed',
                    style: TextStyle(color: r.open ? Colors.white70 : Colors.white24, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                ]),
              );
            })),
          ],
          if (!_loading && _banner == null && _results.isEmpty && _error == null)
            const Expanded(child: Center(child: Text('Enter a host and port to grab its banner', style: TextStyle(color: Colors.white24)))),
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
      onSubmitted: (_) => _grab()),
  ]);
}

class _CommonPort {
  final int port; final String service; final String? banner; final bool open;
  const _CommonPort({required this.port, required this.service, required this.banner, required this.open});
}
