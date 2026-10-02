// lib/screens/camera_scanner_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

// ─── Camera brand profiles ────────────────────────────────────────────────
class _BrandProfile {
  final String name;
  final String defaultUser;
  final String defaultPass;
  final List<String> rtspPaths;
  final List<String> httpPaths; // paths that return 200/401 on real cameras
  final List<String> serverTokens; // HTTP Server header substrings

  const _BrandProfile({
    required this.name,
    required this.defaultUser,
    required this.defaultPass,
    required this.rtspPaths,
    required this.httpPaths,
    required this.serverTokens,
  });
}

const _brands = <String, _BrandProfile>{
  'Hikvision': _BrandProfile(
    name: 'Hikvision',
    defaultUser: 'admin',
    defaultPass: '12345',
    rtspPaths: ['/Streaming/Channels/101', '/h264/ch1/main/av_stream'],
    httpPaths: ['/ISAPI/System/deviceInfo', '/doc/page/login.asp'],
    serverTokens: ['hikvision', 'webs'],
  ),
  'Dahua': _BrandProfile(
    name: 'Dahua',
    defaultUser: 'admin',
    defaultPass: 'admin',
    rtspPaths: ['/cam/realmonitor?channel=1&subtype=0', '/h264Preview_01_main'],
    httpPaths: ['/cgi-bin/magicBox.cgi?action=getDeviceType', '/RPC2_Login'],
    serverTokens: ['dahua', 'dh-'],
  ),
  'Axis': _BrandProfile(
    name: 'Axis',
    defaultUser: 'root',
    defaultPass: 'pass',
    rtspPaths: ['/axis-media/media.amp', '/mpeg4/media.amp'],
    httpPaths: ['/axis-cgi/param.cgi', '/view/view.shtml'],
    serverTokens: ['axis', 'boa'],
  ),
  'Reolink': _BrandProfile(
    name: 'Reolink',
    defaultUser: 'admin',
    defaultPass: '',
    rtspPaths: ['/h264Preview_01_main', '/stream1'],
    httpPaths: ['/cgi-bin/api.cgi', '/'],
    serverTokens: ['reolink'],
  ),
  'Amcrest': _BrandProfile(
    name: 'Amcrest',
    defaultUser: 'admin',
    defaultPass: 'admin',
    rtspPaths: ['/cam/realmonitor?channel=1&subtype=0'],
    httpPaths: ['/cgi-bin/snapshot.cgi', '/'],
    serverTokens: ['amcrest'],
  ),
  'Foscam': _BrandProfile(
    name: 'Foscam',
    defaultUser: 'admin',
    defaultPass: '',
    rtspPaths: ['/videoMain', '/video.mp4'],
    httpPaths: ['/cgi-bin/CGIProxy.fcgi', '/'],
    serverTokens: ['foscam', 'ipc-webs'],
  ),
  'Uniview': _BrandProfile(
    name: 'Uniview',
    defaultUser: 'admin',
    defaultPass: '123456',
    rtspPaths: ['/unicast/c1/s0/live', '/media/video1'],
    httpPaths: ['/LAPI/V1.0/System/DeviceBasicInfo', '/'],
    serverTokens: ['uniview', 'nsc'],
  ),
  'Bosch': _BrandProfile(
    name: 'Bosch',
    defaultUser: 'service',
    defaultPass: '',
    rtspPaths: ['/rtsp_tunnel', '/video.mp4'],
    httpPaths: ['/rcp.xml', '/'],
    serverTokens: ['bosch', 'rtspchn'],
  ),
};

