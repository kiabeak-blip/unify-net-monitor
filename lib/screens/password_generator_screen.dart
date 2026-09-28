import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});
  @override State<PasswordGeneratorScreen> createState() => _State();
}

class _State extends State<PasswordGeneratorScreen> {
  int _length = 16;
  bool _upper = true, _lower = true, _digits = true, _symbols = true, _noAmbig = false;
  final List<String> _history = [];
  String _password = '';
  double _strength = 0;

  @override
  void initState() { super.initState(); _generate(); }

  void _generate() {
    const up = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const upAmbig = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lo = 'abcdefghjkmnpqrstuvwxyz';
    const loAmbig = 'abcdefghijklmnopqrstuvwxyz';
    const dig = '23456789';
    const digAmbig = '0123456789';
    const sym = '!@#\$%^&*-_=+[]{}|;:,.<>?';

    String pool = '';
    if (_upper) pool += _noAmbig ? up : upAmbig;
    if (_lower) pool += _noAmbig ? lo : loAmbig;
    if (_digits) pool += _noAmbig ? dig : digAmbig;
    if (_symbols) pool += sym;
    if (pool.isEmpty) pool = loAmbig;

    final rng = Random.secure();
    final pw = List.generate(_length, (_) => pool[rng.nextInt(pool.length)]).join();
    final entropy = _length * (log(pool.length) / log(2));
    setState(() {
      _password = pw;
      _strength = (entropy / 128).clamp(0.0, 1.0);
      if (_history.isEmpty || _history.first != pw) _history.insert(0, pw);
      if (_history.length > 10) _history.removeLast();
    });
  }

  Color get _strengthColor {
    if (_strength < 0.3) return Colors.redAccent;
    if (_strength < 0.6) return Colors.orangeAccent;
    if (_strength < 0.8) return Colors.yellowAccent;
    return const Color(0xFF00FF88);
  }

  String get _strengthLabel {
    if (_strength < 0.3) return 'Weak';
    if (_strength < 0.6) return 'Fair';
    if (_strength < 0.8) return 'Strong';
    return 'Very Strong';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Password Generator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Password display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
            child: Column(children: [
              SelectableText(_password, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18, letterSpacing: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _strength, backgroundColor: const Color(0xFF1E2D45), valueColor: AlwaysStoppedAnimation(_strengthColor), minHeight: 6)),
              const SizedBox(height: 6),
              Row(children: [
                Text(_strengthLabel, style: TextStyle(color: _strengthColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${(_strength * 128).round()} bits entropy', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: const Text('Generate'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: _password)),
              icon: const Icon(Icons.copy, size: 16), label: const Text('Copy'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(vertical: 14)))),
          ]),
          const SizedBox(height: 24),
          // Options
          _section('Length: $_length'),
          Slider(value: _length.toDouble(), min: 8, max: 64, divisions: 56, activeColor: const Color(0xFF00D4FF),
            onChanged: (v) => setState(() { _length = v.round(); _generate(); })),
          const SizedBox(height: 8),
          _section('Character Sets'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _toggle('A-Z Uppercase', _upper, (v) => setState(() { _upper = v; _generate(); })),
            _toggle('a-z Lowercase', _lower, (v) => setState(() { _lower = v; _generate(); })),
            _toggle('0-9 Numbers', _digits, (v) => setState(() { _digits = v; _generate(); })),
            _toggle('!@# Symbols', _symbols, (v) => setState(() { _symbols = v; _generate(); })),
            _toggle('No Ambiguous (0,O,l,I)', _noAmbig, (v) => setState(() { _noAmbig = v; _generate(); })),
          ]),
          const SizedBox(height: 24),
          if (_history.length > 1) ...[
            _section('History (last 10)'),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
              child: Column(children: _history.skip(1).toList().asMap().entries.map((e) {
                final isLast = e.key == _history.length - 2;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
                  child: Row(children: [
                    Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13))),
                    GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: e.value)),
                      child: const Icon(Icons.copy, size: 14, color: Colors.white24)),
                  ]),
                );
              }).toList()),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)));

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => GestureDetector(
    onTap: () => onChanged(!value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF00D4FF).withOpacity(.12) : const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: value ? const Color(0xFF00D4FF) : const Color(0xFF2A3F5F)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(value ? Icons.check_circle : Icons.circle_outlined, size: 14, color: value ? const Color(0xFF00D4FF) : Colors.white38),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: value ? const Color(0xFF00D4FF) : Colors.white54, fontSize: 12)),
      ]),
    ),
  );
}
