import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MacVendorScreen extends StatefulWidget {
  const MacVendorScreen({super.key});
  @override State<MacVendorScreen> createState() => _State();
}

class _State extends State<MacVendorScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _vendor, _error, _mac;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _lookup() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    final clean = raw.replaceAll(RegExp(r'[:\-\.]'), '').toUpperCase();
    if (clean.length < 6) { setState(() => _error = 'Enter at least 6 hex digits (OUI)'); return; }
    setState(() { _loading = true; _error = null; _vendor = null; _mac = raw; });
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse('https://api.macvendors.com/${clean.substring(0, 6)}'));
      req.headers.set('User-Agent', 'UnifyNetMonitor/1.0');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200) {
        setState(() { _vendor = body.trim(); _loading = false; });
      } else if (res.statusCode == 404) {
        setState(() { _vendor = 'Unknown / Not in database'; _loading = false; });
      } else {
        setState(() { _error = 'API error: ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _format(String raw) {
    final clean = raw.replaceAll(RegExp(r'[:\-\.\s]'), '').toUpperCase();
    if (clean.length < 12) return raw.toUpperCase();
    final pairs = List.generate(6, (i) => clean.substring(i * 2, i * 2 + 2));
    return pairs.join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MAC Vendor Lookup', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Identify the manufacturer from a MAC address or OUI prefix', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', letterSpacing: 1.2),
              decoration: _dec('MAC address  e.g. 00:1A:2B:3C:4D:5E'),
              onSubmitted: (_) => _lookup())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Lookup')),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_vendor != null) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E2D45))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF00D4FF).withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.memory, color: Color(0xFF00D4FF), size: 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_vendor!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_format(_mac!), style: const TextStyle(color: Color(0xFF00D4FF), fontFamily: 'monospace', fontSize: 13)),
                  ])),
                  IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: _vendor!)),
                    icon: const Icon(Icons.copy, color: Colors.white38, size: 18)),
                ]),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF1E2D45)),
                const SizedBox(height: 12),
                _row('OUI Prefix', _format(_mac!).substring(0, 8)),
                _row('Full MAC', _format(_mac!).length >= 17 ? _format(_mac!) : '—'),
                _row('Type', _isMulticast(_mac!) ? 'Multicast' : _isLocal(_mac!) ? 'Locally Administered' : 'Globally Unique'),
              ]),
            ),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Enter a MAC address to identify its manufacturer', style: TextStyle(color: Colors.white24)))),
        ]),
      ),
    );
  }

  bool _isMulticast(String mac) {
    final clean = mac.replaceAll(RegExp(r'[:\-\.]'), '');
    if (clean.length < 2) return false;
    return (int.tryParse(clean.substring(0, 2), radix: 16) ?? 0) & 1 == 1;
  }

  bool _isLocal(String mac) {
    final clean = mac.replaceAll(RegExp(r'[:\-\.]'), '');
    if (clean.length < 2) return false;
    return (int.tryParse(clean.substring(0, 2), radix: 16) ?? 0) & 2 == 2;
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 140, child: Text(l, style: const TextStyle(color: Colors.white38, fontSize: 13))),
      Text(v, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
    ]));

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1A2035),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14));
}
