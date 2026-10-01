import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SnmpBrowserScreen extends StatefulWidget {
  const SnmpBrowserScreen({super.key});
  @override State<SnmpBrowserScreen> createState() => _State();
}

class _State extends State<SnmpBrowserScreen> {
  final _hostCtrl = TextEditingController();
  final _communityCtrl = TextEditingController(text: 'public');
  final _oidCtrl = TextEditingController(text: '1.3.6.1.2.1');
  bool _loading = false;
  String? _error;
  List<_OidEntry> _results = [];
  String _version = 'v2c';

  @override
  void dispose() {
    _hostCtrl.dispose();
    _communityCtrl.dispose();
    _oidCtrl.dispose();
    super.dispose();
  }

  static const _quickOids = <String, String>{
    'System Info': '1.3.6.1.2.1.1',
    'Interfaces': '1.3.6.1.2.1.2',
    'IP Addresses': '1.3.6.1.2.1.4.20',
    'TCP Connections': '1.3.6.1.2.1.6.13',
    'UDP Table': '1.3.6.1.2.1.7.5',
    'sysDescr': '1.3.6.1.2.1.1.1.0',
    'sysUpTime': '1.3.6.1.2.1.1.3.0',
    'sysName': '1.3.6.1.2.1.1.5.0',
    'sysContact': '1.3.6.1.2.1.1.4.0',
  };

  Future<void> _query() async {
    final host = _hostCtrl.text.trim();
    final community = _communityCtrl.text.trim().isEmpty ? 'public' : _communityCtrl.text.trim();
    final oid = _oidCtrl.text.trim().isEmpty ? '1.3.6.1.2.1' : _oidCtrl.text.trim();
    if (host.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final ver = _version == 'v1' ? '1' : '2c';
      final res = await Process.run('powershell', ['-NoProfile', '-Command', '''
\$host_target = "$host"
\$community = "$community"
\$oid = "$oid"
\$version = "$ver"
# Try snmpwalk if available
\$snmpwalk = Get-Command snmpwalk -ErrorAction SilentlyContinue
if (\$snmpwalk) {
  \$result = & snmpwalk -v \$version -c \$community \$host_target \$oid 2>&1
  Write-Output "SNMPWALK=\$(\$result -join '|NEWLINE|')"
} else {
  # Try snmpget via Windows SNMP
  Write-Output "ERROR=snmpwalk not found. Install Net-SNMP tools or enable Windows SNMP service and try again."
}
''']);
      final out = res.stdout.toString().trim();
      if (!mounted) return;
      if (out.startsWith('ERROR=')) {
        setState(() { _error = out.substring(6); _loading = false; }); return;
      }
      if (out.startsWith('SNMPWALK=')) {
        final raw = out.substring(9);
        final lines = raw.split('|NEWLINE|').where((l) => l.trim().isNotEmpty).toList();
        final entries = lines.map((line) {
          final idx = line.indexOf(' = ');
          if (idx < 0) return _OidEntry(oid: line, type: '', value: '');
          final left = line.substring(0, idx);
          final right = line.substring(idx + 3);
          final typeIdx = right.indexOf(': ');
          if (typeIdx < 0) return _OidEntry(oid: left, type: '', value: right);
          return _OidEntry(oid: left, type: right.substring(0, typeIdx), value: right.substring(typeIdx + 2));
        }).toList();
        setState(() { _results = entries; _loading = false; });
      } else {
        setState(() { _error = 'Unexpected output'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SNMP Browser', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Query SNMP-enabled devices (requires snmpwalk in PATH)', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(flex: 3, child: _field(_hostCtrl, 'Target Host / IP', '192.168.1.1')),
            const SizedBox(width: 10),
            Expanded(child: _field(_communityCtrl, 'Community String', 'public')),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Version', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                for (final v in ['v1', 'v2c'])
                  Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                    onTap: () => setState(() => _version = v),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _version == v ? const Color(0xFF00D4FF).withOpacity(.15) : const Color(0xFF1A2035),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _version == v ? const Color(0xFF00D4FF) : const Color(0xFF2A3F5F))),
                      child: Text(v, style: TextStyle(color: _version == v ? const Color(0xFF00D4FF) : Colors.white54, fontSize: 13)))))
              ]),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_oidCtrl, 'OID (walk)', '1.3.6.1.2.1')),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _loading ? null : _query,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Walk')),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _quickOids.entries.map((e) => GestureDetector(
            onTap: () { _oidCtrl.text = e.value; _query(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1A2035), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFF2A3F5F))),
              child: Text(e.key, style: const TextStyle(color: Colors.white54, fontSize: 11))))).toList()),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(.3))),
              child: Row(children: [const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)))])),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text('${_results.length} OID values', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _results.map((e) => '${e.oid} = ${e.value}').join('\n'))),
                icon: const Icon(Icons.copy, size: 13), label: const Text('Copy All'), style: TextButton.styleFrom(foregroundColor: Colors.white38)),
            ]),
            Expanded(child: Container(
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
              child: ListView.builder(itemCount: _results.length, itemBuilder: (_, i) {
                final e = _results[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(border: i < _results.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFF1A2535))) : null),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: SelectableText(e.oid, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
                      if (e.type.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF1A2D45), borderRadius: BorderRadius.circular(4)),
                        child: Text(e.type, style: const TextStyle(color: Colors.white38, fontSize: 10))),
                    ]),
                    const SizedBox(height: 2),
                    SelectableText(e.value, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                  ]),
                );
              }),
            )),
          ] else if (!_loading && _error == null)
            const Expanded(child: Center(child: Text('Enter a host and community string to browse SNMP OIDs', style: TextStyle(color: Colors.white24)))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 4),
    TextField(controller: c, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
        filled: true, fillColor: const Color(0xFF1A2035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      onSubmitted: (_) => _query()),
  ]);
}

class _OidEntry { final String oid, type, value; const _OidEntry({required this.oid, required this.type, required this.value}); }
