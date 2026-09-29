import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WhoisScreen extends StatefulWidget {
  const WhoisScreen({super.key});
  @override State<WhoisScreen> createState() => _State();
}

class _State extends State<WhoisScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _result, _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _lookup() async {
    final target = _ctrl.text.trim();
    if (target.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final res = await Process.run('powershell', ['-NoProfile', '-Command',
        '''
\$domain = "$target"
try {
  \$whoisPath = (Get-Command whois -ErrorAction SilentlyContinue)?.Source
  if (\$whoisPath) {
    & \$whoisPath \$domain
  } else {
    # Fallback: query whois.iana.org via TCP
    \$tld = \$domain.Split(".")[-1]
    \$tcp = [System.Net.Sockets.TcpClient]::new("whois.iana.org", 43)
    \$stream = \$tcp.GetStream()
    \$writer = [System.IO.StreamWriter]::new(\$stream)
    \$reader = [System.IO.StreamReader]::new(\$stream)
    \$writer.WriteLine(\$tld)
    \$writer.Flush()
    Start-Sleep -Milliseconds 500
    \$iana = \$reader.ReadToEnd()
    \$tcp.Close()
    # Extract whois server from IANA response
    \$serverLine = \$iana -split "\`n" | Where-Object { \$_ -match "^whois:" }
    if (\$serverLine) {
      \$server = (\$serverLine -split "\\s+")[1].Trim()
      \$tcp2 = [System.Net.Sockets.TcpClient]::new(\$server, 43)
      \$stream2 = \$tcp2.GetStream()
      \$writer2 = [System.IO.StreamWriter]::new(\$stream2)
      \$reader2 = [System.IO.StreamReader]::new(\$stream2)
      \$writer2.WriteLine(\$domain)
      \$writer2.Flush()
      Start-Sleep -Milliseconds 800
      \$result = \$reader2.ReadToEnd()
      \$tcp2.Close()
      Write-Output \$result
    } else {
      Write-Output \$iana
    }
  }
} catch {
  Write-Output "Error: \$_"
}
''']);
      final out = res.stdout.toString().trim();
      if (out.isEmpty) {
        setState(() { _error = 'No result returned. Whois may not be installed.'; _loading = false; });
      } else {
        setState(() { _result = out; _loading = false; });
      }
    } catch (e) {
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
          const Text('Whois Lookup', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: _dec('Domain or IP  e.g. google.com or 8.8.8.8'),
              onSubmitted: (_) => _lookup())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Lookup')),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Spacer(),
              TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _result!)),
                icon: const Icon(Icons.copy, size: 14), label: const Text('Copy All'),
                style: TextButton.styleFrom(foregroundColor: Colors.white38)),
            ]),
            Expanded(child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
              child: SingleChildScrollView(child: SelectableText(_result!, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12, height: 1.6))),
            )),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Enter a domain or IP address', style: TextStyle(color: Colors.white24)))),
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
