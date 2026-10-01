import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RdpScreen extends StatefulWidget {
  final String? initialHost;
  const RdpScreen({super.key, this.initialHost});

  @override
  State<RdpScreen> createState() => _RdpScreenState();
}

class _RdpScreenState extends State<RdpScreen> {
  List<_RdpProfile> _profiles = [];
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles().then((_) {
      if (widget.initialHost != null) {
        _showConnectDialog(initialHost: widget.initialHost);
      }
    });
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rdp_profiles');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _profiles = list.map((e) => _RdpProfile.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'rdp_profiles', jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

  Future<void> _launch(_RdpProfile profile) async {
    setState(() => _launching = true);
    try {
      // Write a temporary .rdp file for richer options
      final rdpContent = _buildRdpFile(profile);
      final tmpFile = File(
          '${Directory.systemTemp.path}\\netwatch_${profile.host.replaceAll('.', '_')}.rdp');
      await tmpFile.writeAsString(rdpContent);

      await Process.start('mstsc.exe', [tmpFile.path],
          mode: ProcessStartMode.detached);

      // Update last used
      if (!mounted) return;
      setState(() {
        final idx = _profiles.indexWhere((p) => p.id == profile.id);
        if (idx >= 0) {
          _profiles[idx] = profile.copyWith(lastUsed: DateTime.now());
        }
      });
      await _saveProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching RDP to ${profile.host}…'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1A2235),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch RDP: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF4466),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  String _buildRdpFile(_RdpProfile p) {
    final lines = [
      'full address:s:${p.host}:${p.port}',
      'username:s:${p.username}',
      'screen mode id:i:${p.fullscreen ? 2 : 1}',
      'desktopwidth:i:${p.width}',
      'desktopheight:i:${p.height}',
      'session bpp:i:32',
      'compression:i:1',
      'keyboardhook:i:2',
      'audiocapturemode:i:0',
      'videoplaybackmode:i:1',
      'connection type:i:7',
      'networkautodetect:i:1',
      'bandwidthautodetect:i:1',
      'displayconnectionbar:i:1',
      'enableworkspacereconnect:i:0',
      'disable wallpaper:i:0',
      'allow font smoothing:i:1',
      'allow desktop composition:i:1',
      'disable full window drag:i:0',
      'disable menu anims:i:0',
      'disable themes:i:0',
      'disable cursor setting:i:0',
      'bitmapcachepersistenable:i:1',
      'audiomode:i:0',
      'redirectprinters:i:1',
      'redirectcomports:i:0',
      'redirectsmartcards:i:1',
      'redirectclipboard:i:1',
      'redirectposdevices:i:0',
      'autoreconnection enabled:i:1',
      'authentication level:i:2',
      'prompt for credentials:i:${p.username.isEmpty ? 1 : 0}',
      'negotiate security layer:i:1',
      'remoteapplicationmode:i:0',
      'alternate shell:s:',
      'shell working directory:s:',
      'gatewayhostname:s:',
      'gatewayusagemethod:i:4',
      'gatewaycredentialssource:i:4',
      'gatewayprofileusagemethod:i:0',
      'promptcredentialonce:i:0',
      'gatewaybrokeringtype:i:0',
      'use redirection server name:i:0',
      'rdgiskdcproxy:i:0',
    ];
    return lines.join('\r\n');
  }

  void _showConnectDialog({String? initialHost, _RdpProfile? edit}) {
    final hostCtrl =
        TextEditingController(text: edit?.host ?? initialHost ?? '');
    final portCtrl =
        TextEditingController(text: '${edit?.port ?? 3389}');
    final userCtrl = TextEditingController(text: edit?.username ?? '');
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    var fullscreen = edit?.fullscreen ?? true;
    var width = edit?.width ?? 1920;
    var height = edit?.height ?? 1080;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Row(
            children: [
              const Icon(Icons.desktop_windows,
                  color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 10),
              Text(edit != null ? 'Edit Connection' : 'New RDP Connection'),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogField(
                      label: 'Name (optional)',
                      ctrl: nameCtrl,
                      icon: Icons.label_outline,
                      hint: 'My Server'),
                  const SizedBox(height: 10),
                  _DialogField(
                      label: 'Host / IP',
                      ctrl: hostCtrl,
                      icon: Icons.router_outlined,
                      hint: '192.168.1.1'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogField(
                            label: 'Port',
                            ctrl: portCtrl,
                            icon: Icons.settings_ethernet,
                            hint: '3389',
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DialogField(
                            label: 'Username',
                            ctrl: userCtrl,
                            icon: Icons.person_outline,
                            hint: 'Administrator'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Resolution
                  const Text('Resolution',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ['Full HD', 1920, 1080],
                      ['HD', 1280, 720],
                      ['4K', 3840, 2160],
                    ].map((r) {
                      final selected =
                          width == r[1] && height == r[2];
                      return ChoiceChip(
                        label: Text(r[0] as String),
                        selected: selected,
                        selectedColor:
                            const Color(0xFF00D4FF).withOpacity(0.2),
                        side: BorderSide(
                            color: selected
                                ? const Color(0xFF00D4FF)
                                : Colors.white24),
                        labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF00D4FF)
                                : Colors.white54,
                            fontSize: 12),
                        onSelected: (_) =>
                            setLocal(() {
                              width = r[1] as int;
                              height = r[2] as int;
                            }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Full Screen',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    value: fullscreen,
                    activeColor: const Color(0xFF00D4FF),
                    onChanged: (v) => setLocal(() => fullscreen = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF0A0E1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Connect',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                final host = hostCtrl.text.trim();
                if (host.isEmpty) return;
                final port = int.tryParse(portCtrl.text.trim()) ?? 3389;
                final profile = _RdpProfile(
                  id: edit?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim().isNotEmpty
                      ? nameCtrl.text.trim()
                      : host,
                  host: host,
                  port: port,
                  username: userCtrl.text.trim(),
                  fullscreen: fullscreen,
                  width: width,
                  height: height,
                  lastUsed: DateTime.now(),
                );

                // Save profile
                setState(() {
                  final idx =
                      _profiles.indexWhere((p) => p.id == profile.id);
                  if (idx >= 0) {
                    _profiles[idx] = profile;
                  } else {
                    _profiles.insert(0, profile);
                  }
                });
                _saveProfiles();

                Navigator.pop(ctx);
                _launch(profile);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      hostCtrl.dispose();
      portCtrl.dispose();
      userCtrl.dispose();
      nameCtrl.dispose();
    });
  }

  void _deleteProfile(_RdpProfile profile) {
    setState(() => _profiles.removeWhere((p) => p.id == profile.id));
    _saveProfiles();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(title: const Text('RDP Client')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_outlined, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('RDP is only available on Windows',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('RDP Client'),
        actions: [
          IconButton(
            tooltip: 'New Connection',
            icon: const Icon(Icons.add),
            onPressed: () => _showConnectDialog(),
          ),
        ],
      ),
      body: _profiles.isEmpty ? _buildEmpty() : _buildProfileList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.desktop_windows_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.3)),
          const SizedBox(height: 20),
          Text('No RDP Connections',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add a Remote Desktop connection',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New Connection',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showConnectDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
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
        onEdit: () => _showConnectDialog(edit: sorted[i]),
        onDelete: () => _deleteProfile(sorted[i]),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final _RdpProfile profile;
  final bool launching;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.launching,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00D4FF).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: const Icon(Icons.desktop_windows,
                color: Color(0xFF00D4FF), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${profile.host}:${profile.port}',
                  style: const TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 12,
                      fontFamily: 'monospace'),
                ),
                if (profile.username.isNotEmpty)
                  Text(profile.username,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                if (profile.lastUsed != null)
                  Text(
                    'Last: ${_formatDate(profile.lastUsed!)}',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 10),
                  ),
              ],
            ),
          ),
          // Resolution badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${profile.width}×${profile.height}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          // Action buttons
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white38, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFFF4466), size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: launching ? null : onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Dialog field ──────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;

  const _DialogField({
    required this.label,
    required this.ctrl,
    required this.icon,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(
              color: Colors.white, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.white38, size: 16),
            filled: true,
            fillColor: const Color(0xFF0A0E1A),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
}

// ── Data model ────────────────────────────────────────────────────────────────

class _RdpProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final bool fullscreen;
  final int width;
  final int height;
  final DateTime? lastUsed;

  const _RdpProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.fullscreen,
    required this.width,
    required this.height,
    this.lastUsed,
  });

  _RdpProfile copyWith({DateTime? lastUsed}) => _RdpProfile(
        id: id,
        name: name,
        host: host,
        port: port,
        username: username,
        fullscreen: fullscreen,
        width: width,
        height: height,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'fullscreen': fullscreen,
        'width': width,
        'height': height,
        'lastUsed': lastUsed?.toIso8601String(),
      };

  factory _RdpProfile.fromJson(Map<String, dynamic> j) => _RdpProfile(
        id: j['id'],
        name: j['name'],
        host: j['host'],
        port: j['port'] ?? 3389,
        username: j['username'] ?? '',
        fullscreen: j['fullscreen'] ?? true,
        width: j['width'] ?? 1920,
        height: j['height'] ?? 1080,
        lastUsed: j['lastUsed'] != null
            ? DateTime.parse(j['lastUsed'])
            : null,
      );
}
