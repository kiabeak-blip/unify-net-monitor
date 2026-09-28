import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget _notAvailableOnAndroid(String tool) {
  return Scaffold(
    appBar: AppBar(title: Text(tool)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.android, color: Colors.white24, size: 56),
            const SizedBox(height: 20),
            Text(tool, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('$tool is not available on Android.\nUse on Windows desktop for full functionality.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, height: 1.5)),
          ],
        ),
      ),
    ),
  );
}

class NmapScreen extends StatefulWidget {
  final String? initialTarget;
  const NmapScreen({super.key, this.initialTarget});

  @override
  State<NmapScreen> createState() => _NmapScreenState();
}

class _NmapScreenState extends State<NmapScreen> {
  final _targetCtrl = TextEditingController();
  bool _running = false;
  Process? _process;
  _ScanProfile _profile = _ScanProfile.quick;
  _NmapResult? _result;
  String _rawOutput = '';
  String? _error;
  bool _nmapMissing = false;
  bool _installingNmap = false;
  String? _installStatus;
  String _nmapPath = 'nmap'; // resolved on init

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) _targetCtrl.text = widget.initialTarget!;
    _checkNmap();
  }

  @override
  void dispose() {
    _process?.kill();
    _targetCtrl.dispose();
    super.dispose();
  }

  // Common Windows install paths for nmap
  static const _windowsPaths = [
    r'C:\Program Files (x86)\Nmap\nmap.exe',
    r'C:\Program Files\Nmap\nmap.exe',
  ];

  Future<void> _checkNmap() async {
    // First try PATH
    try {
      final result = await Process.run('nmap', ['--version'],
          stdoutEncoding: const SystemEncoding());
      if (result.exitCode == 0) {
        setState(() { _nmapPath = 'nmap'; _nmapMissing = false; });
        return;
      }
    } catch (_) {}

    // Try known install locations (Windows)
    if (Platform.isWindows) {
      for (final path in _windowsPaths) {
        if (File(path).existsSync()) {
          try {
            final result = await Process.run(path, ['--version'],
                stdoutEncoding: const SystemEncoding());
            if (result.exitCode == 0) {
              setState(() { _nmapPath = path; _nmapMissing = false; });
              return;
            }
          } catch (_) {}
        }
      }
    }

    setState(() => _nmapMissing = true);
  }

  Future<void> _installNmap() async {
    setState(() { _installingNmap = true; _installStatus = 'Installing Nmap via winget...'; });
    try {
      final res = await Process.run(
        'winget', ['install', '--id', 'Insecure.Nmap', '--silent', '--accept-package-agreements', '--accept-source-agreements'],
        runInShell: true,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(const Duration(minutes: 3));
      if (res.exitCode == 0 || res.exitCode == -1978335189) {
        // exitCode -1978335189 = already installed (APPINSTALLER_ERROR_ALREADY_INSTALLED)
        if (mounted) setState(() => _installStatus = 'Nmap installed! Detecting...');
        await _checkNmap();
        if (mounted) setState(() { _installingNmap = false; _installStatus = null; });
      } else {
        final err = res.stderr.toString().trim();
        if (mounted) setState(() { _installingNmap = false; _installStatus = 'Install failed: $err\nTry manually: winget install Insecure.Nmap'; });
      }
    } catch (e) {
      if (mounted) setState(() { _installingNmap = false; _installStatus = 'Error: $e'; });
    }
  }

  Future<void> _start() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _running = true;
      _result = null;
      _rawOutput = '';
      _error = null;
    });

    try {
      final args = [
        ..._profile.args,
        '-oX', '-', // XML to stdout
        target,
      ];

      _process = await Process.start(_nmapPath, args);

      final xmlBuffer = StringBuffer();
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((chunk) {
        xmlBuffer.write(chunk);
      }, onDone: () {
        if (mounted) {
          final xml = xmlBuffer.toString();
          setState(() {
            _rawOutput = xml;
            _result = _NmapResult.parse(xml);
            _running = false;
          });
        }
      });

      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((chunk) {
        if (mounted) setState(() => _rawOutput += chunk);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _running = false;
        });
      }
    }
  }

  void _stop() {
    _process?.kill();
    _process = null;
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return _notAvailableOnAndroid('Nmap Scanner');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nmap Scanner'),
        actions: [
          if (_result != null)
            IconButton(
              tooltip: 'Copy raw output',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _rawOutput));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Copied raw output'),
                    duration: Duration(seconds: 1)));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          if (_nmapMissing) _buildMissingBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetCtrl,
                  enabled: !_running,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'IP, range or hostname (e.g. 192.168.1.0/24)',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.manage_search,
                        color: Colors.white38, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A2235),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00D4FF), width: 1.5)),
                  ),
                  onSubmitted: (_) => _running ? _stop() : _start(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _nmapMissing
                      ? null
                      : (_running ? _stop : _start),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _running
                        ? const Color(0xFFFF4466)
                        : const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 18),
                  label: Text(_running ? 'Stop' : 'Scan',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Profile selector
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _ScanProfile.values
                  .map((p) => _ProfileChip(
                        profile: p,
                        selected: _profile == p,
                        onTap: _running
                            ? null
                            : () => setState(() => _profile = p),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4466).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF4466).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4466), size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Nmap is not installed.',
              style: TextStyle(color: Color(0xFFFF4466), fontSize: 13, fontWeight: FontWeight.w600))),
          if (!_installingNmap)
            ElevatedButton.icon(
              onPressed: _installNmap,
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Install Nmap', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
        ]),
        if (_installingNmap) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: Color(0xFF00D4FF), backgroundColor: Color(0xFF1E2D45)),
          const SizedBox(height: 6),
          Text(_installStatus ?? 'Installing...', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ] else if (_installStatus != null) ...[
          const SizedBox(height: 6),
          Text(_installStatus!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ] else ...[
          const SizedBox(height: 4),
          const Text('Click "Install Nmap" to install automatically, or run: winget install Insecure.Nmap',
              style: TextStyle(color: Color(0xFFFF4466), fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _buildBody() {
    if (_running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Color(0xFF00D4FF)),
            ),
            const SizedBox(height: 20),
            Text('Scanning ${_targetCtrl.text.trim()}…',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text(_profile.label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: const TextStyle(color: Color(0xFFFF4466), fontSize: 13)),
      );
    }

    if (_result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search,
                size: 72,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
            const SizedBox(height: 20),
            const Text('Nmap Scanner',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Enter an IP, range, or hostname\nthen select a scan profile',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _QuickChip('192.168.1.1'),
                _QuickChip('192.168.1.0/24'),
                _QuickChip('scanme.nmap.org'),
              ],
            ),
          ],
        ),
      );
    }

    return _NmapResultView(result: _result!);
  }
}

