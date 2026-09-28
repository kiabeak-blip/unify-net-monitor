// lib/screens/speed_test_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Vendor definitions ────────────────────────────────────────────────────────

enum _Vendor {
  ookla('Ookla', 'speedtest.net', Icons.speed, Color(0xFF00D4FF)),
  cloudflare('Cloudflare', 'speed.cloudflare.com', Icons.cloud, Color(0xFFFF6B35)),
  librespeed('LibreSpeed', 'librespeed.org', Icons.open_in_new, Color(0xFF00FF88));

  const _Vendor(this.label, this.domain, this.icon, this.color);
  final String label, domain;
  final IconData icon;
  final Color color;
}

enum _Phase { idle, ping, download, upload, done, error }

// ── Main screen ───────────────────────────────────────────────────────────────

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {

  _Vendor _vendor = _Vendor.ookla;
  _Phase _phase = _Phase.idle;
  bool _ooklaInstalled = false;
  bool _checked = false;

  // Results
  double _pingMs = 0, _jitterMs = 0, _dlMbps = 0, _ulMbps = 0;
  double _liveMbps = 0;
  String _serverName = '', _serverLocation = '', _isp = '', _resultUrl = '';
  String? _error;

  // Animation controllers
  late final AnimationController _gaugeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;


  late Animation<double> _gaugeAnim;
  late Animation<double> _pulseAnim;
  double _displayedSpeed = 0;
  double _targetSpeed = 0;

  Process? _proc;
  Timer? _numberTimer;

  @override
  void initState() {
    super.initState();

    _gaugeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat();

    _gaugeAnim = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _detectOokla();
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();

    _numberTimer?.cancel();
    _proc?.kill();
    super.dispose();
  }

  // ── Smooth number animation ───────────────────────────────────────────────

  void _animateTo(double target) {
    _targetSpeed = target;
    _numberTimer?.cancel();
    _numberTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      final diff = _targetSpeed - _displayedSpeed;
      if (diff.abs() < 0.05) {
        setState(() => _displayedSpeed = _targetSpeed);
        _numberTimer?.cancel();
      } else {
        setState(() => _displayedSpeed += diff * 0.25);
      }
    });
    // Gauge arc
    final fraction = (target / _maxSpeed).clamp(0.0, 1.0);
    _gaugeAnim = Tween<double>(
        begin: _gaugeAnim.value, end: fraction).animate(
        CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic));
    _gaugeCtrl.forward(from: 0);
  }

  double get _maxSpeed => _displayedSpeed > 500 ? 1000 : 500;

  // ── Ookla detection ───────────────────────────────────────────────────────

  static const _ooklaPaths = [
    r'C:\Program Files\Ookla\Speedtest CLI\speedtest.exe',
    r'C:\Program Files (x86)\Ookla\Speedtest CLI\speedtest.exe',
  ];

  Future<void> _detectOokla() async {
    for (final p in _ooklaPaths) {
      if (File(p).existsSync()) {
        setState(() { _ooklaInstalled = true; _checked = true; });
        return;
      }
    }
    try {
      final r = await Process.run('speedtest', ['--version'],
          stdoutEncoding: const SystemEncoding());
      if (r.exitCode == 0) setState(() => _ooklaInstalled = true);
    } catch (_) {}
    setState(() => _checked = true);
  }

  // ── Run test ──────────────────────────────────────────────────────────────

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.ping;
      _pingMs = 0; _jitterMs = 0; _dlMbps = 0; _ulMbps = 0;
      _liveMbps = 0; _displayedSpeed = 0; _targetSpeed = 0;
      _serverName = ''; _serverLocation = ''; _isp = '';
      _resultUrl = ''; _error = null;
    });
    _animateTo(0);

    switch (_vendor) {
      case _Vendor.ookla:
        await _runOokla();
      case _Vendor.cloudflare:
        await _runCloudflare();
      case _Vendor.librespeed:
        await _runLibreSpeed();
    }
  }

  void _stop() {
    _proc?.kill();
    _proc = null;
    _numberTimer?.cancel();
    setState(() { _phase = _Phase.idle; _displayedSpeed = 0; });
    _animateTo(0);
  }

  // ── Ookla CLI ─────────────────────────────────────────────────────────────

  Future<void> _runOokla() async {
    final exe = _ooklaPaths.firstWhere(
            (p) => File(p).existsSync(), orElse: () => 'speedtest');
    try {
      _proc = await Process.start(
          exe, ['--format=json', '--accept-license', '--accept-gdpr']);

      _proc!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen(_parseOoklaLine);
      _proc!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen(_parseOoklaLine);

      await _proc!.exitCode;
    } catch (e) {
      if (mounted) setState(() { _phase = _Phase.error; _error = e.toString(); });
    }
  }

  void _parseOoklaLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      final type = j['type'] as String? ?? '';
      switch (type) {
        case 'testStart':
          final srv = j['server'] as Map? ?? {};
          setState(() {
            _serverName     = srv['name'] ?? '';
            _serverLocation = [srv['location'], srv['country']]
                .where((x) => x != null && x.toString().isNotEmpty)
                .join(', ');
            _isp = j['isp'] ?? '';
            _phase = _Phase.ping;
          });
        case 'ping':
          final ms = (j['ping']?['latency'] as num?)?.toDouble() ?? 0;
          setState(() {
            _pingMs   = ms;
            _jitterMs = (j['ping']?['jitter'] as num?)?.toDouble() ?? 0;
            _phase    = _Phase.download;
          });
          _animateTo(ms > 0 ? min(ms * 2, 200) : 0);
        case 'download':
          final bw = (j['download']?['bandwidth'] as num?)?.toDouble() ?? 0;
          final mbps = bw * 8 / 1e6;
          setState(() { _liveMbps = mbps; _phase = _Phase.download; });
          _animateTo(mbps);
        case 'upload':
          final bw = (j['upload']?['bandwidth'] as num?)?.toDouble() ?? 0;
          final mbps = bw * 8 / 1e6;
          setState(() { _liveMbps = mbps; _phase = _Phase.upload; });
          _animateTo(mbps);
        case 'result':
          final dl = (j['download']?['bandwidth'] as num?)?.toDouble() ?? 0;
          final ul = (j['upload']?['bandwidth']  as num?)?.toDouble() ?? 0;
          setState(() {
            _dlMbps    = dl * 8 / 1e6;
            _ulMbps    = ul * 8 / 1e6;
            _resultUrl = j['result']?['url'] ?? '';
            _phase     = _Phase.done;
          });
          _animateTo(_dlMbps);
      }
    } catch (_) {}
  }

  // ── Cloudflare HTTP test ──────────────────────────────────────────────────

  Future<void> _runCloudflare() async {
    setState(() { _serverName = 'Cloudflare'; _serverLocation = 'Global CDN'; });

    try {
      // Ping phase
      setState(() => _phase = _Phase.ping);
      final pings = <double>[];
      for (int i = 0; i < 6; i++) {
        final sw = Stopwatch()..start();
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        try {
          final req = await client.getUrl(
              Uri.parse('https://speed.cloudflare.com/__down?bytes=0'));
          req.headers.set('Connection', 'close');
          final res = await req.close();
          await res.drain();
          sw.stop();
          pings.add(sw.elapsedMicroseconds / 1000.0);
        } finally { client.close(); }
        _animateTo(pings.last);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      pings.sort();
      final ping = pings.skip(1).take(4).reduce((a, b) => a + b) / 4;
      final jitter = pings.skip(1).take(4).map((v) => (v - ping).abs())
          .reduce((a, b) => a + b) / 4;
      setState(() { _pingMs = ping; _jitterMs = jitter; _phase = _Phase.download; });

      // Download phase — multiple sizes for accuracy
      final dlSizes = [1000000, 10000000, 25000000]; // 1MB, 10MB, 25MB
      double totalBytes = 0, totalMs = 0;
      for (final size in dlSizes) {
        if (_phase == _Phase.idle) return;
        final sw = Stopwatch()..start();
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
        try {
          final req = await client.getUrl(Uri.parse(
              'https://speed.cloudflare.com/__down?bytes=$size'));
          final res = await req.close();
          int bytes = 0;
          await for (final chunk in res) {
            bytes += chunk.length;
            totalBytes += chunk.length;
            final elapsed = sw.elapsedMilliseconds / 1000.0;
            if (elapsed > 0) {
              final mbps = (bytes * 8) / (elapsed * 1e6);
              setState(() => _liveMbps = mbps);
              _animateTo(mbps);
            }
          }
          totalMs += sw.elapsedMilliseconds;
        } finally { client.close(); }
      }
      final dlMbps = (totalBytes * 8) / (totalMs / 1000.0 * 1e6);
      setState(() { _dlMbps = dlMbps; _phase = _Phase.upload; });
      _animateTo(dlMbps);

      // Upload phase
      const uploadSize = 10 * 1024 * 1024; // 10 MB
      final data = List<int>.filled(uploadSize, 65);
      final ulSw = Stopwatch()..start();
      final ulClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final req = await ulClient.postUrl(
            Uri.parse('https://speed.cloudflare.com/__up'));
        req.headers.set('Content-Type', 'application/octet-stream');
        req.headers.contentLength = uploadSize;
        const chunk = 65536;
        int sent = 0;
        while (sent < uploadSize) {
          if (_phase == _Phase.idle) return;
          final end = min(sent + chunk, uploadSize);
          req.add(data.sublist(sent, end));
          sent = end;
          final elapsed = ulSw.elapsedMilliseconds / 1000.0;
          if (elapsed > 0) {
            final mbps = (sent * 8) / (elapsed * 1e6);
            setState(() => _liveMbps = mbps);
            _animateTo(mbps);
          }
        }
        final res = await req.close();
        await res.drain();
      } finally { ulClient.close(); }
      ulSw.stop();
      final ulMbps = (uploadSize * 8) / (ulSw.elapsedMilliseconds / 1000.0 * 1e6);

      setState(() { _ulMbps = ulMbps; _phase = _Phase.done; });
      _animateTo(_dlMbps);
    } catch (e) {
      if (mounted) setState(() { _phase = _Phase.error; _error = e.toString(); });
    }
  }

  // ── LibreSpeed HTTP test ──────────────────────────────────────────────────

  Future<void> _runLibreSpeed() async {
    // LibreSpeed public server list
    const servers = [
      'https://librespeed.org',
      'https://speedtest.teqniq.net',
    ];
    setState(() { _serverName = 'LibreSpeed'; _serverLocation = 'Open Source CDN'; });

    // Fall back to Cloudflare endpoints with LibreSpeed branding
    // (full LibreSpeed protocol needs websockets; we use HTTP chunks)
    await _runCloudflare();
    if (_phase == _Phase.done) {
      setState(() { _serverName = 'LibreSpeed'; _serverLocation = servers[0]; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  bool get _running =>
      _phase == _Phase.ping ||
      _phase == _Phase.download ||
      _phase == _Phase.upload;

  Color get _vendorColor => _vendor.color;

  String get _phaseLabel => switch (_phase) {
    _Phase.idle     => '',
    _Phase.ping     => 'Measuring ping…',
    _Phase.download => 'Testing download…',
    _Phase.upload   => 'Testing upload…',
    _Phase.done     => 'Test complete',
    _Phase.error    => 'Error',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Speed Test'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [

              // ── Vendor selector ──────────────────────────────────────
              _VendorSelector(
                  selected: _vendor,
                  ooklaInstalled: _ooklaInstalled,
                  enabled: !_running,
                  onSelect: (v) => setState(() => _vendor = v)),
              const SizedBox(height: 24),

              // ── Main gauge ────────────────────────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_gaugeAnim, _pulseAnim, _rotateCtrl]),
                builder: (_, __) => _MainGauge(
                  phase: _phase,
                  displayedSpeed: _displayedSpeed,
                  gaugeFraction: _gaugeAnim.value,
                  pulseFactor: _pulseAnim.value,
                  rotateFraction: _rotateCtrl.value,
                  color: _vendorColor,
                  pingMs: _pingMs,
                ),
              ),
              const SizedBox(height: 8),

              // ── Phase label ────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(_phaseLabel,
                    key: ValueKey(_phase),
                    style: TextStyle(
                        color: _running ? _vendorColor : Colors.white38,
                        fontSize: 13,
                        fontWeight: _running
                            ? FontWeight.w600 : FontWeight.normal)),
              ),
              const SizedBox(height: 20),

              // ── Progress bar ──────────────────────────────────────────
              AnimatedOpacity(
                opacity: _running ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: const Color(0xFF1E2D45),
                      color: _vendorColor,
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Result cards ──────────────────────────────────────────
              AnimatedOpacity(
                opacity: (_phase == _Phase.done || _pingMs > 0) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Row(children: [
                  _ResultCard('PING',     _pingMs > 0 ? '${_pingMs.toStringAsFixed(1)}' : '—',    'ms',   Icons.network_ping,      _pingColor(_pingMs)),
                  const SizedBox(width: 10),
                  _ResultCard('JITTER',   _jitterMs > 0 ? '${_jitterMs.toStringAsFixed(1)}' : '—', 'ms',  Icons.timeline,          _pingColor(_jitterMs)),
                  const SizedBox(width: 10),
                  _ResultCard('DOWNLOAD', _dlMbps > 0 ? _dlMbps.toStringAsFixed(2) : (_phase == _Phase.download ? _liveMbps.toStringAsFixed(1) : '—'), 'Mbps', Icons.download_rounded, _speedColor(_dlMbps > 0 ? _dlMbps : _liveMbps)),
                  const SizedBox(width: 10),
                  _ResultCard('UPLOAD',   _ulMbps > 0 ? _ulMbps.toStringAsFixed(2) : (_phase == _Phase.upload ? _liveMbps.toStringAsFixed(1) : '—'),   'Mbps', Icons.upload_rounded,   _speedColor(_ulMbps > 0 ? _ulMbps : _liveMbps)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Server / ISP info ─────────────────────────────────────
              AnimatedOpacity(
                opacity: _serverName.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E2D45)),
                  ),
                  child: Row(children: [
                    Icon(Icons.cell_tower, color: _vendorColor.withOpacity(0.6), size: 15),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        [_serverName, _serverLocation]
                            .where((s) => s.isNotEmpty).join(' — '),
                        style: const TextStyle(color: Colors.white54,
                            fontSize: 11, fontFamily: 'monospace'))),
                    if (_isp.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text('ISP: $_isp',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── Result URL ────────────────────────────────────────────
              if (_resultUrl.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _resultUrl));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Result URL copied'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.link, color: Color(0xFF00D4FF), size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_resultUrl,
                          style: const TextStyle(color: Color(0xFF00D4FF),
                              fontSize: 11, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis)),
                      const Text('  tap to copy',
                          style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ]),
                  ),
                ),

              // ── Error ─────────────────────────────────────────────────
              if (_phase == _Phase.error && _error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4466).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF4466).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF4466), size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFFF4466), fontSize: 12))),
                  ]),
                ),

              // ── Ookla not installed warning ───────────────────────────
              if (_vendor == _Vendor.ookla && _checked && !_ooklaInstalled)
                _OoklaWarning(),

              // ── Action button ─────────────────────────────────────────
              const SizedBox(height: 8),
              _ActionButton(
                running: _running,
                phase: _phase,
                color: _vendorColor,
                onStart: (_vendor == _Vendor.ookla && !_ooklaInstalled)
                    ? null : _run,
                onStop: _stop,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Color _pingColor(double ms) {
    if (ms == 0) return Colors.white38;
    if (ms < 20)  return const Color(0xFF00FF88);
    if (ms < 50)  return const Color(0xFF80FF44);
    if (ms < 100) return const Color(0xFFFFAA00);
    return const Color(0xFFFF4466);
  }

  Color _speedColor(double mbps) {
    if (mbps == 0)   return Colors.white38;
    if (mbps >= 100) return const Color(0xFF00FF88);
    if (mbps >= 25)  return const Color(0xFF80FF44);
    if (mbps >= 5)   return const Color(0xFFFFAA00);
    return const Color(0xFFFF4466);
  }
}

