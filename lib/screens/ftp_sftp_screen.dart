// lib/screens/ftp_sftp_screen.dart
// Combined FTP / SFTP connection manager — launches WinSCP or FileZilla if installed,
// falls back to Windows built-in FTP (ftp://) for FTP connections.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _winscpPaths = [
  r'C:\Program Files (x86)\WinSCP\WinSCP.exe',
  r'C:\Program Files\WinSCP\WinSCP.exe',
];
const _filezillaPaths = [
  r'C:\Program Files\FileZilla FTP Client\filezilla.exe',
  r'C:\Program Files (x86)\FileZilla FTP Client\filezilla.exe',
];

enum _Protocol { ftp, sftp, ftps }

Color _protoColor(_Protocol p) => switch (p) {
  _Protocol.ftp  => const Color(0xFF00D4FF),
  _Protocol.sftp => const Color(0xFF00FF88),
  _Protocol.ftps => const Color(0xFFFFAA00),
};

IconData _protoIcon(_Protocol p) => switch (p) {
  _Protocol.ftp  => Icons.folder_open,
  _Protocol.sftp => Icons.lock,
  _Protocol.ftps => Icons.security,
};

class FtpSftpScreen extends StatefulWidget {
  final String? initialHost;
  final bool startAsSftp;
  const FtpSftpScreen({super.key, this.initialHost, this.startAsSftp = false});

  @override
  State<FtpSftpScreen> createState() => _FtpSftpScreenState();
}

