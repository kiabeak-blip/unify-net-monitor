import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WakeOnLanScreen extends StatefulWidget {
  const WakeOnLanScreen({super.key});
  @override State<WakeOnLanScreen> createState() => _State();
}

class _State extends State<WakeOnLanScreen> {
  final _macCtrl = TextEditingController();
  final _ipCtrl = TextEditingController(text: '255.255.255.255');
  final _portCtrl = TextEditingController(text: '9');
  bool _loading = false;
  String? _result, _error;
  final List<_WolEntry> _history = [];

  @override
  void dispose() { _macCtrl.dispose(); _ipCtrl.dispose(); _portCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final raw = _macCtrl.text.trim().replaceAll(RegExp(r'[:\-\. ]'), '').toUpperCase();
    if (raw.length != 12) { setState(() => _error = 'Invalid MAC address — must be 12 hex characters'); return; }
    final mac = <int>[];
    for (var i = 0; i < 12; i += 2) mac.add(int.parse(raw.substring(i, i + 2), radix: 16));
    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) packet[i] = 0xFF;
    for (var rep = 0; rep < 16; rep++) {
      for (var j = 0; j < 6; j++) packet[6 + rep * 6 + j] = mac[j];
    }
    final ip = _ipCtrl.text.trim().isEmpty ? '255.255.255.255' : _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(packet, InternetAddress(ip), port);
      socket.close();
      final formatted = raw.replaceAllMapped(RegExp(r'(..)(?=.)'), (m) => '${m[1]}:');
      _history.insert(0, _WolEntry(mac: formatted, ip: ip, port: port, time: DateTime.now()));
      if (_history.length > 20) _history.removeLast();
      setState(() { _result = 'Magic packet sent to $formatted via $ip:$port'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Wake on LAN', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Send a magic packet to wake a remote machine over the network', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('MAC Address'),
              const SizedBox(height: 4),
              TextField(controller: _macCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
                decoration: _dec('e.g. AA:BB:CC:DD:EE:FF or AA-BB-CC-DD-EE-FF')),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Broadcast / Target IP'),
                  const SizedBox(height: 4),
                  TextField(controller: _ipCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'), decoration: _dec('255.255.255.255')),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Port'),
                  const SizedBox(height: 4),
                  TextField(controller: _portCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'), decoration: _dec('9')),
                ])),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _loading ? null : _send,
                icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.power, size: 16),
                label: const Text('Send Magic Packet'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontWeight: FontWeight.bold)))),
            ])),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00FF88).withOpacity(.3))),
              child: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 18), const SizedBox(width: 8), Expanded(child: Text(_result!, style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13)))])),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(.3))),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
          ],
          const SizedBox(height: 16),
          const Text('PACKET FORMAT', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E2D45))),
            child: const Text('6 bytes × 0xFF  +  MAC address repeated 16 times  =  102 bytes total\nSent as UDP broadcast', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11, height: 1.5))),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('HISTORY', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Expanded(child: ListView.builder(itemCount: _history.length, itemBuilder: (_, i) {
              final h = _history[i];
              return Container(margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF1E2D45))),
                child: Row(children: [
                  const Icon(Icons.power, color: Color(0xFF00D4FF), size: 13),
                  const SizedBox(width: 8),
                  Text(h.mac, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('→ ${h.ip}:${h.port}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                  const Spacer(),
                  Text('${h.time.hour.toString().padLeft(2, '0')}:${h.time.minute.toString().padLeft(2, '0')}:${h.time.second.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')),
                ]));
            })),
          ] else const Spacer(),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12));

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF141C2F),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}

class _WolEntry { final String mac, ip; final int port; final DateTime time; const _WolEntry({required this.mac, required this.ip, required this.port, required this.time}); }