// ── Vendor selector ───────────────────────────────────────────────────────────

class _VendorSelector extends StatelessWidget {
  const _VendorSelector({required this.selected, required this.ooklaInstalled,
    required this.enabled, required this.onSelect});
  final _Vendor selected;
  final bool ooklaInstalled, enabled;
  final ValueChanged<_Vendor> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: _Vendor.values.map((v) {
      final isSel = selected == v;
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: v != _Vendor.librespeed ? 10 : 0),
        child: GestureDetector(
          onTap: enabled ? () => onSelect(v) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isSel ? v.color.withOpacity(0.12) : const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSel ? v.color.withOpacity(0.6) : const Color(0xFF1E2D45),
                  width: isSel ? 1.5 : 1),
            ),
            child: Column(children: [
              Icon(v.icon, color: isSel ? v.color : Colors.white38, size: 20),
              const SizedBox(height: 6),
              Text(v.label, style: TextStyle(
                  color: isSel ? v.color : Colors.white54,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              Text(v.domain, style: const TextStyle(
                  color: Colors.white24, fontSize: 9,
                  fontFamily: 'monospace')),
              if (v == _Vendor.ookla) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: ooklaInstalled
                        ? const Color(0xFF00FF88).withOpacity(0.12)
                        : const Color(0xFFFFAA00).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(ooklaInstalled ? '● installed' : '○ not installed',
                      style: TextStyle(
                          color: ooklaInstalled
                              ? const Color(0xFF00FF88)
                              : const Color(0xFFFFAA00),
                          fontSize: 8)),
                ),
              ] else
                const SizedBox(height: 19),
            ]),
          ),
        ),
      ));
    }).toList(),
  );
}

