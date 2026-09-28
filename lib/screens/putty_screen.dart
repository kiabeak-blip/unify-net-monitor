// lib/screens/putty_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _puttyPaths = [
  r'C:\Program Files\PuTTY\putty.exe',
  r'C:\Program Files (x86)\PuTTY\putty.exe',
  r'C:\Users\Public\Desktop\PuTTY.exe',
];

class PuttyScreen extends StatefulWidget {
  final String? initialHost;
  const PuttyScreen({super.key, this.initialHost});

  @override
  State<PuttyScreen> createState() => _PuttyScreenState();
}

class _PuttyScreenState extends State<PuttyScreen> {
  List<_PuttyProfile> _profiles = [];
  bool _launching = false;
  String? _puttyPath;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _detectPutty();
    if (widget.initialHost != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showDialog(initialHost: widget.initialHost));
    }
  }

  Future<void> _detectPutty() async {
    for (final path in _puttyPaths) {
      if (File(path).existsSync()) {
        setState(() { _puttyPath = path; _checked = true; });
        return;
      }
    }
    try {
      final r = await Process.run('putty', ['-help'],
          stdoutEncoding: const SystemEncoding());
      if (r.exitCode == 0 || r.exitCode == 1) {
        setState(() { _puttyPath = 'putty'; _checked = true; });
        return;
      }
    } catch (_) {}
    setState(() => _checked = true);
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('putty_profiles');
    if (raw != null) {
      setState(() => _profiles =
          (jsonDecode(raw) as List).map((e) => _PuttyProfile.fromJson(e)).toList());
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('putty_profiles',
        jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

  Future<void> _launch(_PuttyProfile p) async {
    if (_puttyPath == null) { _showNotFound(); return; }
    setState(() => _launching = true);
    try {
      final args = [
        '-${p.protocol}',
        p.host,
        '-P', '${p.port}',
        if (p.username.isNotEmpty) ...['-l', p.username],
      ];
      await Process.start(_puttyPath!, args, mode: ProcessStartMode.detached);
      setState(() {
        final idx = _profiles.indexWhere((x) => x.id == p.id);
        if (idx >= 0) _profiles[idx] = p.copyWith(lastUsed: DateTime.now());
      });
      await _saveProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Launching PuTTY to ${p.host}…'),
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

  void _showNotFound() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAA00)),
          SizedBox(width: 10),
          Text('PuTTY Not Found'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Install PuTTY to use this tool:',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          _CopyRow('winget install PuTTY.PuTTY'),
        ]),
        actions: [TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showDialog({String? initialHost, _PuttyProfile? edit}) {
    final hostCtrl = TextEditingController(text: edit?.host ?? initialHost ?? '');
    final portCtrl = TextEditingController(text: '${edit?.port ?? 22}');
    final userCtrl = TextEditingController(text: edit?.username ?? '');
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    var proto = edit?.protocol ?? 'ssh';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Row(children: [
            const Icon(Icons.terminal, color: Color(0xFFFFAA00), size: 20),
            const SizedBox(width: 10),
            Text(edit != null ? 'Edit Connection' : 'New PuTTY Connection'),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DialogField(label: 'Name (optional)', ctrl: nameCtrl,
                  icon: Icons.label_outline, hint: 'My Server'),
              const SizedBox(height: 10),
              _DialogField(label: 'Host / IP', ctrl: hostCtrl,
                  icon: Icons.computer, hint: '192.168.1.100'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _DialogField(label: 'Port', ctrl: portCtrl,
                    icon: Icons.settings_ethernet, hint: '22',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _DialogField(label: 'Username', ctrl: userCtrl,
                    icon: Icons.person_outline, hint: 'root')),
              ]),
              const SizedBox(height: 12),
              // Protocol selector
              const Align(alignment: Alignment.centerLeft,
                  child: Text('Protocol',
                      style: TextStyle(color: Colors.white54, fontSize: 11,
                          fontWeight: FontWeight.w500))),
              const SizedBox(height: 6),
              Row(children: [
                for (final p in ['ssh', 'telnet', 'serial'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.toUpperCase()),
                      selected: proto == p,
                      selectedColor: const Color(0xFFFFAA00).withOpacity(0.2),
                      side: BorderSide(
                          color: proto == p ? const Color(0xFFFFAA00) : Colors.white24),
                      labelStyle: TextStyle(
                          color: proto == p ? const Color(0xFFFFAA00) : Colors.white54,
                          fontSize: 12),
                      onSelected: (_) => setLocal(() {
                        proto = p;
                        if (p == 'ssh') portCtrl.text = '22';
                        if (p == 'telnet') portCtrl.text = '23';
                      }),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAA00),
                  foregroundColor: const Color(0xFF0A0E1A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                final host = hostCtrl.text.trim();
                if (host.isEmpty) return;
                final port = int.tryParse(portCtrl.text.trim()) ?? 22;
                final profile = _PuttyProfile(
                  id: edit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim(),
                  host: host, port: port,
                  username: userCtrl.text.trim(),
                  protocol: proto,
                  lastUsed: DateTime.now(),
                );
                setState(() {
                  final idx = _profiles.indexWhere((p) => p.id == profile.id);
                  if (idx >= 0) _profiles[idx] = profile;
                  else _profiles.insert(0, profile);
                });
                _saveProfiles();
                Navigator.pop(ctx);
                _launch(profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PuTTY'),
        actions: [
          if (_checked && _puttyPath == null)
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
                Text('PuTTY not installed',
                    style: TextStyle(color: Color(0xFFFFAA00), fontSize: 11)),
              ]),
            ),
          IconButton(tooltip: 'New Connection', icon: const Icon(Icons.add),
              onPressed: () => _showDialog()),
        ],
      ),
      body: _profiles.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.terminal, size: 64,
          color: const Color(0xFFFFAA00).withOpacity(0.3)),
      const SizedBox(height: 20),
      const Text('No PuTTY Connections',
          style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Add SSH / Telnet connections to open in PuTTY',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFAA00),
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
      itemBuilder: (_, i) => _Card(
        profile: sorted[i], launching: _launching,
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

class _Card extends StatelessWidget {
  const _Card({required this.profile, required this.launching,
    required this.onConnect, required this.onEdit, required this.onDelete});
  final _PuttyProfile profile;
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
        border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFAA00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.3)),
          ),
          child: const Icon(Icons.terminal, color: Color(0xFFFFAA00), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile.name, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          Text('${profile.protocol.toUpperCase()}  ${profile.host}:${profile.port}',
              style: const TextStyle(color: Color(0xFFFFAA00),
                  fontSize: 12, fontFamily: 'monospace')),
          if (profile.username.isNotEmpty)
            Text(profile.username,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
              backgroundColor: const Color(0xFFFFAA00),
              foregroundColor: const Color(0xFF0A0E1A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Open',
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

class _CopyRow extends StatelessWidget {
  const _CopyRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1)));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
        const Icon(Icons.copy, color: Colors.white24, size: 12),
      ]),
    ),
  );
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
        style: const TextStyle(color: Colors.white,
            fontFamily: 'monospace', fontSize: 13),
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

class _PuttyProfile {
  final String id, name, host, username, protocol;
  final int port;
  final DateTime? lastUsed;

  const _PuttyProfile({required this.id, required this.name,
    required this.host, required this.port, required this.username,
    required this.protocol, this.lastUsed});

  _PuttyProfile copyWith({DateTime? lastUsed}) => _PuttyProfile(
      id: id, name: name, host: host, port: port, username: username,
      protocol: protocol, lastUsed: lastUsed ?? this.lastUsed);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'host': host,
    'port': port, 'username': username, 'protocol': protocol,
    'lastUsed': lastUsed?.toIso8601String()};

  factory _PuttyProfile.fromJson(Map<String, dynamic> j) => _PuttyProfile(
      id: j['id'], name: j['name'], host: j['host'], port: j['port'] ?? 22,
      username: j['username'] ?? '', protocol: j['protocol'] ?? 'ssh',
      lastUsed: j['lastUsed'] != null ? DateTime.parse(j['lastUsed']) : null);
}
