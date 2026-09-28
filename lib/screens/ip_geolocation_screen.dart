import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IpGeolocationScreen extends StatefulWidget {
  const IpGeolocationScreen({super.key});
  @override State<IpGeolocationScreen> createState() => _State();
}

class _State extends State<IpGeolocationScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  Future<void> _lookup([String? ip]) async {
    final target = (ip ?? _ctrl.text.trim()).isEmpty ? '' : (ip ?? _ctrl.text.trim());
    setState(() { _loading = true; _error = null; _data = null; });
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final url = target.isEmpty ? 'http://ip-api.com/json/?fields=66846719' : 'http://ip-api.com/json/$target?fields=66846719';
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'fail') {
        setState(() { _error = json['message'] ?? 'Lookup failed'; _loading = false; });
        return;
      }
      setState(() { _data = json; _loading = false; });
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
          const Text('IP Geolocation', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: _dec('IP address or domain (leave blank for your IP)'),
              onSubmitted: (_) => _lookup())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Lookup')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _loading ? null : () { _ctrl.clear(); _lookup(''); },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Color(0xFF2A3F5F)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
              child: const Text('My IP')),
          ]),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
          if (_data != null) ...[
            const SizedBox(height: 24),
            Expanded(child: _ResultView(_data!)),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Enter an IP or click "My IP"', style: TextStyle(color: Colors.white24)))),
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

class _ResultView extends StatelessWidget {
  const _ResultView(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('IP Address', '${d['query']}'),
      ('Country', '${d['country']} (${d['countryCode']})'),
      ('Region', '${d['regionName']} (${d['region']})'),
      ('City', '${d['city']}'),
      ('ZIP / Postal', '${d['zip']}'),
      ('Latitude', '${d['lat']}'),
      ('Longitude', '${d['lon']}'),
      ('Timezone', '${d['timezone']}'),
      ('ISP', '${d['isp']}'),
      ('Organization', '${d['org']}'),
      ('ASN', '${d['as']}'),
      ('Hostname', '${d['reverse'] ?? '-'}'),
      ('Mobile', d['mobile'] == true ? 'Yes' : 'No'),
      ('Proxy / VPN', d['proxy'] == true ? 'Yes' : 'No'),
      ('Hosting', d['hosting'] == true ? 'Yes' : 'No'),
    ];
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
        child: Column(children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2D45)))),
            child: Row(children: [
              SizedBox(width: 160, child: Text(e.value.$1, style: const TextStyle(color: Colors.white54, fontSize: 13))),
              Expanded(child: Text(e.value.$2 == 'null' ? '—' : e.value.$2, style: const TextStyle(color: Colors.white, fontSize: 13))),
              IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: e.value.$2)),
                icon: const Icon(Icons.copy, size: 13, color: Colors.white24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          );
        }).toList()),
      ),
    );
  }
}
