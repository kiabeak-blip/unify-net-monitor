import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SshScreen extends StatefulWidget {
  final String host;
  final int port;

  const SshScreen({super.key, required this.host, this.port = 22});

  @override
  State<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends State<SshScreen> {
  // Connection form
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  // Terminal
  final _cmdCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _cmdFocus = FocusNode();

  _SshSession? _session;
  bool _connecting = false;
  bool _connected = false;
  String? _connectError;

  final List<_TermLine> _lines = [];
  final List<String> _history = [];
  int _historyIdx = -1;

  @override
  void initState() {
    super.initState();
    _portCtrl.text = widget.port.toString();
    _cmdFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_history.isNotEmpty && _historyIdx < _history.length - 1) {
          setState(() {
            _historyIdx++;
            _cmdCtrl.text = _history[_historyIdx];
            _cmdCtrl.selection =
                TextSelection.collapsed(offset: _cmdCtrl.text.length);
          });
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_historyIdx > 0) {
            _historyIdx--;
            _cmdCtrl.text = _history[_historyIdx];
          } else {
            _historyIdx = -1;
            _cmdCtrl.clear();
          }
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _session?.close();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _portCtrl.dispose();
    _cmdCtrl.dispose();
    _scrollCtrl.dispose();
    _cmdFocus.dispose();
    super.dispose();
  }

  static String _stripAnsi(String text) {
    // Remove all ANSI/VT escape sequences (colors, cursor movement, bracketed paste, etc.)
    return text
        .replaceAll(RegExp(r'\x1B\[[0-9;?]*[a-zA-Z]'), '')
        .replaceAll(RegExp(r'\x1B[()][AB012]'), '')
        .replaceAll(RegExp(r'\x1B[=>]'), '')
        .replaceAll(RegExp(r'\x0D'), '') // bare carriage return
        .replaceAll(RegExp(r'\x07'), ''); // bell
  }

  void _appendLine(String text, {_LineType type = _LineType.output}) {
    if (!mounted) return;
    final clean = _stripAnsi(text);
    // Split on newlines so each logical line is its own entry
    final parts = clean.split('\n');
    setState(() {
      for (final part in parts) {
        if (part.isNotEmpty) _lines.add(_TermLine(part, type));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _connectError = null;
      _lines.clear();
    });

    try {
      final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
      final socket = await SSHSocket.connect(
        widget.host,
        port,
        timeout: const Duration(seconds: 10),
      );
      final client = SSHClient(
        socket,
        username: _userCtrl.text.trim(),
        onPasswordRequest: () => _passCtrl.text,
      );

      final shell = await client.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: 200,
          height: 50,
        ),
      );

      _session = _SshSession(client: client, shell: shell);

      shell.stdout.listen(
        (data) => _appendLine(utf8.decode(data, allowMalformed: true)),
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );
      shell.stderr.listen(
        (data) => _appendLine(
            utf8.decode(data, allowMalformed: true), type: _LineType.error),
      );

      if (!mounted) return;
      setState(() {
        _connected = true;
        _connecting = false;
      });
      _appendLine('Connected to ${widget.host}:$port', type: _LineType.info);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cmdFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectError = e.toString();
      });
    }
  }

  void _onDisconnect() {
    if (!mounted) return;
    setState(() => _connected = false);
    _appendLine('Connection closed.', type: _LineType.info);
  }

  void _sendCommand(String cmd) {
    if (_session == null || cmd.isEmpty) return;
    _history.insert(0, cmd);
    _historyIdx = -1;
    _appendLine('> $cmd', type: _LineType.command);
    _session!.shell.stdin.add(utf8.encode('$cmd\n'));
    _cmdCtrl.clear();
  }

  void _disconnect() {
    _session?.close();
    _session = null;
    setState(() => _connected = false);
    _appendLine('Disconnected.', type: _LineType.info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SSH Terminal'),
            Text(
              widget.host,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          if (_connected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off, size: 16,
                  color: Color(0xFFFF4466)),
              label: const Text('Disconnect',
                  style: TextStyle(
                      color: Color(0xFFFF4466), fontSize: 12)),
            ),
        ],
      ),
      body: _connected ? _buildTerminal() : _buildConnectForm(),
    );
  }

  // ── Connection form ────────────────────────────────────────────────────────

  Widget _buildConnectForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.terminal,
                        color: Color(0xFF00D4FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SSH Connection',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(widget.host,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Fields
              _FormField(
                label: 'Username',
                controller: _userCtrl,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _FormField(
                label: 'Password',
                controller: _passCtrl,
                icon: Icons.lock_outline,
                obscure: true,
                onSubmit: _connecting ? null : _connect,
              ),
              const SizedBox(height: 12),
              _FormField(
                label: 'Port',
                controller: _portCtrl,
                icon: Icons.settings_ethernet,
                keyboardType: TextInputType.number,
              ),

              if (_connectError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4466).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF4466).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFFF4466), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _connectError!,
                          style: const TextStyle(
                              color: Color(0xFFFF4466), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A0E1A)),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: Text(
                    _connecting ? 'Connecting…' : 'Connect',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Terminal ───────────────────────────────────────────────────────────────

  void _copyAll() {
    final text = _lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terminal output copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1A2235),
      ),
    );
  }

  Future<void> _pasteToInput() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final pos = _cmdCtrl.selection.isValid
          ? _cmdCtrl.selection.baseOffset
          : _cmdCtrl.text.length;
      final before = _cmdCtrl.text.substring(0, pos);
      final after = _cmdCtrl.text.substring(pos);
      _cmdCtrl.text = before + data!.text! + after;
      _cmdCtrl.selection = TextSelection.collapsed(
          offset: pos + data.text!.length);
    }
  }

  Widget _buildTerminal() {
    return Column(
      children: [
        // Toolbar
        Container(
          color: const Color(0xFF0D1117),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              _ToolbarBtn(
                icon: Icons.content_copy,
                label: 'Copy All',
                onTap: _copyAll,
              ),
              const SizedBox(width: 8),
              _ToolbarBtn(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear',
                onTap: () => setState(() => _lines.clear()),
              ),
            ],
          ),
        ),

        // Output area
        Expanded(
          child: GestureDetector(
            onTap: () => _cmdFocus.requestFocus(),
            child: Container(
              color: const Color(0xFF050A0F),
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: _lines.length,
                  itemBuilder: (_, i) => _TermLineWidget(line: _lines[i]),
                ),
              ),
            ),
          ),
        ),

        // Input bar
        Container(
          color: const Color(0xFF0D1117),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('\$',
                  style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cmdCtrl,
                  focusNode: _cmdFocus,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a command…  (Ctrl+V to paste)',
                    hintStyle: TextStyle(
                        color: Colors.white24, fontFamily: 'monospace'),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: _sendCommand,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 4),
              // Paste button
              Tooltip(
                message: 'Paste (Ctrl+V)',
                child: GestureDetector(
                  onTap: _pasteToInput,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.content_paste,
                        color: Color(0xFF00FF88), size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _sendCommand(_cmdCtrl.text.trim()),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.send,
                      color: Color(0xFF00D4FF), size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Session wrapper ───────────────────────────────────────────────────────────

class _SshSession {
  final SSHClient client;
  final SSHSession shell;
  _SshSession({required this.client, required this.shell});

  void close() {
    shell.close();
    client.close();
  }
}

// ── Terminal line model ───────────────────────────────────────────────────────

enum _LineType { output, command, error, info }

class _TermLine {
  final String text;
  final _LineType type;
  _TermLine(this.text, this.type);
}

class _TermLineWidget extends StatelessWidget {
  final _TermLine line;
  const _TermLineWidget({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final color = switch (line.type) {
      _LineType.command => const Color(0xFF00D4FF),
      _LineType.error   => const Color(0xFFFF4466),
      _LineType.info    => const Color(0xFFFFAA00),
      _LineType.output  => Colors.white70,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line.text,
        style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5),
      ),
    );
  }
}

// ── Toolbar button ────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolbarBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white54),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Form field helper ─────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmit;

  const _FormField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(
              color: Colors.white, fontFamily: 'monospace', fontSize: 14),
          onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white38, size: 18),
            filled: true,
            fillColor: const Color(0xFF1A2235),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
