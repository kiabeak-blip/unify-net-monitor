import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Utilities'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'WiFi QR'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scanner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WifiQrTab(),
          _ScannerTab(),
        ],
      ),
    );
  }
}

// ── WiFi QR Generator ─────────────────────────────────────────────────────────

class _WifiQrTab extends StatefulWidget {
  const _WifiQrTab();

  @override
  State<_WifiQrTab> createState() => _WifiQrTabState();
}

class _WifiQrTabState extends State<_WifiQrTab> {
  final _ssidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _security = 'WPA';
  bool _hidden = false;
  bool _showPassword = false;
  bool _loadingCurrent = false;

  String get _qrData {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) return '';
    final s = _security == 'None' ? 'nopass' : _security;
    final p = _passwordCtrl.text;
    final h = _hidden ? 'true' : 'false';
    return 'WIFI:T:$s;S:${_escapeWifi(ssid)};P:${_escapeWifi(p)};H:$h;;';
  }

  String _escapeWifi(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll(';', '\\;')
          .replaceAll(',', '\\,').replaceAll('"', '\\"');

  Future<void> _loadCurrentWifi() async {
    setState(() => _loadingCurrent = true);
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      if (ssid != null && ssid.isNotEmpty && mounted) {
        setState(() {
          _ssidCtrl.text = ssid.replaceAll('"', '');
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCurrent = false);
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qrData;
    final hasQr = qr.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // QR display
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasQr
                ? Container(
                    key: ValueKey(qr),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: qr,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  )
                : Container(
                    width: 232,
                    height: 232,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_password,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text('Enter SSID to generate',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
          ),
        ),

        if (hasQr)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR data copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy QR data'),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // SSID field
        _Label('Network Name (SSID)'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ssidCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('MyNetwork'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Load current WiFi',
              onPressed: _loadingCurrent ? null : _loadCurrentWifi,
              icon: _loadingCurrent
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_outlined,
                      color: Color(0xFF00D4FF)),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Security type
        _Label('Security'),
        const SizedBox(height: 6),
        Row(
          children: ['WPA', 'WEP', 'None'].map((type) {
            final selected = _security == type;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _security = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00D4FF).withOpacity(0.15)
                          : const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00D4FF)
                            : Colors.white.withOpacity(0.1),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF00D4FF)
                              : Colors.white54,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Password field
        if (_security != 'None') ...[
          _Label('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            onChanged: (_) => setState(() {}),
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: _inputDecoration('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 18),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Hidden toggle
        Row(
          children: [
            const Text('Hidden Network',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            Switch(
              value: _hidden,
              onChanged: (v) => setState(() => _hidden = v),
              activeColor: const Color(0xFF00D4FF),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A2235),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF00D4FF), width: 1.5)),
      );
}

// ── QR Scanner ────────────────────────────────────────────────────────────────

class _ScannerTab extends StatefulWidget {
  const _ScannerTab();

  @override
  State<_ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<_ScannerTab> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanning = false;
  String? _lastResult;
  bool _flashOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value == null || value == _lastResult) return;
    setState(() {
      _lastResult = value;
      _scanning = false;
    });
    _ctrl.stop();
  }

  void _startScan() {
    setState(() { _lastResult = null; _scanning = true; });
    _ctrl.start();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const Center(
        child: Text('QR scanning requires a mobile device with a camera.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54)),
      );
    }

    if (_scanning) {
      return Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          // Overlay frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00D4FF), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Controls
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () async {
                    await _ctrl.toggleTorch();
                    setState(() => _flashOn = !_flashOn);
                  },
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: _flashOn ? const Color(0xFFFFAA00) : Colors.white54,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4466),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () { _ctrl.stop(); setState(() => _scanning = false); },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: const Icon(Icons.qr_code_scanner, color: Color(0xFF00D4FF), size: 40),
          ),
          const SizedBox(height: 20),
          const Text('QR Scanner',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Scan any QR code with your camera',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Start Scanning', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _startScan,
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAST RESULT',
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SelectableText(_lastResult!,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _lastResult!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy'),
                      ),
                      TextButton.icon(
                        onPressed: _startScan,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Label widget ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600));
  }
}
