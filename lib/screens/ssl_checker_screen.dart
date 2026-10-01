import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SslCheckerScreen extends StatefulWidget {
  const SslCheckerScreen({super.key});
  @override State<SslCheckerScreen> createState() => _State();
}

class _State extends State<SslCheckerScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  _SslResult? _result;
  String? _error;

  Future<void> _check() async {
    var host = _ctrl.text.trim().replaceAll(RegExp(r'^https?://'), '').split('/').first;
    if (host.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final res = await Process.run('powershell', ['-NoProfile', '-Command', '''
\$targetHost = "$host"
\$port = 443
try {
  \$tcpClient = [System.Net.Sockets.TcpClient]::new(\$targetHost, \$port)
  \$sslStream = [System.Net.Security.SslStream]::new(\$tcpClient.GetStream(), \$false, { \$true })
  \$sslStream.AuthenticateAsClient(\$targetHost)
  \$cert = \$sslStream.RemoteCertificate
  \$cert2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]::\$cert
  Write-Output "Subject=\$(\$cert.Subject)"
  Write-Output "Issuer=\$(\$cert.Issuer)"
  Write-Output "NotBefore=\$(\$cert.GetEffectiveDateString())"
  Write-Output "NotAfter=\$(\$cert.GetExpirationDateString())"
  Write-Output "Protocol=\$(\$sslStream.SslProtocol)"
  Write-Output "CipherAlg=\$(\$sslStream.CipherAlgorithm)"
  Write-Output "CipherStrength=\$(\$sslStream.CipherStrength)"
  Write-Output "HashAlg=\$(\$sslStream.HashAlgorithm)"
  Write-Output "Thumbprint=\$(\$cert.GetCertHashString())"
  Write-Output "SerialNumber=\$(\$cert.GetSerialNumberString())"
  \$sslStream.Close()
  \$tcpClient.Close()
} catch {
  Write-Output "ERROR=\$_"
}
''']);
      final out = res.stdout.toString().trim();
      if (!mounted) return;
      if (out.startsWith('ERROR=')) {
        setState(() { _error = out.substring(6); _loading = false; }); return;
      }
      final map = <String, String>{};
      for (final line in out.split('\n')) {
        final idx = line.indexOf('=');
        if (idx > 0) map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
      }
      if (map.isEmpty) { if (mounted) setState(() { _error = 'Could not parse result'; _loading = false; }); return; }

      final expiry = _parseDate(map['NotAfter'] ?? '');
      final now = DateTime.now();
      final daysLeft = expiry != null ? expiry.difference(now).inDays : null;

      setState(() {
        _result = _SslResult(
          host: host,
          subject: map['Subject'] ?? '—',
          issuer: map['Issuer'] ?? '—',
          notBefore: map['NotBefore'] ?? '—',
          notAfter: map['NotAfter'] ?? '—',
          protocol: map['Protocol'] ?? '—',
          cipher: '${map['CipherAlg'] ?? ''} ${map['CipherStrength'] ?? ''}bit'.trim(),
          hash: map['HashAlg'] ?? '—',
          thumbprint: map['Thumbprint'] ?? '—',
          serial: map['SerialNumber'] ?? '—',
          daysLeft: daysLeft,
          valid: daysLeft != null && daysLeft > 0,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  DateTime? _parseDate(String s) {
    // ISO 8601 format
    try { return DateTime.parse(s); } catch (_) {}
    // PowerShell Windows locale: M/d/yyyy h:mm:ss AM/PM  e.g. "1/15/2025 3:00:00 PM"
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    if (m != null) {
      try {
        return DateTime(int.parse(m.group(3)!), int.parse(m.group(1)!), int.parse(m.group(2)!));
      } catch (_) {}
    }
    // DD-MM-YYYY fallback
    try { return DateTime.tryParse(s.replaceAll('/', '-')); } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SSL / TLS Certificate Checker', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: _dec('Domain  e.g. google.com'),
              onSubmitted: (_) => _check())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _check,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Check')),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), _errBox(_error!)],
          if (_result != null) ...[const SizedBox(height: 24), _ResultCard(_result!)],
        ]),
      ),
    );
  }

  Widget _errBox(String e) => Container(padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.red.withOpacity(.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(.3))),
    child: Text(e, style: const TextStyle(color: Colors.redAccent, fontSize: 13)));

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1A2035),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00D4FF))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14));
}

class _SslResult {
  final String host, subject, issuer, notBefore, notAfter, protocol, cipher, hash, thumbprint, serial;
  final int? daysLeft;
  final bool valid;
  const _SslResult({required this.host, required this.subject, required this.issuer,
    required this.notBefore, required this.notAfter, required this.protocol,
    required this.cipher, required this.hash, required this.thumbprint,
    required this.serial, required this.daysLeft, required this.valid});
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final _SslResult r;

  @override
  Widget build(BuildContext context) {
    final statusColor = !r.valid ? Colors.redAccent : r.daysLeft != null && r.daysLeft! < 30 ? Colors.orangeAccent : const Color(0xFF00FF88);
    final statusLabel = !r.valid ? 'EXPIRED' : r.daysLeft != null && r.daysLeft! < 30 ? 'EXPIRING SOON' : 'VALID';

    final rows = [
      ('Subject', r.subject), ('Issuer', r.issuer),
      ('Valid From', r.notBefore), ('Expires', r.notAfter),
      ('Days Remaining', r.daysLeft != null ? '${r.daysLeft} days' : '—'),
      ('Protocol', r.protocol), ('Cipher Suite', r.cipher),
      ('Hash Algorithm', r.hash), ('Serial Number', r.serial),
      ('Thumbprint', r.thumbprint),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: statusColor.withOpacity(.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(.3))),
        child: Row(children: [
          Icon(r.valid ? Icons.verified_user : Icons.gpp_bad, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(r.host, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
        child: Column(children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 160, child: Text(e.value.$1, style: const TextStyle(color: Colors.white54, fontSize: 13))),
              Expanded(child: SelectableText(e.value.$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'))),
              IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: e.value.$2)),
                icon: const Icon(Icons.copy, size: 13, color: Colors.white24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          );
        }).toList()),
      ),
    ]);
  }
}