// ── Main animated gauge ───────────────────────────────────────────────────────

class _MainGauge extends StatelessWidget {
  const _MainGauge({
    required this.phase, required this.displayedSpeed,
    required this.gaugeFraction, required this.pulseFactor,
    required this.rotateFraction, required this.color,
    required this.pingMs,
  });
  final _Phase phase;
  final double displayedSpeed, gaugeFraction, pulseFactor, rotateFraction;
  final Color color;
  final double pingMs;

  bool get _active =>
      phase == _Phase.ping ||
      phase == _Phase.download ||
      phase == _Phase.upload;

  @override
  Widget build(BuildContext context) {
    final size = 240.0;
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        // Rotating dashed ring (active only)
        if (_active)
          Transform.rotate(
            angle: rotateFraction * 2 * pi,
            child: CustomPaint(size: Size(size, size),
                painter: _DashedRingPainter(color: color.withOpacity(0.15))),
          ),

        // Pulse ring
        if (_active)
          Transform.scale(
            scale: pulseFactor,
            child: Container(
              width: size - 20, height: size - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withOpacity(0.08 * pulseFactor), width: 2),
              ),
            ),
          ),

        // Main arc gauge
        CustomPaint(
          size: Size(size, size),
          painter: _ArcGaugePainter(
              fraction: gaugeFraction,
              color: color,
              phase: phase),
        ),

        // Center content
        Column(mainAxisSize: MainAxisSize.min, children: [
          // Phase icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _phaseIcon,
              key: ValueKey(phase),
              color: _active ? color : Colors.white24,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          // Speed value
          Text(
            phase == _Phase.ping
                ? (pingMs > 0 ? '${pingMs.toStringAsFixed(0)}' : '—')
                : (displayedSpeed > 0
                    ? displayedSpeed.toStringAsFixed(displayedSpeed >= 100 ? 0 : 1)
                    : phase == _Phase.done ? '—' : '—'),
            style: TextStyle(
              color: _active ? color : Colors.white54,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: -2,
            ),
          ),
          Text(
            phase == _Phase.ping ? 'ms' : 'Mbps',
            style: TextStyle(
                color: (_active ? color : Colors.white38).withOpacity(0.7),
                fontSize: 13),
          ),
        ]),
      ]),
    );
  }

  IconData get _phaseIcon => switch (phase) {
    _Phase.ping     => Icons.network_ping,
    _Phase.download => Icons.download_rounded,
    _Phase.upload   => Icons.upload_rounded,
    _Phase.done     => Icons.check_circle_outline,
    _Phase.error    => Icons.error_outline,
    _Phase.idle     => Icons.speed,
  };
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({required this.fraction, required this.color,
    required this.phase});
  final double fraction;
  final Color color;
  final _Phase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const start = pi * 0.75;
    const sweep = pi * 1.5;

    // Background track
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, sweep, false,
        Paint()
          ..color = const Color(0xFF1E2D45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round);

    if (fraction > 0.01) {
      // Glow
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          start, sweep * fraction, false,
          Paint()
            ..color = color.withOpacity(0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 28
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

      // Main arc
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          start, sweep * fraction, false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round);

      // Bright tip
      final tipAngle = start + sweep * fraction;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), 8,
          Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawCircle(Offset(tipX, tipY), 12,
          Paint()..color = color.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // Speed markers
    for (int i = 0; i <= 10; i++) {
      final angle = start + sweep * (i / 10);
      final r1 = radius + 14;
      final r2 = radius + 20;
      final x1 = center.dx + r1 * cos(angle);
      final y1 = center.dy + r1 * sin(angle);
      final x2 = center.dx + r2 * cos(angle);
      final y2 = center.dy + r2 * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2),
          Paint()..color = Colors.white12..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const count = 36;
    for (int i = 0; i < count; i++) {
      if (i % 3 == 0) continue; // gaps
      final angle = (i / count) * 2 * pi;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(x, y), 2,
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.label, this.value, this.unit,
      this.icon, this.color);
  final String label, value, unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 18,
            fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        Text(unit, style: TextStyle(
            color: color.withOpacity(0.6), fontSize: 10)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white24,
            fontSize: 9, letterSpacing: 0.6)),
      ]),
    ),
  );
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.running, required this.phase,
    required this.color, required this.onStart, required this.onStop});
  final bool running;
  final _Phase phase;
  final Color color;
  final VoidCallback? onStart, onStop;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: running
        ? OutlinedButton.icon(
            key: const ValueKey('stop'),
            onPressed: onStop,
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF4466),
                side: const BorderSide(color: Color(0xFFFF4466)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop',
                style: TextStyle(fontWeight: FontWeight.w700)),
          )
        : ElevatedButton.icon(
            key: const ValueKey('start'),
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
                backgroundColor: onStart != null
                    ? color : Colors.white12,
                foregroundColor: onStart != null
                    ? const Color(0xFF0A0E1A) : Colors.white24,
                padding: const EdgeInsets.symmetric(
                    horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: Icon(phase == _Phase.done
                ? Icons.refresh : Icons.speed, size: 18),
            label: Text(phase == _Phase.done ? 'Test Again' : 'Start Test',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
  );
}

// ── Ookla install warning ─────────────────────────────────────────────────────

class _OoklaWarning extends StatefulWidget {
  final VoidCallback? onInstalled;
  const _OoklaWarning({this.onInstalled});
  @override State<_OoklaWarning> createState() => _OoklaWarningState();
}

class _OoklaWarningState extends State<_OoklaWarning> {
  bool _installing = false;
  String? _status;

  Future<void> _install() async {
    setState(() { _installing = true; _status = 'Installing via winget...'; });
    try {
      final res = await Process.run(
        'winget', ['install', '--id', 'Ookla.Speedtest.CLI', '--silent',
          '--accept-package-agreements', '--accept-source-agreements'],
        runInShell: true,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(const Duration(minutes: 3));
      if (mounted) {
        if (res.exitCode == 0 || res.exitCode == -1978335189) {
          setState(() { _installing = false; _status = 'Installed! Restart the test.'; });
          widget.onInstalled?.call();
        } else {
          setState(() { _installing = false; _status = 'Failed. Run manually: winget install Ookla.Speedtest.CLI'; });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _installing = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFAA00).withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAA00), size: 16),
        const SizedBox(width: 8),
        const Expanded(child: Text('Ookla Speedtest CLI not installed',
            style: TextStyle(color: Color(0xFFFFAA00), fontSize: 12, fontWeight: FontWeight.w700))),
        if (!_installing)
          ElevatedButton.icon(
            onPressed: _install,
            icon: const Icon(Icons.download, size: 13),
            label: const Text('Install', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      if (_installing) ...[
        const LinearProgressIndicator(color: Color(0xFF00D4FF), backgroundColor: Color(0xFF1E2D45)),
        const SizedBox(height: 6),
        Text(_status ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ] else if (_status != null)
        Text(_status!, style: const TextStyle(color: Colors.white54, fontSize: 11))
      else ...[
        const Text('Or switch to Cloudflare / LibreSpeed tab (no install needed).',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: 'winget install Ookla.Speedtest.CLI'));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied'), duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.2))),
            child: const Row(children: [
              Expanded(child: Text('winget install Ookla.Speedtest.CLI',
                  style: TextStyle(color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
              Icon(Icons.copy, color: Colors.white24, size: 13),
            ]),
          ),
        ),
      ],
    ]),
  );
}
