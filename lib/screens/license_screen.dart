// lib/screens/license_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/license_service.dart';

// ── Owner contact emails ──────────────────────────────────────────────────
const _ownerEmailPrimary   = 'ajiba85@yahoo.com';
const _ownerEmailSecondary = 'license@unify-technology.com';
const _ownerEmail = '$_ownerEmailPrimary, $_ownerEmailSecondary';
const _ownerName  = 'Unify Technologies';

// ── License Gate — wraps the whole app ────────────────────────────────────

class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  LicenseInfo? _info;
  bool _loading = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final info = await LicenseService.check();
    if (mounted) setState(() { _info = info; _loading = false; _bannerDismissed = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    if (_info!.canUse) {
      return Stack(children: [
        widget.child,
        if (_info!.status == LicenseStatus.trial && !_bannerDismissed)
          _TrialPopup(
            daysLeft: _info!.trialDaysLeft,
            onActivate: () => _showActivation(context),
            onRequest: () => _showRequest(context),
            onDismiss: () => setState(() => _bannerDismissed = true),
          ),
      ]);
    }
    return _ExpiredScreen(onActivated: _check);
  }

  void _showActivation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ActivationDialog(onActivated: () {
        Navigator.pop(context);
        _check();
      }),
    );
  }

  void _showRequest(BuildContext context) {
    showDialog(context: context,
        builder: (_) => const _RequestDialog());
  }
}

// ── Splash ────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0E1A),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/app_icon.png', width: 96, height: 96,
          errorBuilder: (_, __, ___) => const Icon(Icons.monitor_heart,
              color: Color(0xFF00D4FF), size: 64)),
      const SizedBox(height: 24),
      const Text('Unify Net Monitor',
          style: TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      const Text('by $_ownerName',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 32),
      const SizedBox(width: 200,
          child: LinearProgressIndicator(
              backgroundColor: Color(0xFF1E2D45),
              color: Color(0xFF00D4FF), minHeight: 2)),
    ])),
  );
}

// ── Trial banner ──────────────────────────────────────────────────────────

class _TrialPopup extends StatelessWidget {
  const _TrialPopup({
    required this.daysLeft,
    required this.onActivate,
    required this.onRequest,
    required this.onDismiss,
  });
  final int daysLeft;
  final VoidCallback onActivate, onRequest, onDismiss;

  Color get _color => daysLeft > 14
      ? const Color(0xFF00D4FF)
      : daysLeft > 7
          ? const Color(0xFFFFAA00)
          : const Color(0xFFFF4466);

  @override
  Widget build(BuildContext context) => Positioned(
    top: 16, right: 16,
    child: Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.timer_outlined, color: _color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  daysLeft == 1 ? 'Trial expires tomorrow!'
                      : '$daysLeft days remaining in trial',
                  style: TextStyle(color: _color, fontSize: 13,
                      fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Activate a license key to unlock the full version.',
              style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _color,
                    side: BorderSide(color: _color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Request License'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onActivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Enter Key'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ── Expired screen ────────────────────────────────────────────────────────

class _ExpiredScreen extends StatelessWidget {
  const _ExpiredScreen({required this.onActivated});
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0E1A),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/app_icon.png', width: 80, height: 80,
                errorBuilder: (_, __, ___) => const Icon(Icons.monitor_heart,
                    color: Color(0xFF00D4FF), size: 64)),
            const SizedBox(height: 20),
            const Text('Unify Net Monitor',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF4466).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFF4466).withOpacity(0.4))),
              child: const Text('60-DAY TRIAL EXPIRED',
                  style: TextStyle(color: Color(0xFFFF4466), fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 28),
            const Text(
              'Your free trial has ended.\nRequest a license key from the owner\nto continue using Unify Net Monitor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 28),

            // Request via email — primary action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const _RequestDialog()),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Request License via Email',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),

            // Already have a key
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _ActivationDialog(onActivated: onActivated),
                ),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.vpn_key_outlined, size: 16),
                label: const Text('I already have a license key',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),
            Text(_ownerEmailPrimary,
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
            Text(_ownerEmailSecondary,
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
        ),
      ),
    ),
  );
}

// ── Request License dialog ─────────────────────────────────────────────────