// OUI prefix → brand key
const _ouiBrands = <String, String>{
  'ACDCAA': 'Hikvision', 'D074DF': 'Hikvision', 'C01678': 'Hikvision',
  '8C968A': 'Hikvision', '8CF5A3': 'Hikvision', '4C11AE': 'Hikvision',
  'D46A35': 'Dahua',     '3C1B86': 'Dahua',     '705A9E': 'Dahua',
  'E0CC7A': 'Dahua',     '00083A': 'Dahua',
  '00E091': 'Axis',      '00408C': 'Axis',       'ACCC8E': 'Axis',
  'B4A2EB': 'Reolink',   '6C29B5': 'Reolink',
  'D80404': 'Hanwha',    '001C54': 'Hanwha',
  '00408F': 'Bosch',
  'D480BE': 'Foscam',    '00157D': 'Foscam',
};

// Ports that carry RTSP vs HTTP
const _rtspPorts = {554, 8554};
const _httpPorts = {80, 8080, 8000, 8888, 443};
// Proprietary DVR/NVR ports — strong indicator of camera device
const _proprietaryPorts = {37777, 34567};

// All ports to probe initially
const _allPorts = [554, 8554, 37777, 34567, 8080, 8000, 8888, 80, 443];

// ─── Camera info (fetched after verification) ─────────────────────────────
class CameraInfo {
  final String? manufacturer;
  final String? model;
  final String? firmware;
  final String? serial;
  final String? deviceType; // IPCamera, NVR, DVR…
  final String? hardwareVersion;
  final String? macFromDevice; // MAC reported by the device itself

  const CameraInfo({
    this.manufacturer,
    this.model,
    this.firmware,
    this.serial,
    this.deviceType,
    this.hardwareVersion,
    this.macFromDevice,
  });

  bool get hasAny =>
      manufacturer != null || model != null || firmware != null ||
      serial != null || deviceType != null;
}

class CameraDevice {
  final String ip;
  final String? mac;
  final String? brand;
  final List<int> openPorts;
  final bool verified;
  final CameraInfo? info;

  const CameraDevice({
    required this.ip,
    required this.openPorts,
    required this.verified,
    this.mac,
    this.brand,
    this.info,
  });

  String streamUrl() {
    // Prefer RTSP ports
    final rtsp = openPorts.where((p) => _rtspPorts.contains(p)).toList();
    if (rtsp.isNotEmpty) {
      final port = rtsp.first;
      final profile = brand != null ? _brands[brand] : null;
      final path = profile?.rtspPaths.first ?? '/stream1';
      final u = profile?.defaultUser ?? 'admin';
      final p = profile?.defaultPass ?? '';
      return 'rtsp://$u:$p@$ip:$port$path';
    }
    // HTTP ports → MJPEG/snapshot URL
    final http = openPorts.where((p) => _httpPorts.contains(p)).toList();
    if (http.isNotEmpty) {
      final port = http.first;
      final scheme = port == 443 ? 'https' : 'http';
      return '$scheme://$ip:$port/';
    }
    return 'rtsp://$ip:${openPorts.first}/';
  }