// ── Result view ───────────────────────────────────────────────────────────────

class _NmapResultView extends StatelessWidget {
  final _NmapResult result;
  const _NmapResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              _SummaryItem(
                  label: 'Hosts Up',
                  value: '${result.hosts.where((h) => h.isUp).length}',
                  color: const Color(0xFF00FF88)),
              _SummaryItem(
                  label: 'Hosts Down',
                  value:
                      '${result.hosts.where((h) => !h.isUp).length}',
                  color: const Color(0xFFFF4466)),
              _SummaryItem(
                  label: 'Open Ports',
                  value:
                      '${result.hosts.expand((h) => h.ports).where((p) => p.state == 'open').length}',
                  color: const Color(0xFF00D4FF)),
              Expanded(
                child: Text(
                  result.scanTime,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),

        // Host cards
        ...result.hosts.map((host) => _HostCard(host: host)),

        if (result.hosts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hosts found in scan results.',
                  style: TextStyle(color: Colors.white38)),
            ),
          ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Host card ─────────────────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final _NmapHost host;
  const _HostCard({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    final openPorts = host.ports.where((p) => p.state == 'open').toList();
    final statusColor =
        host.isUp ? const Color(0xFF00FF88) : const Color(0xFFFF4466);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: host.isUp
              ? const Color(0xFF00FF88).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Host header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: host.isUp
                        ? [BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host.hostname.isNotEmpty ? host.hostname : host.ip,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace'),
                      ),
                      if (host.hostname.isNotEmpty)
                        Text(host.ip,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Text(host.isUp ? 'up' : 'down',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                if (host.latency.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(host.latency,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ],
            ),
          ),

          // OS detection
          if (host.os.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAA00).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFAA00).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer,
                      size: 14, color: Color(0xFFFFAA00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(host.os,
                        style: const TextStyle(
                            color: Color(0xFFFFAA00),
                            fontSize: 11,
                            fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ],

          // Ports
          if (openPorts.isNotEmpty) ...[
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                '${openPorts.length} OPEN PORT${openPorts.length != 1 ? 'S' : ''}',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0),
              ),
            ),
            ...openPorts.map((port) => _PortRow(port: port)),
          ] else if (host.isUp)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text('No open ports found',
                  style:
                      TextStyle(color: Colors.white24, fontSize: 12)),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Port row ──────────────────────────────────────────────────────────────────

class _PortRow extends StatelessWidget {
  final _NmapPort port;
  const _PortRow({super.key, required this.port});

  @override
  Widget build(BuildContext context) {
    final isOpen = port.state == 'open';
    final color = isOpen ? const Color(0xFF00FF88) : const Color(0xFFFF4466);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text('${port.port}/${port.protocol}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontFamily: 'monospace')),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(port.state,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              port.service.isNotEmpty ? port.service : '—',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ),
          if (port.version.isNotEmpty)
            Flexible(
              child: Text(port.version,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
        ],
      ),
    );
  }
}

// ── Scan profile ──────────────────────────────────────────────────────────────

enum _ScanProfile {
  quick('Quick', '-T4 -F', 'Top 100 ports'),
  standard('Standard', '-T4', 'Top 1000 ports'),
  service('Services', '-T4 -sV', 'Service & version detection'),
  os('OS Detect', '-T4 -O', 'OS fingerprinting'),
  aggressive('Aggressive', '-T4 -A', 'OS + version + scripts');

  final String label;
  final String _argStr;
  final String description;

  const _ScanProfile(this.label, this._argStr, this.description);

  List<String> get args => _argStr.split(' ');
}

class _ProfileChip extends StatelessWidget {
  final _ScanProfile profile;
  final bool selected;
  final VoidCallback? onTap;
  const _ProfileChip(
      {required this.profile, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color.withOpacity(0.5) : Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile.label,
                style: TextStyle(
                    color: selected ? color : Colors.white54,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ── Quick chip ────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  const _QuickChip(this.label);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(
              color: Color(0xFF00D4FF), fontSize: 12, fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF00D4FF).withOpacity(0.08),
      side: const BorderSide(color: Color(0xFF00D4FF), width: 0.5),
      onPressed: () {
        final state = context.findAncestorStateOfType<_NmapScreenState>();
        if (state != null) {
          state._targetCtrl.text = label;
          state._start();
        }
      },
    );
  }
}

// ── XML Parser ────────────────────────────────────────────────────────────────

class _NmapResult {
  final List<_NmapHost> hosts;
  final String scanTime;

  _NmapResult({required this.hosts, required this.scanTime});

  static _NmapResult parse(String xml) {
    final hosts = <_NmapHost>[];
    String scanTime = '';

    // Extract scan time
    final timeMatch = RegExp(r'elapsed="([\d.]+)"').firstMatch(xml);
    if (timeMatch != null) scanTime = '${timeMatch.group(1)}s elapsed';

    // Extract hosts
    final hostRegex = RegExp(r'<host\b[^>]*>(.*?)</host>', dotAll: true);
    for (final hostMatch in hostRegex.allMatches(xml)) {
      final hostXml = hostMatch.group(1)!;
      hosts.add(_NmapHost.parse(hostXml));
    }

    return _NmapResult(hosts: hosts, scanTime: scanTime);
  }
}

class _NmapHost {
  final String ip;
  final String hostname;
  final bool isUp;
  final String latency;
  final String os;
  final List<_NmapPort> ports;

  _NmapHost({
    required this.ip,
    required this.hostname,
    required this.isUp,
    required this.latency,
    required this.os,
    required this.ports,
  });

  static _NmapHost parse(String xml) {
    // IP
    final ipMatch = RegExp(r'addrtype="ipv4"[^/]*addr="([^"]+)"')
        .firstMatch(xml);
    final ip = ipMatch?.group(1) ?? '';

    // Hostname
    final hnMatch = RegExp(r'<hostname\s[^>]*name="([^"]+)"').firstMatch(xml);
    final hostname = hnMatch?.group(1) ?? '';

    // Status
    final stateMatch = RegExp(r'<status\s[^>]*state="([^"]+)"').firstMatch(xml);
    final isUp = stateMatch?.group(1) == 'up';

    // Latency
    final latMatch = RegExp(r'srtt="(\d+)"').firstMatch(xml);
    String latency = '';
    if (latMatch != null) {
      final us = int.tryParse(latMatch.group(1)!) ?? 0;
      latency = '${(us / 1000).toStringAsFixed(1)}ms';
    }

    // OS
    String os = '';
    final osMatch =
        RegExp(r'<osmatch\s[^>]*name="([^"]+)"').firstMatch(xml);
    if (osMatch != null) os = osMatch.group(1)!;

    // Ports
    final ports = <_NmapPort>[];
    final portRegex = RegExp(r'<port\s+protocol="([^"]+)"\s+portid="(\d+)">(.*?)</port>',
        dotAll: true);
    for (final pm in portRegex.allMatches(xml)) {
      final protocol = pm.group(1)!;
      final portNum = pm.group(2)!;
      final portXml = pm.group(3)!;

      final stMatch =
          RegExp(r'<state\s[^>]*state="([^"]+)"').firstMatch(portXml);
      final state = stMatch?.group(1) ?? 'unknown';

      final svcMatch =
          RegExp(r'<service\s[^>]*name="([^"]+)"').firstMatch(portXml);
      final service = svcMatch?.group(1) ?? '';

      final verMatch =
          RegExp(r'product="([^"]+)"').firstMatch(portXml);
      final extraMatch =
          RegExp(r'extrainfo="([^"]+)"').firstMatch(portXml);
      final versionMatch =
          RegExp(r'version="([^"]+)"').firstMatch(portXml);
      final version = [
        verMatch?.group(1),
        versionMatch?.group(1),
        extraMatch?.group(1),
      ].whereType<String>().join(' ');

      ports.add(_NmapPort(
        port: portNum,
        protocol: protocol,
        state: state,
        service: service,
        version: version,
      ));
    }

    return _NmapHost(
        ip: ip,
        hostname: hostname,
        isUp: isUp,
        latency: latency,
        os: os,
        ports: ports);
  }
}

class _NmapPort {
  final String port;
  final String protocol;
  final String state;
  final String service;
  final String version;

  const _NmapPort({
    required this.port,
    required this.protocol,
    required this.state,
    required this.service,
    required this.version,
  });
}