class _FtpSftpScreenState extends State<FtpSftpScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<_FtpProfile> _profiles = [];
  bool _launching = false;
  String? _winscpPath;
  String? _filezillaPath;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, vsync: this, initialIndex: widget.startAsSftp ? 1 : 0);
    _loadProfiles();
    _detectClients();
    if (widget.initialHost != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showDialog(initialHost: widget.initialHost,
              protocol: widget.startAsSftp ? _Protocol.sftp : _Protocol.ftp));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _detectClients() async {
    for (final p in _winscpPaths) {
      if (File(p).existsSync()) { _winscpPath = p; break; }
    }
    for (final p in _filezillaPaths) {
      if (File(p).existsSync()) { _filezillaPath = p; break; }
    }
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ftp_profiles');
    if (raw != null) {
      setState(() => _profiles =
          (jsonDecode(raw) as List).map((e) => _FtpProfile.fromJson(e)).toList());
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ftp_profiles',
        jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

  Future<void> _launch(_FtpProfile p) async {
    setState(() => _launching = true);
    try {
      bool launched = false;

      // SFTP always prefers WinSCP
      if (p.protocol == _Protocol.sftp && _winscpPath != null) {
        final url = 'sftp://${_encodeUser(p)}${p.host}:${p.port}';
        await Process.start(_winscpPath!, [url], mode: ProcessStartMode.detached);
        launched = true;
      }

      // FTP: try FileZilla → WinSCP → Windows Explorer
      if (!launched && p.protocol == _Protocol.ftp) {
        if (_filezillaPath != null) {
          final url = 'ftp://${_encodeUser(p)}${p.host}:${p.port}';
          await Process.start(_filezillaPath!, [url],
              mode: ProcessStartMode.detached);
          launched = true;
        } else if (_winscpPath != null) {
          final url = 'ftp://${_encodeUser(p)}${p.host}:${p.port}';
          await Process.start(_winscpPath!, [url], mode: ProcessStartMode.detached);
          launched = true;
        }
      }

      // FTPS: WinSCP
      if (!launched && p.protocol == _Protocol.ftps && _winscpPath != null) {
        final url = 'ftps://${_encodeUser(p)}${p.host}:${p.port}';
        await Process.start(_winscpPath!, [url], mode: ProcessStartMode.detached);
        launched = true;
      }

      if (!launched) {
        // Last resort for FTP: open in Windows Explorer
        if (p.protocol == _Protocol.ftp) {
          final url = 'ftp://${p.host}:${p.port}';
          await Process.start('explorer', [url], mode: ProcessStartMode.detached);
          launched = true;
        } else {
          _showNoClientDialog(p.protocol);
          return;
        }
      }

      setState(() {
        final idx = _profiles.indexWhere((x) => x.id == p.id);
        if (idx >= 0) _profiles[idx] = p.copyWith(lastUsed: DateTime.now());
      });
      await _saveProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connecting to ${p.host}…'),
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

  String _encodeUser(_FtpProfile p) {
    if (p.username.isEmpty) return '';
    final pass = p.password.isEmpty ? '' : ':${Uri.encodeComponent(p.password)}';
    return '${Uri.encodeComponent(p.username)}$pass@';
  }

  void _showNoClientDialog(_Protocol proto) {
    final isSftp = proto == _Protocol.sftp || proto == _Protocol.ftps;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAA00)),
          SizedBox(width: 10),
          Text('No FTP/SFTP Client Found'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(isSftp
              ? 'Install WinSCP for SFTP/FTPS support:'
              : 'Install one of these FTP clients:',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          _CopyRow('WinSCP', 'winget install WinSCP.WinSCP'),
          const SizedBox(height: 6),
          _CopyRow('FileZilla', 'winget install TimKosse.FileZilla.Client'),
        ]),
        actions: [TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showDialog({String? initialHost, _FtpProfile? edit,
      _Protocol protocol = _Protocol.ftp}) {
    final hostCtrl = TextEditingController(text: edit?.host ?? initialHost ?? '');
    final portCtrl = TextEditingController(text: '${edit?.port ?? _defaultPort(protocol)}');
    final userCtrl = TextEditingController(text: edit?.username ?? '');
    final passCtrl = TextEditingController(text: edit?.password ?? '');
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    var proto = edit?.protocol ?? protocol;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Row(children: [
            Icon(_protoIcon(proto), color: _protoColor(proto), size: 20),
            const SizedBox(width: 10),
            Text(edit != null ? 'Edit Connection' : 'New Connection'),
          ]),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Protocol selector
                Row(children: [
                  for (final p in _Protocol.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.name.toUpperCase()),
                        selected: proto == p,
                        selectedColor: _protoColor(p).withOpacity(0.2),
                        side: BorderSide(
                            color: proto == p ? _protoColor(p) : Colors.white24),
                        labelStyle: TextStyle(
                            color: proto == p ? _protoColor(p) : Colors.white54,
                            fontSize: 11),
                        onSelected: (_) => setLocal(() {
                          proto = p;
                          portCtrl.text = '${_defaultPort(p)}';
                        }),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                _DialogField(label: 'Name (optional)', ctrl: nameCtrl,
                    icon: Icons.label_outline, hint: 'My FTP Server'),
                const SizedBox(height: 10),
                _DialogField(label: 'Host / IP', ctrl: hostCtrl,
                    icon: Icons.computer, hint: '192.168.1.100'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _DialogField(label: 'Port', ctrl: portCtrl,
                      icon: Icons.settings_ethernet,
                      hint: '${_defaultPort(proto)}',
                      keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _DialogField(label: 'Username', ctrl: userCtrl,
                      icon: Icons.person_outline, hint: 'anonymous')),
                ]),
                const SizedBox(height: 10),
                _DialogField(label: 'Password', ctrl: passCtrl,
                    icon: Icons.lock_outline, hint: '••••••', obscure: true),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _protoColor(proto),
                  foregroundColor: const Color(0xFF0A0E1A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Connect',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                final host = hostCtrl.text.trim();
                if (host.isEmpty) return;
                final port = int.tryParse(portCtrl.text.trim()) ?? _defaultPort(proto);
                final profile = _FtpProfile(
                  id: edit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim(),
                  host: host, port: port,
                  username: userCtrl.text.trim(),
                  password: passCtrl.text,
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

  static int _defaultPort(_Protocol p) =>
      p == _Protocol.sftp ? 22 : p == _Protocol.ftps ? 990 : 21;

  @override
  Widget build(BuildContext context) {
    final ftpProfiles = _profiles
        .where((p) => p.protocol == _Protocol.ftp || p.protocol == _Protocol.ftps)
        .toList()
      ..sort((a, b) =>
          (b.lastUsed ?? DateTime(0)).compareTo(a.lastUsed ?? DateTime(0)));
    final sftpProfiles = _profiles
        .where((p) => p.protocol == _Protocol.sftp)
        .toList()
      ..sort((a, b) =>
          (b.lastUsed ?? DateTime(0)).compareTo(a.lastUsed ?? DateTime(0)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP / SFTP'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF00D4FF),
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'FTP / FTPS'),
            Tab(text: 'SFTP'),
          ],
        ),
        actions: [
          if (_checked && _winscpPath == null && _filezillaPath == null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAA00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFAA00).withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFAA00), size: 14),
                SizedBox(width: 5),
                Text('No FTP client detected',
                    style: TextStyle(color: Color(0xFFFFAA00), fontSize: 11)),
              ]),
            ),
          IconButton(
            tooltip: 'New Connection',
            icon: const Icon(Icons.add),
            onPressed: () => _showDialog(
                protocol: _tabs.index == 1 ? _Protocol.sftp : _Protocol.ftp),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileList(
            profiles: ftpProfiles, launching: _launching,
            emptyIcon: Icons.folder_open,
            emptyText: 'No FTP connections',
            emptySubtext: 'Add an FTP or FTPS connection',
            accentColor: const Color(0xFF00D4FF),
            onAdd: () => _showDialog(protocol: _Protocol.ftp),
            onConnect: _launch,
            onEdit: (p) => _showDialog(edit: p),
            onDelete: (p) {
              setState(() => _profiles.removeWhere((x) => x.id == p.id));
              _saveProfiles();
            },
          ),
          _ProfileList(
            profiles: sftpProfiles, launching: _launching,
            emptyIcon: Icons.lock,
            emptyText: 'No SFTP connections',
            emptySubtext: 'Add a secure SFTP connection (requires WinSCP)',
            accentColor: const Color(0xFF00FF88),
            onAdd: () => _showDialog(protocol: _Protocol.sftp),
            onConnect: _launch,
            onEdit: (p) => _showDialog(edit: p),
            onDelete: (p) {
              setState(() => _profiles.removeWhere((x) => x.id == p.id));
              _saveProfiles();
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.profiles, required this.launching,
    required this.emptyIcon, required this.emptyText,
    required this.emptySubtext, required this.accentColor,
    required this.onAdd, required this.onConnect,
    required this.onEdit, required this.onDelete,
  });
  final List<_FtpProfile> profiles;
  final bool launching;
  final IconData emptyIcon;
  final String emptyText, emptySubtext;
  final Color accentColor;
  final VoidCallback onAdd;
  final void Function(_FtpProfile) onConnect, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon, size: 64, color: accentColor.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(emptyText, style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(emptySubtext,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: const Color(0xFF0A0E1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12)),
            icon: const Icon(Icons.add),
            label: const Text('New Connection',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: onAdd,
          ),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: profiles.length,
      itemBuilder: (_, i) => _ProfileCard(
        profile: profiles[i], launching: launching,
        accentColor: accentColor,
        onConnect: () => onConnect(profiles[i]),
        onEdit: () => onEdit(profiles[i]),
        onDelete: () => onDelete(profiles[i]),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile, required this.launching,
    required this.accentColor, required this.onConnect,
    required this.onEdit, required this.onDelete,
  });
  final _FtpProfile profile;
  final bool launching;
  final Color accentColor;
  final VoidCallback onConnect, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Icon(_protoIcon(profile.protocol),
              color: accentColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(profile.name, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          Text('${profile.protocol.name.toUpperCase()}  '
              '${profile.host}:${profile.port}',
              style: TextStyle(color: accentColor,
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
              backgroundColor: accentColor,
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

class _CopyRow extends StatelessWidget {
  const _CopyRow(this.name, this.cmd);
  final String name, cmd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('• $name', style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 3),
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: cmd));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Copied'), duration: Duration(seconds: 1)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4FF).withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.2)),
          ),
          child: Row(children: [
            Expanded(child: Text(cmd, style: const TextStyle(
                color: Color(0xFF00D4FF), fontSize: 11, fontFamily: 'monospace'))),
            const Icon(Icons.copy, color: Colors.white24, size: 12),
          ]),
        ),
      ),
    ],
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

class _FtpProfile {
  final String id, name, host, username, password;
  final int port;
  final _Protocol protocol;
  final DateTime? lastUsed;

  const _FtpProfile({required this.id, required this.name,
    required this.host, required this.port, required this.username,
    required this.password, required this.protocol, this.lastUsed});

  _FtpProfile copyWith({DateTime? lastUsed}) => _FtpProfile(
      id: id, name: name, host: host, port: port, username: username,
      password: password, protocol: protocol,
      lastUsed: lastUsed ?? this.lastUsed);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'host': host,
    'port': port, 'username': username, 'password': password,
    'protocol': protocol.name, 'lastUsed': lastUsed?.toIso8601String()};

  factory _FtpProfile.fromJson(Map<String, dynamic> j) => _FtpProfile(
      id: j['id'], name: j['name'], host: j['host'], port: j['port'] ?? 21,
      username: j['username'] ?? '', password: j['password'] ?? '',
      protocol: _Protocol.values.firstWhere((p) => p.name == j['protocol'],
          orElse: () => _Protocol.ftp),
      lastUsed: j['lastUsed'] != null ? DateTime.parse(j['lastUsed']) : null);
}
