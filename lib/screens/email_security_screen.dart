import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmailSecurityScreen extends StatefulWidget {
  const EmailSecurityScreen({super.key});
  @override State<EmailSecurityScreen> createState() => _State();
}

class _State extends State<EmailSecurityScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  _EmailResult? _result;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _check() async {
    final domain = _ctrl.text.trim().replaceAll(RegExp(r'^.*@'), '');
    if (domain.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final res = await Process.run('powershell', ['-NoProfile', '-Command', '''
\$domain = "$domain"
function Get-DnsRecord(\$Name, \$Type) {
  try { (Resolve-DnsName -Name \$Name -Type \$Type -ErrorAction Stop) | ForEach-Object { \$_.Strings -join "" } } catch { "" }
}
# MX
\$mx = try { (Resolve-DnsName -Name \$domain -Type MX -ErrorAction Stop) | Sort-Object Preference | ForEach-Object { "\$(\$_.Preference) \$(\$_.NameExchange)" } } catch { @() }
Write-Output "MX=\$(\$mx -join "|")"
# SPF
\$spf = try { (Resolve-DnsName -Name \$domain -Type TXT -ErrorAction Stop) | Where-Object { \$_.Strings -match "v=spf1" } | ForEach-Object { \$_.Strings -join "" } } catch { "" }
Write-Output "SPF=\$spf"
# DMARC
\$dmarc = try { (Resolve-DnsName -Name "_dmarc.\$domain" -Type TXT -ErrorAction Stop) | ForEach-Object { \$_.Strings -join "" } } catch { "" }
Write-Output "DMARC=\$dmarc"
# DKIM (common selectors)
\$dkimSelectors = @("default","google","k1","k2","mail","dkim","selector1","selector2","s1","s2")
\$dkimFound = @()
foreach (\$sel in \$dkimSelectors) {
  try {
    \$r = (Resolve-DnsName -Name "\$sel._domainkey.\$domain" -Type TXT -ErrorAction Stop)
    if (\$r) { \$dkimFound += "\$sel: \$(\$r | ForEach-Object { \$_.Strings -join "" } | Select-Object -First 1)" }
  } catch {}
}
Write-Output "DKIM=\$(\$dkimFound -join "|")"
# BIMI
\$bimi = try { (Resolve-DnsName -Name "default._bimi.\$domain" -Type TXT -ErrorAction Stop) | ForEach-Object { \$_.Strings -join "" } } catch { "" }
Write-Output "BIMI=\$bimi"
# MTA-STS
\$mtasts = try { (Resolve-DnsName -Name "_mta-sts.\$domain" -Type TXT -ErrorAction Stop) | ForEach-Object { \$_.Strings -join "" } } catch { "" }
Write-Output "MTASTS=\$mtasts"
''']);
      final out = res.stdout.toString().trim();
      if (!mounted) return;
      if (out.isEmpty) { setState(() { _error = 'No DNS data returned'; _loading = false; }); return; }
      final map = <String, String>{};
      for (final line in out.split('\n')) {
        final idx = line.indexOf('=');
        if (idx > 0) map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
      }
      setState(() {
        _result = _EmailResult(
          domain: domain,
          mx: map['MX']?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
          spf: map['SPF'] ?? '',
          dmarc: map['DMARC'] ?? '',
          dkim: map['DKIM']?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
          bimi: map['BIMI'] ?? '',
          mtaSts: map['MTASTS'] ?? '',
        );
        _loading = false;
      });
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
          const Text('Email Security Checker', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Check SPF, DMARC, DKIM, MX and other email security records', style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: _dec('Domain or email  e.g. gmail.com or user@company.com'),
              onSubmitted: (_) => _check())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _check,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Check')),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: _ResultView(_result!))),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Enter a domain to check its email security', style: TextStyle(color: Colors.white24)))),
        ]),
      ),
    );
  }

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1A2035),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14));
}

class _EmailResult {
  final String domain, spf, dmarc, bimi, mtaSts;
  final List<String> mx, dkim;
  const _EmailResult({required this.domain, required this.mx, required this.spf, required this.dmarc, required this.dkim, required this.bimi, required this.mtaSts});
}

class _ResultView extends StatelessWidget {
  const _ResultView(this.r);
  final _EmailResult r;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary badges
      Wrap(spacing: 8, runSpacing: 8, children: [
        _badge('SPF', r.spf.isNotEmpty),
        _badge('DMARC', r.dmarc.isNotEmpty),
        _badge('DKIM', r.dkim.isNotEmpty),
        _badge('MX', r.mx.isNotEmpty),
        _badge('BIMI', r.bimi.isNotEmpty),
        _badge('MTA-STS', r.mtaSts.isNotEmpty),
      ]),
      const SizedBox(height: 20),
      _section('MX Records', r.mx.isEmpty ? ['No MX records found'] : r.mx, r.mx.isNotEmpty),
      const SizedBox(height: 12),
      _section('SPF', r.spf.isEmpty ? ['No SPF record found'] : [r.spf], r.spf.isNotEmpty),
      const SizedBox(height: 12),
      _section('DMARC', r.dmarc.isEmpty ? ['No DMARC record found'] : [r.dmarc], r.dmarc.isNotEmpty),
      const SizedBox(height: 12),
      _section('DKIM', r.dkim.isEmpty ? ['No DKIM records found (checked common selectors)'] : r.dkim, r.dkim.isNotEmpty),
      if (r.bimi.isNotEmpty) ...[const SizedBox(height: 12), _section('BIMI', [r.bimi], true)],
      if (r.mtaSts.isNotEmpty) ...[const SizedBox(height: 12), _section('MTA-STS', [r.mtaSts], true)],
    ]);
  }

  Widget _badge(String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: ok ? const Color(0xFF00FF88).withOpacity(.1) : Colors.red.withOpacity(.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ok ? const Color(0xFF00FF88).withOpacity(.4) : Colors.red.withOpacity(.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ok ? Icons.check_circle : Icons.cancel, size: 13, color: ok ? const Color(0xFF00FF88) : Colors.redAccent),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: ok ? const Color(0xFF00FF88) : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _section(String title, List<String> lines, bool ok) => Container(
    decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D45))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 14, color: ok ? const Color(0xFF00FF88) : Colors.redAccent),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (ok) GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: lines.join('\n'))),
          child: const Icon(Icons.copy, size: 13, color: Colors.white24)),
      ])),
      const Divider(height: 1, color: Color(0xFF1E2D45)),
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) => SelectableText(l, style: TextStyle(color: ok ? Colors.white70 : Colors.white38, fontFamily: 'monospace', fontSize: 11, height: 1.5))).toList())),
    ]),
  );
}
