// lib/screens/vnc_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Common VNC viewer paths on Windows
const _vncPaths = [
  r'C:\Program Files\TightVNC\tvnviewer.exe',
  r'C:\Program Files (x86)\TightVNC\tvnviewer.exe',
  r'C:\Program Files\RealVNC\VNC Viewer\vncviewer.exe',
  r'C:\Program Files (x86)\RealVNC\VNC Viewer\vncviewer.exe',
  r'C:\Program Files\UltraVNC\vncviewer.exe',
  r'C:\Program Files (x86)\UltraVNC\vncviewer.exe',
  r'C:\Program Files\RealVNC\VNC4\vncviewer.exe',
];

class VncScreen extends StatefulWidget {
  final String? initialHost;
  const VncScreen({super.key, this.initialHost});

  @override
  State<VncScreen> createState() => _VncScreenState();
}

class _VncScreenState extends State<VncScreen> {
  List<_VncProfile> _profiles = [];
  bool _launching = false;
  String? _detectedViewer;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _detectViewer();
    if (widget.initialHost != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showDialog(initialHost: widget.initialHost));
    }
  }

  Future<void> _detectViewer() async {
    for (final path in _vncPaths) {
      if (File(path).existsSync()) {
        setState(() => _detectedViewer = path);
        return;
      }
    }
    // Try PATH
    try {
      final r = await Process.run('vncviewer', ['--help'],
          stdoutEncoding: const SystemEncoding());
      if (r.exitCode == 0 || r.exitCode == 1) {
        setState(() => _detectedViewer = 'vncviewer');
      }
    } catch (_) {}
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vnc_profiles');
    if (raw != null) {
      setState(() => _profiles =
          (jsonDecode(raw) as List).map((e) => _VncProfile.fromJson(e)).toList());
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'vnc_profiles', jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

  Future<void> _launch(_VncProfile p) async {
    if (_detectedViewer == null) {
      _showNoViewerDialog();
      return;
    }
    setState(() => _launching = true);
    try {
      final host = '${p.host}:${p.port}';
      await Process.start(_detectedViewer!, [host],
          mode: ProcessStartMode.detached);
      if (!mounted) return;
      setState(() {
        final idx = _profiles.indexWhere((x) => x.id == p.id);
        if (idx >= 0) _profiles[idx] = p.copyWith(lastUsed: DateTime.now());
      });
      await _saveProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Launching VNC to ${p.host}…'),
          backgroundColor: const Color(0xFF1A2235),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFFF4466),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _showNoViewerDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAA00)),
          SizedBox(width: 10),
          Text('VNC Viewer Not Found'),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No VNC viewer was detected. Install one of:',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 12),
            _InstallChip('TightVNC', 'winget install GlavSoft.TightVNC'),
            SizedBox(height: 6),
            _InstallChip('RealVNC Viewer', 'winget install RealVNC.VNCViewer'),
            SizedBox(height: 6),
            _InstallChip('UltraVNC', 'winget install uvncbvba.UltraVnc'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showDialog({String? initialHost, _VncProfile? edit}) {
    final hostCtrl = TextEditingController(text: edit?.host ?? initialHost ?? '');
    final portCtrl = TextEditingController(text: '${edit?.port ?? 5900}');
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Row(children: [
          const Icon(Icons.monitor, color: Color(0xFF00FF88), size: 20),
          const SizedBox(width: 10),
          Text(edit != null ? 'Edit VNC Connection' : 'New VNC Connection'),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(label: 'Name (optional)', ctrl: nameCtrl,
                  icon: Icons.label_outline, hint: 'My Desktop'),
              const SizedBox(height: 10),
              _DialogField(label: 'Host / IP', ctrl: hostCtrl,
                  icon: Icons.computer, hint: '192.168.1.100'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _DialogField(label: 'Port', ctrl: portCtrl,
                    icon: Icons.settings_ethernet, hint: '5900',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _DialogField(label: 'Password', ctrl: passCtrl,
                    icon: Icons.lock_outline, hint: '••••••', obscure: true)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: const Color(0xFF0A0E1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Connect',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              final host = hostCtrl.text.trim();
              if (host.isEmpty) return;
              final port = int.tryParse(portCtrl.text.trim()) ?? 5900;
              final profile = _VncProfile(
                id: edit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim(),
                host: host,
                port: port,
                lastUsed: DateTime.now(),
              );
              setState(() {
                final idx = _profiles.indexWhere((p) => p.id == profile.id);
                if (idx >= 0) _profiles[idx] = profile;
                else _profiles.insert(0, profile);
              });
              _saveProfiles();
              Navigator.pop(context);
              _launch(profile);
            },
          ),
        ],
      ),
    ).whenComplete(() {
      hostCtrl.dispose();
      portCtrl.dispose();
      nameCtrl.dispose();
      passCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNC Viewer'),
        actions: [
          if (_detectedViewer == null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAA00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFAA00), size: 14),
                SizedBox(width: 5),
                Text('VNC viewer not detected',
                    style: TextStyle(color: Color(0xFFFFAA00), fontSize: 11)),
              ]),
            ),
          IconButton(
              tooltip: 'New Connection',
              icon: const Icon(Icons.add),
              onPressed: () => _showDialog()),
        ],
      ),
      body: _profiles.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.monitor, size: 64,
          color: const Color(0xFF00FF88).withOpacity(0.3)),
      const SizedBox(height: 20),
      const Text('No VNC Connections',
          style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Add a VNC connection to remote control a desktop',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            foregroundColor: const Color(0xFF0A0E1A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        icon: const Icon(Icons.add),
        label: const Text('New Connection',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showDialog(),
      ),
    ]),
  );

  Widget _buildList() {
    final sorted = [..._profiles]
      ..sort((a, b) =>
          (b.lastUsed ?? DateTime(0)).compareTo(a.lastUsed ?? DateTime(0)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _ProfileCard(
        profile: sorted[i],
        launching: _launching,
        onConnect: () => _launch(sorted[i]),
        onEdit: () => _showDialog(edit: sorted[i]),
        onDelete: () {
          setState(() => _profiles.removeWhere((p) => p.id == sorted[i].id));
          _saveProfiles();
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile, required this.launching,
    required this.onConnect, required this.onEdit, required this.onDelete,
  });
  final _VncProfile profile;
  final bool launching;
  final VoidCallback onConnect, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
          ),
          child: const Icon(Icons.monitor, color: Color(0xFF00FF88), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile.name, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          Text('${profile.host}:${profile.port}', style: const TextStyle(
              color: Color(0xFF00FF88), fontSize: 12, fontFamily: 'monospace')),
          if (profile.lastUsed != null)
            Text(_ago(profile.lastUsed!),
                style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined,
            color: Colors.white38, size: 18), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline,
            color: Color(0xFFFF4466), size: 18), onPressed: onDelete),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: launching ? null : onConnect,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0E1A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Connect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InstallChip extends StatelessWidget {
  const _InstallChip(this.name, this.cmd);
  final String name, cmd;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('• $name  ', style: const TextStyle(color: Colors.white60, fontSize: 12)),
    Expanded(child: Text(cmd, style: const TextStyle(
        color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
  ]);
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.label, required this.ctrl,
    required this.icon, required this.hint,
    this.keyboardType, this.obscure = false});
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl, obscureText: obscure, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white38, size: 16),
          filled: true, fillColor: const Color(0xFF0A0E1A), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 1.5)),
        ),
      ),
    ],
  );
}

class _VncProfile {
  final String id, name, host;
  final int port;
  final DateTime? lastUsed;
  const _VncProfile({required this.id, required this.name,
    required this.host, required this.port, this.lastUsed});

  _VncProfile copyWith({DateTime? lastUsed}) => _VncProfile(
      id: id, name: name, host: host, port: port,
      lastUsed: lastUsed ?? this.lastUsed);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'host': host,
    'port': port, 'lastUsed': lastUsed?.toIso8601String()};

  factory _VncProfile.fromJson(Map<String, dynamic> j) => _VncProfile(
      id: j['id'], name: j['name'], host: j['host'], port: j['port'] ?? 5900,
      lastUsed: j['lastUsed'] != null ? DateTime.parse(j['lastUsed']) : null);
}
