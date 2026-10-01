import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HttpHeaderScreen extends StatefulWidget {
  const HttpHeaderScreen({super.key});
  @override State<HttpHeaderScreen> createState() => _State();
}

class _State extends State<HttpHeaderScreen> {
  final _ctrl = TextEditingController(text: 'https://');
  bool _loading = false, _followRedirects = true;
  String? _error;
  List<_Header> _headers = [];
  int? _statusCode;
  String? _statusMsg;
  final List<_SecurityCheck> _checks = [];

  static const _securityHeaders = {
    'strict-transport-security': ('HSTS', 'Enforces HTTPS', true),
    'content-security-policy': ('CSP', 'Prevents XSS', true),
    'x-frame-options': ('X-Frame-Options', 'Prevents clickjacking', true),
    'x-content-type-options': ('X-Content-Type-Options', 'Prevents MIME sniffing', true),
    'referrer-policy': ('Referrer-Policy', 'Controls referrer info', false),
    'permissions-policy': ('Permissions-Policy', 'Controls browser features', false),
    'x-xss-protection': ('X-XSS-Protection', 'Legacy XSS filter', false),
    'cache-control': ('Cache-Control', 'Cache directives', false),
  };

  Future<void> _fetch() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty || url == 'https://') return;
    setState(() { _loading = true; _error = null; _headers = []; _statusCode = null; _checks.clear(); });
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      if (!_followRedirects) client.maxConnectionsPerHost = 1;
      final req = await client.openUrl('GET', Uri.parse(url));
      req.followRedirects = _followRedirects;
      req.headers.set('User-Agent', 'UnifyNetMonitor/1.0');
      final res = await req.close();
      final headers = <_Header>[];
      res.headers.forEach((name, values) {
        for (final v in values) headers.add(_Header(name: name, value: v));
      });
      headers.sort((a, b) => a.name.compareTo(b.name));
      final checks = _securityHeaders.entries.map((e) {
        final found = headers.any((h) => h.name.toLowerCase() == e.key);
        return _SecurityCheck(name: e.value.$1, description: e.value.$2, present: found, critical: e.value.$3);
      }).toList();
      await res.drain<void>();
      if (!mounted) return;
      setState(() {
        _headers = headers; _statusCode = res.statusCode;
        _statusMsg = _httpStatus(res.statusCode);
        _checks.addAll(checks); _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _httpStatus(int code) {
    const m = {200:'OK',201:'Created',204:'No Content',301:'Moved Permanently',302:'Found',304:'Not Modified',400:'Bad Request',401:'Unauthorized',403:'Forbidden',404:'Not Found',500:'Internal Server Error',502:'Bad Gateway',503:'Service Unavailable'};
    return m[code] ?? '';
  }

  Color _statusColor(int? code) {
    if (code == null) return Colors.white38;
    if (code < 300) return const Color(0xFF00FF88);
    if (code < 400) return Colors.blueAccent;
    if (code < 500) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final score = _checks.isEmpty ? null : (_checks.where((c) => c.present).length / _checks.length * 100).round();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HTTP Header Analyzer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: _dec('URL  e.g. https://example.com'),
              onSubmitted: (_) => _fetch())),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _loading ? null : _fetch,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Fetch')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: _followRedirects, onChanged: (v) => setState(() => _followRedirects = v ?? true), checkColor: Colors.black, fillColor: WidgetStateProperty.all(const Color(0xFF00D4FF)), side: const BorderSide(color: Color(0xFF2A3F5F))),
            const Text('Follow redirects', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
          if (_statusCode != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(_statusCode).withOpacity(.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _statusColor(_statusCode).withOpacity(.4))),
                child: Text('$_statusCode $_statusMsg', style: TextStyle(color: _statusColor(_statusCode), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600))),
              if (score != null) ...[const SizedBox(width: 16),
                Text('Security score: $score%', style: TextStyle(color: score > 70 ? const Color(0xFF00FF88) : score > 40 ? Colors.orangeAccent : Colors.redAccent, fontSize: 13))],
            ]),
          ],
          if (_checks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Security Headers', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _checks.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.present ? const Color(0xFF00FF88).withOpacity(.1) : (c.critical ? Colors.red.withOpacity(.1) : Colors.white.withOpacity(.04)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.present ? const Color(0xFF00FF88).withOpacity(.4) : c.critical ? Colors.red.withOpacity(.3) : const Color(0xFF2A3F5F)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(c.present ? Icons.check : Icons.close, size: 12, color: c.present ? const Color(0xFF00FF88) : c.critical ? Colors.redAccent : Colors.white24),
                const SizedBox(width: 5),
                Text(c.name, style: TextStyle(color: c.present ? const Color(0xFF00FF88) : c.critical ? Colors.redAccent : Colors.white38, fontSize: 11)),
              ]),
            )).toList()),
          ],
          if (_headers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text('${_headers.length} headers', style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5)),
              const Spacer(),
              TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _headers.map((h) => '${h.name}: ${h.value}').join('\n'))),
                icon: const Icon(Icons.copy, size: 13), label: const Text('Copy All'), style: TextButton.styleFrom(foregroundColor: Colors.white38)),
            ]),
            Expanded(child: Container(
              decoration: BoxDecoration(color: const Color(0xFF0D1321), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2D45))),
              child: ListView.builder(itemCount: _headers.length, itemBuilder: (_, i) {
                final h = _headers[i];
                final isSecKey = _securityHeaders.containsKey(h.name.toLowerCase());
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(border: i < _headers.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFF1E2D45))) : null),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 200, child: Text(h.name, style: TextStyle(color: isSecKey ? const Color(0xFF00D4FF) : Colors.white54, fontSize: 12, fontFamily: 'monospace'))),
                    Expanded(child: SelectableText(h.value, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'))),
                  ]),
                );
              }),
            )),
          ] else if (!_loading && _error == null)
            const Expanded(child: Center(child: Text('Enter a URL to analyze its HTTP headers', style: TextStyle(color: Colors.white24)))),
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

class _Header { final String name, value; const _Header({required this.name, required this.value}); }
class _SecurityCheck { final String name, description; final bool present, critical; const _SecurityCheck({required this.name, required this.description, required this.present, required this.critical}); }