class _RequestDialog extends StatefulWidget {
  const _RequestDialog();

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  // Machine info (auto-filled)
  String _computerName = '';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadMachineInfo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMachineInfo() async {
    try {
      _computerName = Platform.localHostname;
      _username = Platform.environment['USERNAME'] ??
          Platform.environment['USER'] ?? '';
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _sendRequest() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) return;

    setState(() => _sending = true);

    final subject = Uri.encodeComponent(
        'License Request — Unify Net Monitor');

    final body = Uri.encodeComponent(
        'Hello $_ownerName,\n\n'
        'I would like to request a license key for Unify Net Monitor.\n\n'
        '--- User Details ---\n'
        'Name:          $name\n'
        'Email:         $email\n'
        'Computer:      $_computerName\n'
        'Windows User:  $_username\n'
        '${_messageCtrl.text.trim().isNotEmpty ? "\nMessage:\n${_messageCtrl.text.trim()}\n" : ""}'
        '\nThank you.');

    final mailto = 'mailto:$_ownerEmailPrimary?cc=${Uri.encodeComponent(_ownerEmailSecondary)}&subject=$subject&body=$body';

    try {
      // Open default mail client
      await Process.start('cmd', ['/c', 'start', '', mailto],
          mode: ProcessStartMode.detached);
      setState(() { _sending = false; _sent = true; });
    } catch (e) {
      // Fallback: copy email address
      await Clipboard.setData(const ClipboardData(text: _ownerEmail));
      setState(() { _sending = false; _sent = true; });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF111827),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: SizedBox(
        width: 440,
        child: _sent ? _buildSentView() : _buildFormView(),
      ),
    ),
  );

  Widget _buildSentView() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF00FF88).withOpacity(0.3))),
        child: const Icon(Icons.mark_email_read_outlined,
            color: Color(0xFF00FF88), size: 32),
      ),
      const SizedBox(height: 16),
      const Text('Email Opened!',
          style: TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text(
        'Your default email app should be open\nwith the request pre-filled.\n\nSend the email and wait for your\nlicense key reply.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 8),
      Text(_ownerEmailPrimary,
          style: const TextStyle(color: Color(0xFF00D4FF),
              fontSize: 12, fontFamily: 'monospace')),
      const SizedBox(height: 2),
      Text(_ownerEmailSecondary,
          style: const TextStyle(color: Color(0xFF00D4FF),
              fontSize: 12, fontFamily: 'monospace')),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Close'),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => _ActivationDialog(onActivated: () {
                Navigator.pop(context);
              }),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.vpn_key_outlined, size: 14),
          label: const Text('Enter Key',
              style: TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    ],
  );

  Widget _buildFormView() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3))),
          child: const Icon(Icons.email_outlined,
              color: Color(0xFF00D4FF), size: 20)),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Request a License Key',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text('We\'ll send a key to your email',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
      const SizedBox(height: 20),

      // Auto-filled machine info chip
      if (_computerName.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2D45))),
          child: Row(children: [
            const Icon(Icons.computer, color: Colors.white24, size: 14),
            const SizedBox(width: 8),
            Text('$_computerName  •  $_username',
                style: const TextStyle(color: Colors.white38,
                    fontSize: 11, fontFamily: 'monospace')),
            const Spacer(),
            const Text('auto-detected',
                style: TextStyle(color: Colors.white24, fontSize: 9)),
          ]),
        ),

      _Field('Your Name', _nameCtrl, Icons.person_outline, 'John Smith'),
      const SizedBox(height: 10),
      _Field('Your Email', _emailCtrl, Icons.alternate_email,
          'john@example.com', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 10),
      _Field('Message (optional)', _messageCtrl, Icons.notes_outlined,
          'e.g. requesting for 1 year extension…', maxLines: 3),
      const SizedBox(height: 20),

      // Send to info
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFF00D4FF).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF00D4FF).withOpacity(0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Request will be sent to:',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.send, color: Color(0xFF00D4FF), size: 12),
            const SizedBox(width: 6),
            Text(_ownerEmailPrimary, style: const TextStyle(
                color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.send, color: Color(0xFF00D4FF), size: 12),
            const SizedBox(width: 6),
            Text(_ownerEmailSecondary, style: const TextStyle(
                color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace')),
          ]),
        ]),
      ),
      const SizedBox(height: 20),

      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Cancel'),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: (_sending ||
              _nameCtrl.text.trim().isEmpty ||
              _emailCtrl.text.trim().isEmpty)
              ? null : _sendRequest,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          icon: _sending
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Color(0xFF0A0E1A)))
              : const Icon(Icons.send, size: 15),
          label: Text(_sending ? 'Opening…' : 'Send Request',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    ],
  );
}

