import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DnsLookupScreen extends StatefulWidget {
  const DnsLookupScreen({super.key});

  @override
  State<DnsLookupScreen> createState() => _DnsLookupScreenState();
}

class _DnsLookupScreenState extends State<DnsLookupScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _error;
  _LookupResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isIP(String s) =>
      RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(s);

  Future<void> _lookup() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _LookupResult.fetch(query);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = 'Lookup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS Lookup'),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            onSubmit: _lookup,
            loading: _loading,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                : _error != null
                    ? _ErrorView(message: _error!)
                    : _result != null
                        ? _ResultView(result: _result!)
                        : const _EmptyHint(),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool loading;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter IP or hostname (e.g. 8.8.8.8)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A2235),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF00D4FF), width: 1.5),
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0A0E1A)),
                    )
                  : const Text('Lookup',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result view ─────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final _LookupResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Query info
        _SectionCard(
          icon: Icons.manage_search,
          iconColor: const Color(0xFF00D4FF),
          title: 'Query',
          children: [
            _InfoRow('Input', result.query),
            _InfoRow('Type', result.isIP ? 'IP Address' : 'Hostname'),
          ],
        ),

        // Forward / Reverse DNS
        if (result.resolvedIPs.isNotEmpty)
          _SectionCard(
            icon: Icons.dns,
            iconColor: const Color(0xFF00D4FF),
            title: 'DNS Resolution',
            children: result.resolvedIPs
                .map((ip) => _InfoRow('A Record', ip))
                .toList(),
          ),

        if (result.reverseDns != null)
          _SectionCard(
            icon: Icons.swap_horiz,
            iconColor: const Color(0xFF00D4FF),
            title: 'Reverse DNS (PTR)',
            children: [_InfoRow('Hostname', result.reverseDns!)],
          ),

        // Geo / network info
        if (result.geo != null) ...[
          _SectionCard(
            icon: Icons.public,
            iconColor: const Color(0xFF00FF88),
            title: 'Geolocation',
            children: [
              if (result.geo!.country != null)
                _InfoRow('Country',
                    '${result.geo!.countryFlag} ${result.geo!.country!}'),
              if (result.geo!.region != null)
                _InfoRow('Region', result.geo!.region!),
              if (result.geo!.city != null)
                _InfoRow('City', result.geo!.city!),
              if (result.geo!.lat != null && result.geo!.lon != null)
                _InfoRow(
                    'Coordinates', '${result.geo!.lat}, ${result.geo!.lon}'),
              if (result.geo!.timezone != null)
                _InfoRow('Timezone', result.geo!.timezone!),
            ],
          ),
          _SectionCard(
            icon: Icons.router,
            iconColor: const Color(0xFFFFAA00),
            title: 'Network',
            children: [
              if (result.geo!.isp != null) _InfoRow('ISP', result.geo!.isp!),
              if (result.geo!.org != null) _InfoRow('Org', result.geo!.org!),
              if (result.geo!.asn != null) _InfoRow('ASN', result.geo!.asn!),
            ],
          ),
        ],

        if (result.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(result.error!,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: $value'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.3)),
          const SizedBox(height: 20),
          Text('DNS Lookup',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Enter any public IP or hostname\nto resolve DNS and geo info',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _ExampleChip('8.8.8.8'),
              _ExampleChip('1.1.1.1'),
              _ExampleChip('google.com'),
              _ExampleChip('github.com'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String label;
  const _ExampleChip(this.label);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 12,
              fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF00D4FF).withOpacity(0.08),
      side: const BorderSide(color: Color(0xFF00D4FF), width: 0.5),
      onPressed: () {
        final state =
            context.findAncestorStateOfType<_DnsLookupScreenState>();
        if (state != null) {
          state._controller.text = label;
          state._lookup();
        }
      },
    );
  }
}

// ── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF4466), size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Data model & fetcher ──────────────────────────────────────────────────────

class _GeoInfo {
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final String? isp;
  final String? org;
  final String? asn;
  final String? timezone;
  final double? lat;
  final double? lon;

  _GeoInfo({
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.isp,
    this.org,
    this.asn,
    this.timezone,
    this.lat,
    this.lon,
  });

  String get countryFlag {
    if (countryCode == null || countryCode!.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCodes(
        countryCode!.toUpperCase().codeUnits.map((c) => base + c));
  }

  factory _GeoInfo.fromJson(Map<String, dynamic> j) => _GeoInfo(
        country: j['country'],
        countryCode: j['countryCode'],
        region: j['regionName'],
        city: j['city'],
        isp: j['isp'],
        org: j['org'],
        asn: j['as'],
        timezone: j['timezone'],
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
      );
}

class _LookupResult {
  final String query;
  final bool isIP;
  final List<String> resolvedIPs;
  final String? reverseDns;
  final _GeoInfo? geo;
  final String? error;

  _LookupResult({
    required this.query,
    required this.isIP,
    required this.resolvedIPs,
    this.reverseDns,
    this.geo,
    this.error,
  });

  static Future<_LookupResult> fetch(String query) async {
    final isIP = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(query);
    final resolvedIPs = <String>[];
    String? reverseDns;
    _GeoInfo? geo;
    String? error;

    if (isIP) {
      // Reverse DNS
      try {
        final addr = InternetAddress(query);
        final reversed = await addr.reverse().timeout(const Duration(seconds: 4));
        if (reversed.host != query) reverseDns = reversed.host;
      } catch (_) {}

      // Geo info
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final req = await client
            .getUrl(Uri.parse('http://ip-api.com/json/$query?fields=status,message,country,countryCode,regionName,city,lat,lon,timezone,isp,org,as'));
        final res = await req.close();
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          if (json['status'] == 'success') {
            geo = _GeoInfo.fromJson(json);
          } else {
            error = json['message'] ?? 'Geo lookup failed';
          }
        }
        client.close();
      } catch (e) {
        error = 'Geo lookup unavailable: $e';
      }
    } else {
      // Forward DNS
      try {
        final addresses = await InternetAddress.lookup(query)
            .timeout(const Duration(seconds: 5));
        for (final a in addresses) {
          if (a.type == InternetAddressType.IPv4 &&
              !resolvedIPs.contains(a.address)) {
            resolvedIPs.add(a.address);
          }
        }
      } catch (e) {
        error = 'DNS resolution failed: $e';
      }

      // Geo info for the first resolved IP
      if (resolvedIPs.isNotEmpty) {
        try {
          final ip = resolvedIPs.first;
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 5);
          final req = await client.getUrl(Uri.parse(
              'http://ip-api.com/json/$ip?fields=status,message,country,countryCode,regionName,city,lat,lon,timezone,isp,org,as'));
          final res = await req.close();
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            if (json['status'] == 'success') geo = _GeoInfo.fromJson(json);
          }
          client.close();
        } catch (_) {}
      }
    }

    return _LookupResult(
      query: query,
      isIP: isIP,
      resolvedIPs: resolvedIPs,
      reverseDns: reverseDns,
      geo: geo,
      error: error,
    );
  }
}
