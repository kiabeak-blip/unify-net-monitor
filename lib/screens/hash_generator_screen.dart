import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HashGeneratorScreen extends StatefulWidget {
  const HashGeneratorScreen({super.key});
  @override State<HashGeneratorScreen> createState() => _State();
}

class _State extends State<HashGeneratorScreen> {
  final _ctrl = TextEditingController();
  bool _isHex = false;
  Map<String, String> _hashes = {};

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _compute() {
    final text = _ctrl.text;
    if (text.isEmpty) { setState(() => _hashes = {}); return; }
    late List<int> bytes;
    if (_isHex) {
      try {
        bytes = List.generate(text.replaceAll(' ', '').length ~/ 2,
            (i) => int.parse(text.replaceAll(' ', '').substring(i * 2, i * 2 + 2), radix: 16));
      } catch (_) { setState(() => _hashes = {'Error': 'Invalid hex input'}); return; }
    } else {
      bytes = utf8.encode(text);
    }
    setState(() => _hashes = {
      'MD5': md5.convert(bytes).toString(),
      'SHA-1': sha1.convert(bytes).toString(),
      'SHA-256': sha256.convert(bytes).toString(),
      'SHA-384': sha384.convert(bytes).toString(),
      'SHA-512': sha512.convert(bytes).toString(),
      'HMAC-SHA256 (key=text)': Hmac(sha256, bytes).convert(bytes).toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hash Generator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            const Text('Input as:', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 12),
            _chip('Text', !_isHex, () => setState(() { _isHex = false; _compute(); })),
            const SizedBox(width: 8),
            _chip('Hex', _isHex, () => setState(() { _isHex = true; _compute(); })),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            decoration: _dec('Enter text or data to hash...'),
            onChanged: (_) => _compute(),
          ),
          const SizedBox(height: 20),
          if (_hashes.isNotEmpty) ...[
            const Text('Results', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
                child: ListView(children: _hashes.entries.toList().asMap().entries.map((e) {
                  final isLast = e.key == _hashes.length - 1;
                  final name = e.value.key; final hash = e.value.value;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(name, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Clipboard.setData(ClipboardData(text: hash)),
                          child: const Row(children: [Icon(Icons.copy, size: 13, color: Colors.white38), SizedBox(width: 4), Text('Copy', style: TextStyle(color: Colors.white38, fontSize: 11))]),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      SelectableText(hash, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
                    ]),
                  );
                }).toList()),
              ),
            ),
          ] else
            const Expanded(child: Center(child: Text('Type something above to generate hashes', style: TextStyle(color: Colors.white24)))),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF00D4FF).withOpacity(.15) : const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFF00D4FF) : const Color(0xFF2A3F5F)),
      ),
      child: Text(label, style: TextStyle(color: active ? const Color(0xFF00D4FF) : Colors.white54, fontSize: 13)),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1A2035),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
    contentPadding: const EdgeInsets.all(12),
  );
}