  String get defaultCredentials {
    final p = brand != null ? _brands[brand] : null;
    if (p == null) return 'admin / admin';
    final pass = p.defaultPass.isEmpty ? '(blank)' : p.defaultPass;
    return '${p.defaultUser} / $pass';
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final _subnetCtrl = TextEditingController();
  bool _scanning = false;
  int _progress = 0;
  int _total = 254;
  String _status = '';
  List<CameraDevice> _found = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subnet = context.read<DeviceManager>().subnet;
      if (subnet != null && _subnetCtrl.text.isEmpty) {
        _subnetCtrl.text = subnet;
      }
    });
  }

  @override
  void dispose() {
    _subnetCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final raw = _subnetCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter a subnet prefix (e.g. 192.168.1)');
      return;
    }
    final base = raw.replaceAll(RegExp(r'\.$'), '').replaceAll(RegExp(r'\.0$'), '');
    if (base.split('.').length != 3) {
      setState(() => _error = 'Use a /24 prefix like 192.168.1');
      return;
    }

    setState(() {
      _scanning = true;
      _progress = 0;
      _total = 254;
      _found = [];
      _error = null;
      _status = 'Scanning for open camera ports…';
    });

    // Phase 1: port probe in batches of 20
    const batchSize = 20;
    final candidates = <String, List<int>>{}; // ip → open ports

    for (var i = 1; i <= 254 && _scanning; i += batchSize) {
      final end = (i + batchSize - 1).clamp(1, 254);
      final ips = List.generate(end - i + 1, (j) => '$base.${i + j}');

      await Future.wait(ips.map((ip) async {
        final open = await _probePorts(ip);
        if (open.isNotEmpty) candidates[ip] = open;
      }));

      if (mounted) setState(() => _progress = end);
    }

    if (!_scanning) { if (mounted) setState(() => _scanning = false); return; }

    // Phase 2: verify candidates are actually cameras
    if (mounted) setState(() => _status = 'Verifying ${candidates.length} candidate(s)…');

    for (final entry in candidates.entries) {
      if (!_scanning) break;
      final ip = entry.key;
      final ports = entry.value;

      final mac = await _getMac(ip);
      String? brand = _guessBrandFromMac(mac);

      // Try to confirm it's a camera and identify brand
      final verified = await _verifyCamera(ip, ports);
      if (!verified.isCamera) continue; // skip non-cameras
      if (verified.brand != null) brand = verified.brand;

      final info = await _fetchCameraInfo(ip, ports, brand);

      final device = CameraDevice(
        ip: ip,
        openPorts: ports,
        verified: true,
        mac: mac,
        brand: brand ?? info?.manufacturer,
        info: info,
      );

      if (mounted) setState(() => _found = [..._found, device]);
    }

    if (mounted) setState(() { _scanning = false; _status = ''; });
  }

  void _stop() => setState(() { _scanning = false; _status = ''; });

  // ── Port probe ───────────────────────────────────────────────────────────

  Future<List<int>> _probePorts(String ip) async {
    final open = <int>[];
    await Future.wait(_allPorts.map((port) async {
      try {
        final sock = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 500));
        await sock.close();
        open.add(port);
      } catch (_) {}
    }));
    return open;
  }

  // ── Camera verification ──────────────────────────────────────────────────

  Future<_VerifyResult> _verifyCamera(String ip, List<int> ports) async {
    // Proprietary DVR/NVR ports are very strong indicators
    if (ports.any((p) => _proprietaryPorts.contains(p))) {
      return const _VerifyResult(isCamera: true);
    }

    // Check RTSP ports — send OPTIONS and look for RTSP/1.0 response
    for (final port in ports.where((p) => _rtspPorts.contains(p))) {
      final r = await _checkRtsp(ip, port);
      if (r.isCamera) return r;
    }

    // Check HTTP ports — inspect headers and known camera paths
    for (final port in ports.where((p) => _httpPorts.contains(p))) {
      final r = await _checkHttp(ip, port);
      if (r.isCamera) return r;
    }

    return const _VerifyResult(isCamera: false);
  }

  Future<_VerifyResult> _checkRtsp(String ip, int port) async {
    try {
      final sock = await Socket.connect(ip, port,
          timeout: const Duration(milliseconds: 800));
      sock.write('OPTIONS * RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: UnifyNetMonitor\r\n\r\n');
      await sock.flush();

      final completer = Completer<String>();
      final buf = StringBuffer();
      late StreamSubscription sub;
      sub = sock.listen(
        (data) {
          buf.write(String.fromCharCodes(data));
          if (!completer.isCompleted) completer.complete(buf.toString());
        },
        onDone: () { if (!completer.isCompleted) completer.complete(buf.toString()); },
        onError: (_) { if (!completer.isCompleted) completer.complete(''); },
      );

      final response = await completer.future.timeout(
          const Duration(milliseconds: 1000), onTimeout: () => buf.toString());
      await sub.cancel();
      await sock.close();

      if (response.startsWith('RTSP/1.0')) return const _VerifyResult(isCamera: true);
    } catch (_) {}
    return const _VerifyResult(isCamera: false);
  }

  Future<_VerifyResult> _checkHttp(String ip, int port) async {
    try {
      final scheme = port == 443 ? 'https' : 'http';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2)
        ..badCertificateCallback = (_, __, ___) => true;

      // 1. Check root path — Server header + first 2KB of body
      final req = await client.getUrl(Uri.parse('$scheme://$ip:$port/'));
      req.headers.set('User-Agent', 'UnifyNetMonitor/1.3.9');
      req.headers.set('Connection', 'close');
      final res = await req.close().timeout(const Duration(seconds: 3));
      final server = (res.headers.value('server') ?? '').toLowerCase();

      // Read up to 2KB of body to look for camera keywords
      final bodyBytes = <int>[];
      await for (final chunk in res) {
        bodyBytes.addAll(chunk);
        if (bodyBytes.length >= 2048) break;
      }
      final body = utf8.decode(bodyBytes, allowMalformed: true).toLowerCase();

      // Server header match — most reliable
      for (final entry in _brands.entries) {
        for (final token in entry.value.serverTokens) {
          if (server.contains(token)) {
            return _VerifyResult(isCamera: true, brand: entry.key);
          }
        }
      }

      // Body keyword match — camera login pages always contain these
      const cameraKeywords = [
        'hikvision', 'dahua', 'axis camera', 'reolink', 'foscam',
        'amcrest', 'ip camera', 'ipcam', 'nvr', 'dvr login',
        'webcam', 'onvif', 'rtsp://', 'channel=1',
      ];
      for (final kw in cameraKeywords) {
        if (body.contains(kw)) return const _VerifyResult(isCamera: true);
      }

      // 2. Try ONVIF with a real SOAP request — check body for SOAP/ONVIF response
      // Do NOT accept 401 alone — any server returns 401 on unknown paths
      try {
        const soap =
            '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">'
            '<s:Body><tds:GetDeviceInformation xmlns:tds="http://www.onvif.org/ver10/device/wsdl"/>'
            '</s:Body></s:Envelope>';
        final onvifReq = await client
            .postUrl(Uri.parse('$scheme://$ip:$port/onvif/device_service'))
            .timeout(const Duration(seconds: 2));
        onvifReq.headers.set('Content-Type', 'application/soap+xml');
        onvifReq.headers.set('Connection', 'close');
        onvifReq.write(soap);
        final onvifRes = await onvifReq.close().timeout(const Duration(seconds: 3));
        final onvifBody = await onvifRes
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 2));
        // Real ONVIF cameras return a SOAP envelope with onvif namespaces
        if ((onvifRes.statusCode == 200 || onvifRes.statusCode == 400) &&
            (onvifBody.contains('onvif') ||
             onvifBody.contains('Envelope') ||
             onvifBody.contains('tds:'))) {
          return const _VerifyResult(isCamera: true);
        }
      } catch (_) {}

      // 3. Hikvision ISAPI — only valid if body contains XML device info
      try {
        final hikReq = await client
            .getUrl(Uri.parse('$scheme://$ip:$port/ISAPI/System/deviceInfo'))
            .timeout(const Duration(seconds: 2));
        hikReq.headers.set('Connection', 'close');
        final hikRes = await hikReq.close().timeout(const Duration(seconds: 2));
        if (hikRes.statusCode == 200) {
          final hikBody = await hikRes
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 2));
          if (hikBody.contains('DeviceInfo') || hikBody.contains('deviceName')) {
            return const _VerifyResult(isCamera: true, brand: 'Hikvision');
          }
        } else {
          await hikRes.drain<void>();
        }
      } catch (_) {}

      // 4. Dahua magic box — returns plaintext like "DeviceType=IPC"
      try {
        final dhReq = await client
            .getUrl(Uri.parse(
                '$scheme://$ip:$port/cgi-bin/magicBox.cgi?action=getDeviceType'))
            .timeout(const Duration(seconds: 2));
        dhReq.headers.set('Connection', 'close');
        final dhRes = await dhReq.close().timeout(const Duration(seconds: 2));
        if (dhRes.statusCode == 200) {
          final dhBody = await dhRes
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 2));
          if (dhBody.contains('DeviceType') || dhBody.contains('IPC') ||
              dhBody.contains('NVR') || dhBody.contains('DVR')) {
            return const _VerifyResult(isCamera: true, brand: 'Dahua');
          }
        } else {
          await dhRes.drain<void>();
        }
      } catch (_) {}

      client.close();
    } catch (_) {}
    return const _VerifyResult(isCamera: false);
  }

  // ── Fetch device info ────────────────────────────────────────────────────

  Future<CameraInfo?> _fetchCameraInfo(
      String ip, List<int> ports, String? brand) async {
    final httpPort = ports.firstWhere(
        (p) => _httpPorts.contains(p), orElse: () => 0);
    final scheme = httpPort == 443 ? 'https' : 'http';

    // Try ONVIF GetDeviceInformation first (works on most brands)
    if (httpPort != 0) {
      final onvif = await _fetchOnvif(ip, httpPort, scheme);
      if (onvif != null) return onvif;
    }

    // Try brand-specific endpoints
    if (httpPort != 0) {
      final b = brand ?? '';
      if (b == 'Hikvision' || b.isEmpty) {
        final hik = await _fetchHikvision(ip, httpPort, scheme);
        if (hik != null) return hik;
      }
      if (b == 'Dahua' || b.isEmpty) {
        final dah = await _fetchDahua(ip, httpPort, scheme);
        if (dah != null) return dah;
      }
    }
    return null;
  }

  Future<CameraInfo?> _fetchOnvif(String ip, int port, String scheme) async {
    try {
      const soap =
          '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">'
          '<s:Body><tds:GetDeviceInformation xmlns:tds="http://www.onvif.org/ver10/device/wsdl"/>'
          '</s:Body></s:Envelope>';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => true;
      final req = await client
          .postUrl(Uri.parse('$scheme://$ip:$port/onvif/device_service'))
          .timeout(const Duration(seconds: 3));
      req.headers.set('Content-Type', 'application/soap+xml');
      req.headers.set('Connection', 'close');
      req.write(soap);
      final res = await req.close().timeout(const Duration(seconds: 4));
      final body = await res.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 3));
      client.close();

      if (!body.contains('Envelope')) return null;

      String? _tag(String tag) {
        final m = RegExp('<[^:>]*:?$tag[^>]*>([^<]+)<', caseSensitive: false)
            .firstMatch(body);
        return m?.group(1)?.trim();
      }

      final mfr  = _tag('Manufacturer');
      final model = _tag('Model');
      final fw   = _tag('FirmwareVersion');
      final sn   = _tag('SerialNumber');
      final hw   = _tag('HardwareId');
      if (mfr == null && model == null) return null;
      return CameraInfo(
          manufacturer: mfr, model: model, firmware: fw,
          serial: sn, hardwareVersion: hw);
    } catch (_) { return null; }
  }

  Future<CameraInfo?> _fetchHikvision(String ip, int port, String scheme) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => true;
      final req = await client
          .getUrl(Uri.parse('$scheme://$ip:$port/ISAPI/System/deviceInfo'))
          .timeout(const Duration(seconds: 3));
      req.headers.set('Connection', 'close');
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) { await res.drain<void>(); client.close(); return null; }
      final body = await res.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 3));
      client.close();

      String? _tag(String tag) {
        final m = RegExp('<$tag>([^<]+)</$tag>', caseSensitive: false)
            .firstMatch(body);
        return m?.group(1)?.trim();
      }

      return CameraInfo(
        manufacturer: 'Hikvision',
        model: _tag('model'),
        firmware: _tag('firmwareVersion'),
        serial: _tag('serialNumber'),
        deviceType: _tag('deviceType'),
        hardwareVersion: _tag('hardwareVersion'),
        macFromDevice: _tag('macAddress'),
      );
    } catch (_) { return null; }
  }

  Future<CameraInfo?> _fetchDahua(String ip, int port, String scheme) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => true;

      Future<String> _cgi(String action) async {
        final req = await client.getUrl(Uri.parse(
            '$scheme://$ip:$port/cgi-bin/magicBox.cgi?action=$action'));
        req.headers.set('Connection', 'close');
        final res = await req.close().timeout(const Duration(seconds: 3));
        if (res.statusCode != 200) { await res.drain<void>(); return ''; }
        return res.transform(utf8.decoder).join()
            .timeout(const Duration(seconds: 2));
      }

      final typeBody = await _cgi('getDeviceType');
      if (!typeBody.contains('DeviceType')) { client.close(); return null; }

      final fwBody  = await _cgi('getSoftwareVersion');
      final hwBody  = await _cgi('getHardwareVersion');
      final snBody  = await _cgi('getSerialNo');
      client.close();

      String? _val(String body) {
        final m = RegExp(r'=(.+)').firstMatch(body.trim());
        return m?.group(1)?.trim();
      }

      return CameraInfo(
        manufacturer: 'Dahua',
        deviceType: _val(typeBody),
        firmware: _val(fwBody),
        hardwareVersion: _val(hwBody),
        serial: _val(snBody),
      );
    } catch (_) { return null; }
  }

  // ── MAC & brand ──────────────────────────────────────────────────────────

  Future<String?> _getMac(String ip) async {
    try {
      await Process.run('ping', ['-n', '1', '-w', '200', ip]);
      final res = await Process.run('arp', ['-a', ip],
          stdoutEncoding: const SystemEncoding());
      for (final line in res.stdout.toString().split('\n')) {
        if (line.contains(ip)) {
          final m = RegExp(r'([0-9a-f]{2}[:\-]){5}[0-9a-f]{2}',
              caseSensitive: false).firstMatch(line);
          if (m != null) return m.group(0);
        }
      }
    } catch (_) {}
    return null;
  }

  String? _guessBrandFromMac(String? mac) {
    if (mac == null) return null;
    final oui = mac.replaceAll(RegExp(r'[:\-]'), '').toUpperCase();
    if (oui.length >= 6) return _ouiBrands[oui.substring(0, 6)];
    return null;
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Header(
        subnetCtrl: _subnetCtrl,
        scanning: _scanning,
        progress: _progress,
        total: _total,
        found: _found.length,
        status: _status,
        onScan: _scan,
        onStop: _stop,
        error: _error,
      ),
      Expanded(
        child: _found.isEmpty
            ? _EmptyState(scanning: _scanning, progress: _progress, total: _total, status: _status)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _found.length,
                itemBuilder: (ctx, i) => _CameraCard(camera: _found[i]),
              ),
      ),
    ]);
  }
}