// ── Activation dialog ─────────────────────────────────────────────────────

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog({required this.onActivated});
  final VoidCallback onActivated;

  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _activate() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });

    final result = await LicenseService.activate(key);
    if (!mounted) return;

    if (result.ok) {
      setState(() { _success = result.message; _loading = false; });
      await Future.delayed(const Duration(seconds: 1));
      widget.onActivated();
    } else {
      setState(() { _error = result.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF111827),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.3))),
              child: const Icon(Icons.vpn_key_outlined,
                  color: Color(0xFF00D4FF), size: 20)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enter License Key',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text('Paste the key you received via email',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 24),

          const Text('License Key',
              style: TextStyle(color: Colors.white54, fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white,
                fontFamily: 'monospace', fontSize: 14, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'UNM-XXXXXXXX-XXXXXX',
              hintStyle: const TextStyle(color: Colors.white24,
                  fontFamily: 'monospace', letterSpacing: 1),
              filled: true, fillColor: const Color(0xFF0A0E1A),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF00D4FF), width: 1.5)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste,
                    color: Colors.white38, size: 18),
                tooltip: 'Paste',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _ctrl.text = data!.text!.trim().toUpperCase();
                  }
                },
              ),
            ),
            onSubmitted: (_) => _activate(),
            inputFormatters: [
              TextInputFormatter.withFunction((old, next) =>
                  next.copyWith(text: next.text.toUpperCase())),
            ],
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF4466).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF4466).withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF4466), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFFF4466), fontSize: 12))),
              ]),
            )
          else if (_success != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF00FF88), size: 14),
                const SizedBox(width: 8),
                Text(_success!,
                    style: const TextStyle(
                        color: Color(0xFF00FF88), fontSize: 12)),
              ]),
            ),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white38,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _loading ? null : _activate,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: const Color(0xFF0A0E1A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Color(0xFF0A0E1A)))
                  : const Text('Activate',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    ),
  );
}

// ── Field helper ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field(this.label, this.ctrl, this.icon, this.hint,
      {this.keyboardType, this.maxLines = 1});
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white,
            fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          prefixIcon: maxLines == 1
              ? Icon(icon, color: Colors.white38, size: 16) : null,
          filled: true, fillColor: const Color(0xFF0A0E1A), isDense: true,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: maxLines > 1 ? 12 : 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF00D4FF), width: 1.5)),
        ),
      ),
    ],
  );
}

// ── Key Generator (owner-only, NOT included in user build) ────────────────
// Keep this class here so the owner's build can still use it via a separate
// build flag — but it's not reachable from the user-facing navigation.

class KeyGeneratorScreen extends StatefulWidget {
  const KeyGeneratorScreen({super.key});

  @override
  State<KeyGeneratorScreen> createState() => _KeyGeneratorScreenState();
}

class _KeyGeneratorScreenState extends State<KeyGeneratorScreen> {
  int _days = 365;
  bool _forever = false;
  String _generatedKey = '';

  void _generate() {
    final expiry = _forever ? null : DateTime.now().add(Duration(days: _days));
    setState(() => _generatedKey = LicenseService.generateKey(expiry: expiry));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('License Key Generator'),
        backgroundColor: const Color(0xFF0A0E1A)),
    backgroundColor: const Color(0xFF0A0E1A),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF4466).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF4466).withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.lock, color: Color(0xFFFF4466), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('OWNER TOOL — Keep this private.',
                    style: TextStyle(color: Color(0xFFFF4466), fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lifetime license',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              value: _forever,
              activeColor: const Color(0xFF00D4FF),
              onChanged: (v) => setState(() => _forever = v),
            ),
            if (!_forever) ...[
              Text('Duration: $_days days',
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              Slider(
                value: _days.toDouble(), min: 30, max: 1825, divisions: 36,
                activeColor: const Color(0xFF00D4FF),
                inactiveColor: const Color(0xFF1E2D45),
                onChanged: (v) => setState(() => _days = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generate,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.generating_tokens, size: 16),
                label: const Text('Generate Key',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            if (_generatedKey.isNotEmpty) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _generatedKey));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied'),
                      behavior: SnackBarBehavior.floating));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.3))),
                  child: Row(children: [
                    Expanded(child: Text(_generatedKey,
                        style: const TextStyle(color: Color(0xFF00FF88),
                            fontSize: 15, fontFamily: 'monospace',
                            fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                    const Icon(Icons.copy, color: Colors.white38, size: 16),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
}
