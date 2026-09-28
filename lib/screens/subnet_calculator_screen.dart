import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubnetCalculatorScreen extends StatefulWidget {
  const SubnetCalculatorScreen({super.key});
  @override State<SubnetCalculatorScreen> createState() => _State();
}

class _State extends State<SubnetCalculatorScreen> {
  final _ipCtrl = TextEditingController(text: '192.168.1.0');
  final _cidrCtrl = TextEditingController(text: '24');
  _SubnetResult? _result;
  String? _error;

  void _calculate() {
    setState(() { _error = null; _result = null; });
    final ip = _ipCtrl.text.trim();
    final cidrStr = _cidrCtrl.text.trim();
    final cidr = int.tryParse(cidrStr);
    if (cidr == null || cidr < 0 || cidr > 32) {
      setState(() => _error = 'CIDR must be 0–32'); return;
    }
    final parts = ip.split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null || int.parse(p) > 255)) {
      setState(() => _error = 'Invalid IP address'); return;
    }
    final ipInt = parts.fold<int>(0, (acc, p) => (acc << 8) | int.parse(p));
    final maskInt = cidr == 0 ? 0 : (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    final networkInt = ipInt & maskInt;
    final broadcastInt = networkInt | (~maskInt & 0xFFFFFFFF);
    final hosts = cidr >= 31 ? pow(2, 32 - cidr).toInt() : max(0, pow(2, 32 - cidr).toInt() - 2);
    setState(() => _result = _SubnetResult(
      network: _intToIp(networkInt),
      broadcast: _intToIp(broadcastInt),
      mask: _intToIp(maskInt),
      wildcard: _intToIp(~maskInt & 0xFFFFFFFF),
      firstHost: cidr < 31 ? _intToIp(networkInt + 1) : _intToIp(networkInt),
      lastHost: cidr < 31 ? _intToIp(broadcastInt - 1) : _intToIp(broadcastInt),
      hosts: hosts,
      cidr: cidr,
      ipClass: _getClass(ipInt),
      binary: _toBinary(maskInt),
    ));
  }

  String _intToIp(int i) =>
      '${(i >> 24) & 0xFF}.${(i >> 16) & 0xFF}.${(i >> 8) & 0xFF}.${i & 0xFF}';

  String _toBinary(int mask) {
    final s = mask.toRadixString(2).padLeft(32, '0');
    return '${s.substring(0, 8)}.${s.substring(8, 16)}.${s.substring(16, 24)}.${s.substring(24)}';
  }

  String _getClass(int ip) {
    final first = (ip >> 24) & 0xFF;
    if (first < 128) return 'A';
    if (first < 192) return 'B';
    if (first < 224) return 'C';
    if (first < 240) return 'D (Multicast)';
    return 'E (Reserved)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Subnet Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _field(_ipCtrl, 'IP Address', 'e.g. 192.168.1.0')),
            const SizedBox(width: 12),
            SizedBox(width: 100, child: _field(_cidrCtrl, 'CIDR', '0-32')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: const Text('Calculate'),
            ),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultGrid(_result!),
          ],
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 4),
      TextField(controller: c, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
          filled: true, fillColor: const Color(0xFF1A2035),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        onSubmitted: (_) => _calculate()),
    ],
  );
}

class _SubnetResult {
  final String network, broadcast, mask, wildcard, firstHost, lastHost, ipClass, binary;
  final int hosts, cidr;
  const _SubnetResult({required this.network, required this.broadcast, required this.mask,
    required this.wildcard, required this.firstHost, required this.lastHost,
    required this.hosts, required this.cidr, required this.ipClass, required this.binary});
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid(this.r);
  final _SubnetResult r;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Network Address', r.network), ('Subnet Mask', r.mask),
      ('Broadcast Address', r.broadcast), ('Wildcard Mask', r.wildcard),
      ('First Host', r.firstHost), ('Last Host', r.lastHost),
      ('Usable Hosts', '${r.hosts.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'),
      ('IP Class', r.ipClass), ('CIDR Notation', '/${r.cidr}'),
      ('Binary Mask', r.binary),
    ];
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
      child: Column(children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
          child: Row(children: [
            SizedBox(width: 180, child: Text(e.value.$1, style: const TextStyle(color: Colors.white54, fontSize: 13))),
            Expanded(child: Text(e.value.$2, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'))),
            IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: e.value.$2)),
              icon: const Icon(Icons.copy, size: 14, color: Colors.white24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        );
      }).toList()),
    );
  }
}