// ─── Verify result ────────────────────────────────────────────────────────

class _VerifyResult {
  final bool isCamera;
  final String? brand;
  const _VerifyResult({required this.isCamera, this.brand});
}

// ─── Header ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.subnetCtrl,
    required this.scanning,
    required this.progress,
    required this.total,
    required this.found,
    required this.status,
    required this.onScan,
    required this.onStop,
    required this.error,
  });

  final TextEditingController subnetCtrl;
  final bool scanning;
  final int progress, total, found;
  final String status;
  final VoidCallback onScan, onStop;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E2D45))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.videocam, color: Color(0xFF00D4FF), size: 20),
          const SizedBox(width: 8),
          const Text('Camera Scanner',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Text('— verified cameras only',
              style: TextStyle(color: Color(0xFF4A6480), fontSize: 12)),
          const Spacer(),
          if (found > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.3)),
              ),
              child: Text('$found found',
                  style: const TextStyle(
                      color: Color(0xFF00D4FF), fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: subnetCtrl,
              enabled: !scanning,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '192.168.1',
                hintStyle: const TextStyle(color: Color(0xFF4A6480)),
                labelText: 'Subnet prefix (/24)',
                labelStyle:
                    const TextStyle(color: Color(0xFF7A96B8), fontSize: 12),
                prefixIcon: const Icon(Icons.lan_outlined,
                    color: Color(0xFF4A6480), size: 17),
                filled: true,
                fillColor: const Color(0xFF111927),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E2D45))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E2D45))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF00D4FF))),
                errorText: error,
                errorStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 40,
            child: scanning
                ? OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop, size: 15),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFFF87171))),
                  )
                : ElevatedButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.search, size: 15),
                    label: const Text('Scan'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18)),
                  ),
          ),
        ]),
        if (scanning) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? progress / total : null,
                  backgroundColor: const Color(0xFF1E2D45),
                  color: const Color(0xFF00D4FF),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$progress / $total',
                style: const TextStyle(color: Color(0xFF7A96B8), fontSize: 11)),
          ]),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(status,
                style: const TextStyle(color: Color(0xFF4A6480), fontSize: 11)),
          ],
        ],
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.scanning,
    required this.progress,
    required this.total,
    required this.status,
  });
  final bool scanning;
  final int progress, total;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          scanning ? Icons.radar : Icons.videocam_off_outlined,
          size: 56,
          color: const Color(0xFF1E2D45),
        ),
        const SizedBox(height: 14),
        Text(
          scanning
              ? (status.isNotEmpty ? status : 'Scanning for IP cameras…')
              : 'Enter a subnet prefix and press Scan',
          style: const TextStyle(color: Color(0xFF4A6480), fontSize: 14),
        ),
        if (scanning && status.isEmpty) ...[
          const SizedBox(height: 6),
          Text('$progress of $total hosts checked',
              style: const TextStyle(color: Color(0xFF2A3F5F), fontSize: 12)),
        ],
        if (!scanning) ...[
          const SizedBox(height: 8),
          const Text(
            'Only confirmed IP cameras are shown.\nPCs and routers with open ports are filtered out.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF2A3F5F), fontSize: 12),
          ),
        ],
      ]),
    );
  }
}

