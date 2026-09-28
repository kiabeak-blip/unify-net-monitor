import 'dart:io';
import 'package:flutter/material.dart';

class WifiAnalyzerScreen extends StatefulWidget {
  const WifiAnalyzerScreen({super.key});

  @override
  State<WifiAnalyzerScreen> createState() => _WifiAnalyzerScreenState();
}

class _WifiAnalyzerScreenState extends State<WifiAnalyzerScreen> {
  bool _loading = false;
  String? _error;
  List<_WifiNetwork> _networks = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final networks = await _parseNetworks();
      setState(() {
        _networks = networks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<_WifiNetwork>> _parseNetworks() async {
    if (!Platform.isWindows) {
      return [
        _WifiNetwork(
          ssid: 'WiFi Analyzer',
          bssid: 'N/A',
          signal: -65,
          channel: 6,
          band: '2.4 GHz',
          authentication: 'WPA2-Personal',
          encryption: 'CCMP',
          isHidden: false,
        ),
      ];
    }

    final result = await Process.run(
      'netsh',
      ['wlan', 'show', 'networks', 'mode=Bssid'],
      stdoutEncoding: const SystemEncoding(),
    );
    final output = result.stdout.toString();
    return _parseNetshOutput(output);
  }

  List<_WifiNetwork> _parseNetshOutput(String output) {
    final networks = <_WifiNetwork>[];
    final blocks = output.split(RegExp(r'SSID \d+ :'));

    for (int i = 1; i < blocks.length; i++) {
      final block = blocks[i];
      final lines = block.split('\n').map((l) => l.trim()).toList();

      String ssid = lines.isNotEmpty ? lines[0].trim() : '';
      final isHidden = ssid.isEmpty;
      if (isHidden) ssid = '<Hidden Network>';

      String auth = _extract(block, 'Authentication');
      String encryption = _extract(block, 'Encryption');

      // Parse BSSID sub-blocks
      final bssidMatches =
          RegExp(r'BSSID \d+\s*:\s*(.+)').allMatches(block).toList();
      final signalMatches =
          RegExp(r'Signal\s*:\s*(\d+)%').allMatches(block).toList();
      final channelMatches =
          RegExp(r'Channel\s*:\s*(\d+)').allMatches(block).toList();
      final radioMatches =
          RegExp(r'Radio type\s*:\s*(.+)').allMatches(block).toList();

      if (bssidMatches.isEmpty) {
        networks.add(_WifiNetwork(
          ssid: ssid,
          bssid: 'Unknown',
          signal: -100,
          channel: 0,
          band: 'Unknown',
          authentication: auth,
          encryption: encryption,
          isHidden: isHidden,
        ));
        continue;
      }

      for (int j = 0; j < bssidMatches.length; j++) {
        final bssid = bssidMatches[j].group(1)?.trim() ?? 'Unknown';
        final signalPct = j < signalMatches.length
            ? int.tryParse(signalMatches[j].group(1) ?? '0') ?? 0
            : 0;
        final channel = j < channelMatches.length
            ? int.tryParse(channelMatches[j].group(1) ?? '0') ?? 0
            : 0;
        final radioType = j < radioMatches.length
            ? radioMatches[j].group(1)?.trim() ?? ''
            : '';

        final dBm = _pctToDbm(signalPct);
        final band = _detectBand(channel, radioType);

        networks.add(_WifiNetwork(
          ssid: ssid,
          bssid: bssid,
          signal: dBm,
          channel: channel,
          band: band,
          authentication: auth,
          encryption: encryption,
          isHidden: isHidden,
        ));
      }
    }

    // Sort by signal strength (strongest first)
    networks.sort((a, b) => b.signal.compareTo(a.signal));
    return networks;
  }

  String _extract(String block, String key) {
    final match = RegExp('$key\\s*:\\s*(.+)').firstMatch(block);
    return match?.group(1)?.trim() ?? 'Unknown';
  }

  int _pctToDbm(int pct) {
    // Windows reports signal as 0-100%, approximate dBm
    if (pct <= 0) return -100;
    if (pct >= 100) return -50;
    return (-100 + (pct / 2)).round();
  }

  String _detectBand(int channel, String radioType) {
    if (radioType.contains('802.11ax') || radioType.contains('6 GHz')) {
      return '6 GHz';
    }
    if (channel > 14) return '5 GHz';
    if (channel >= 1 && channel <= 14) return '2.4 GHz';
    if (radioType.contains('802.11ac') || radioType.contains('802.11n')) {
      return '5 GHz';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final rogueGroups = _detectRogueAPs(_networks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Analyzer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : _networks.isEmpty
                  ? const Center(
                      child: Text('No Wi-Fi networks found',
                          style: TextStyle(color: Colors.white54)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _buildSummaryRow(rogueGroups),
                        const SizedBox(height: 16),
                        ..._networks.map((n) =>
                            _NetworkCard(network: n, rogueGroups: rogueGroups)),
                      ],
                    ),
    );
  }

  Widget _buildSummaryRow(Set<String> rogueGroups) {
    final hidden = _networks.where((n) => n.isHidden).length;
    final weak = _networks
        .where((n) => _WifiNetwork.isWeakEncryption(n.authentication, n.encryption))
        .length;
    final rogueCount = _networks.where((n) => rogueGroups.contains(n.ssid)).length;

    return Row(
      children: [
        _StatChip('${_networks.length}', 'Networks', const Color(0xFF00D4FF)),
        const SizedBox(width: 8),
        _StatChip('$hidden', 'Hidden', const Color(0xFFFFAA00)),
        const SizedBox(width: 8),
        _StatChip('$weak', 'Weak Enc.', const Color(0xFFFF8C00)),
        const SizedBox(width: 8),
        _StatChip('$rogueCount', 'Rogue?', const Color(0xFFFF4466)),
      ],
    );
  }

  Set<String> _detectRogueAPs(List<_WifiNetwork> networks) {
    // Same SSID with different authentication types = potentially rogue
    final ssidAuth = <String, Set<String>>{};
    for (final n in networks) {
      ssidAuth.putIfAbsent(n.ssid, () => {}).add(n.authentication);
    }
    return ssidAuth.entries
        .where((e) => e.value.length > 1)
        .map((e) => e.key)
        .toSet();
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _WifiNetwork {
  final String ssid;
  final String bssid;
  final int signal; // dBm
  final int channel;
  final String band;
  final String authentication;
  final String encryption;
  final bool isHidden;

  const _WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signal,
    required this.channel,
    required this.band,
    required this.authentication,
    required this.encryption,
    required this.isHidden,
  });

  int get signalPercent {
    final clamped = signal.clamp(-100, -50);
    return ((clamped + 100) * 2).clamp(0, 100);
  }

  Color get signalColor {
    if (signalPercent >= 70) return const Color(0xFF00FF88);
    if (signalPercent >= 40) return const Color(0xFFFFAA00);
    return const Color(0xFFFF4466);
  }

  static bool isWeakEncryption(String auth, String enc) {
    final a = auth.toUpperCase();
    final e = enc.toUpperCase();
    if (a.contains('OPEN') || a == 'NONE') return true;
    if (a.contains('WEP')) return true;
    if (a.contains('WPA') && !a.contains('WPA2') && !a.contains('WPA3')) {
      return true;
    }
    if (e.contains('WEP') || e.contains('TKIP')) return true;
    return false;
  }
}

// ── Network card ──────────────────────────────────────────────────────────────

class _NetworkCard extends StatelessWidget {
  final _WifiNetwork network;
  final Set<String> rogueGroups;

  const _NetworkCard({required this.network, required this.rogueGroups});

  @override
  Widget build(BuildContext context) {
    final isWeak = _WifiNetwork.isWeakEncryption(
        network.authentication, network.encryption);
    final isRogue = rogueGroups.contains(network.ssid);

    Color borderColor = Colors.white.withOpacity(0.08);
    if (isRogue) borderColor = const Color(0xFFFF4466).withOpacity(0.5);
    else if (isWeak) borderColor = const Color(0xFFFFAA00).withOpacity(0.4);
    else if (network.isHidden) borderColor = const Color(0xFFFFAA00).withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  network.isHidden ? Icons.wifi_off : Icons.wifi,
                  color: network.signalColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    network.ssid,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                _BandBadge(network.band),
                if (isWeak) ...[
                  const SizedBox(width: 6),
                  _AlertBadge('WEAK ENC', const Color(0xFFFF8C00)),
                ],
                if (isRogue) ...[
                  const SizedBox(width: 6),
                  _AlertBadge('ROGUE?', const Color(0xFFFF4466)),
                ],
                if (network.isHidden) ...[
                  const SizedBox(width: 6),
                  _AlertBadge('HIDDEN', const Color(0xFFFFAA00)),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Signal bar
            Row(
              children: [
                const Text('Signal',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: network.signalPercent / 100,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      color: network.signalColor,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${network.signal} dBm  (${network.signalPercent}%)',
                  style: TextStyle(
                      color: network.signalColor,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info row
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoPair('BSSID', network.bssid),
                if (network.channel > 0)
                  _InfoPair('Ch', '${network.channel}'),
                _InfoPair('Auth', network.authentication),
                _InfoPair('Enc', network.encryption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BandBadge extends StatelessWidget {
  final String band;
  const _BandBadge(this.band);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (band.contains('6')) {
      color = const Color(0xFFAA00FF);
    } else if (band.contains('5')) {
      color = const Color(0xFF00D4FF);
    } else {
      color = const Color(0xFF00FF88);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(band,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _InfoPair extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPair(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
              text: '$label: ',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
          TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _StatChip(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