// ─── Camera card ──────────────────────────────────────────────────────────

class _CameraCard extends StatefulWidget {
  const _CameraCard({required this.camera});
  final CameraDevice camera;

  @override
  State<_CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<_CameraCard> {
  bool _showCreds = false;

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final url = cam.streamUrl();
    final profile = cam.brand != null ? _brands[cam.brand] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111927),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2D45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Title row ──
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.videocam, color: Color(0xFF00D4FF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cam.brand ?? 'IP Camera',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Row(children: [
                  Text(cam.ip,
                      style: const TextStyle(color: Color(0xFF7A96B8),
                          fontSize: 12, fontFamily: 'monospace')),
                ]),
              ]),
            ),
            if (cam.mac != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D45),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(cam.mac!,
                    style: const TextStyle(color: Color(0xFF4A6480),
                        fontSize: 10, fontFamily: 'monospace')),
              ),
          ]),

          // ── Specs panel ──
          if (cam.info != null && cam.info!.hasAny) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1321),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2D45)),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 6,
                children: [
                  if (cam.info!.manufacturer != null)
                    _specRow('Manufacturer', cam.info!.manufacturer!),
                  if (cam.info!.model != null)
                    _specRow('Model', cam.info!.model!),
                  if (cam.info!.deviceType != null)
                    _specRow('Type', cam.info!.deviceType!),
                  if (cam.info!.firmware != null)
                    _specRow('Firmware', cam.info!.firmware!),
                  if (cam.info!.hardwareVersion != null)
                    _specRow('Hardware', cam.info!.hardwareVersion!),
                  if (cam.info!.serial != null)
                    _specRow('Serial', cam.info!.serial!),
                  if (cam.info!.macFromDevice != null)
                    _specRow('MAC', cam.info!.macFromDevice!),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Open ports ──
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final port in cam.openPorts)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DD68C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: const Color(0xFF3DD68C).withValues(alpha: 0.3)),
                ),
                child: Text(_portLabel(port),
                    style: const TextStyle(color: Color(0xFF3DD68C),
                        fontSize: 11, fontFamily: 'monospace')),
              ),
          ]),

          const SizedBox(height: 12),

          // ── Stream URL ──
          _UrlRow(
            label: _rtspPorts.contains(cam.openPorts.firstWhere(
                    (p) => _rtspPorts.contains(p),
                    orElse: () => 0))
                ? 'RTSP'
                : 'HTTP',
            url: url,
          ),

          // ── Additional RTSP paths for known brands ──
          if (profile != null && profile.rtspPaths.length > 1) ...[
            const SizedBox(height: 6),
            for (final path in profile.rtspPaths.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _UrlRow(label: 'alt', url: _buildRtsp(cam, path, profile)),
              ),
          ],

          const SizedBox(height: 10),

          // ── Default credentials toggle ──
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _showCreds = !_showCreds),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1321),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E2D45)),
              ),
              child: Row(children: [
                const Icon(Icons.key, color: Color(0xFF4A6480), size: 13),
                const SizedBox(width: 6),
                const Text('Default credentials',
                    style: TextStyle(color: Color(0xFF7A96B8), fontSize: 12)),
                const Spacer(),
                Icon(_showCreds ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF4A6480), size: 16),
              ]),
            ),
          ),

          if (_showCreds) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1321),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _credRow('Username', profile?.defaultUser ?? 'admin'),
                const SizedBox(height: 4),
                _credRow('Password',
                    profile?.defaultPass.isEmpty ?? true
                        ? '(blank)'
                        : profile!.defaultPass),
                if (profile != null && profile.httpPaths.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Web interface paths:',
                      style: TextStyle(color: Color(0xFF4A6480), fontSize: 11)),
                  const SizedBox(height: 4),
                  for (final path in profile.httpPaths)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('http://${cam.ip}$path',
                          style: const TextStyle(
                              color: Color(0xFF7A96B8), fontSize: 11,
                              fontFamily: 'monospace')),
                    ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _specRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: const TextStyle(color: Color(0xFF4A6480),
              fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.08)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 12,
              fontFamily: 'monospace')),
    ],
  );

  Widget _credRow(String label, String value) => Row(children: [
    SizedBox(
      width: 72,
      child: Text(label,
          style: const TextStyle(color: Color(0xFF4A6480), fontSize: 12)),
    ),
    Text(value,
        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12,
            fontFamily: 'monospace', fontWeight: FontWeight.w600)),
  ]);

  String _buildRtsp(CameraDevice cam, String path, _BrandProfile p) {
    final port = cam.openPorts.firstWhere(
        (pt) => _rtspPorts.contains(pt), orElse: () => 554);
    return 'rtsp://${p.defaultUser}:${p.defaultPass}@${cam.ip}:$port$path';
  }
}

String _portLabel(int port) {
  switch (port) {
    case 554:   return '554/RTSP';
    case 8554:  return '8554/RTSP';
    case 80:    return '80/HTTP';
    case 443:   return '443/HTTPS';
    case 8080:  return '8080/HTTP';
    case 8000:  return '8000/HTTP';
    case 37777: return '37777/Dahua';
    case 34567: return '34567/DVR';
    default:    return '$port';
  }
}

// ─── URL row widget ───────────────────────────────────────────────────────

class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1321),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E2D45)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2D45),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: const TextStyle(color: Color(0xFF4A6480),
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(url,
              style: const TextStyle(color: Color(0xFF7A96B8),
                  fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF111927),
            ));
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy, color: Color(0xFF4A6480), size: 13),
          ),
        ),
      ]),
    );
  }
}
