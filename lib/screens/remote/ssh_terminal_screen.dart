import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/remote_host.dart';
import '../../services/ssh_service.dart';

class SshTerminalScreen extends StatefulWidget {
  final RemoteHost host;
  const SshTerminalScreen({super.key, required this.host});

  @override
  State<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends State<SshTerminalScreen> {
  late SshService _ssh;
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _outputLines = <_TerminalLine>[];
  bool _connected = false;
  bool _showInput = true;
  String _currentInput = '';

  static const _ansiColors = {
    '30': Color(0xFF000000), '31': Color(0xFFFF5555),
    '32': Color(0xFF50FA7B), '33': Color(0xFFF1FA8C),
    '34': Color(0xFF6272A4), '35': Color(0xFFFF79C6),
    '36': Color(0xFF8BE9FD), '37': Color(0xFFF8F8F2),
  };

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _ssh.disconnect();
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    _appendOutput('正在连接 ${widget.host.host}:${widget.host.port}...', color: Colors.yellow);
    _ssh = SshService(
      host: widget.host.host,
      port: widget.host.port,
      username: widget.host.username ?? 'root',
      password: widget.host.password ?? '',
      onOutput: (data) {
        setState(() => _appendOutput(data));
        _scrollToBottom();
      },
      onConnected: () {
        setState(() {
          _connected = true;
          _appendOutput('✓ 已连接到 ${widget.host.name}', color: Colors.greenAccent);
        });
      },
      onDisconnected: () {
        setState(() {
          _connected = false;
          _appendOutput('连接已断开', color: Colors.orange);
        });
      },
      onError: (e) {
        setState(() => _appendOutput('错误: $e', color: Colors.red));
      },
    );
    await _ssh.connect();
  }

  void _appendOutput(String text, {Color? color}) {
    _outputLines.add(_TerminalLine(text: text, color: color));
    if (_outputLines.length > 2000) _outputLines.removeAt(0);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              _connected ? Icons.circle : Icons.circle_outlined,
              color: _connected ? Colors.greenAccent : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 8),
            Text(
              widget.host.name,
              style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: () => setState(() => _showInput = !_showInput),
            tooltip: '输入框',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: _copyOutput,
            tooltip: '复制内容',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() => _outputLines.clear()),
            tooltip: '清屏',
          ),
        ],
      ),
      body: Column(
        children: [
          // 终端输出区
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: _outputLines.length,
                  itemBuilder: (_, i) {
                    final line = _outputLines[i];
                    return Text(
                      line.text,
                      style: TextStyle(
                        color: line.color ?? const Color(0xFFF8F8F2),
                        fontFamily: 'Courier New',
                        fontSize: 13,
                        height: 1.4,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 快捷键栏
          _buildShortcutBar(),

          // 输入栏
          if (_showInput) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildShortcutBar() {
    const shortcuts = ['Tab', 'Ctrl+C', 'Ctrl+D', 'Ctrl+Z', '↑', '↓', 'Esc'];
    return Container(
      height: 40,
      color: const Color(0xFF181825),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendShortcut(shortcuts[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF313244),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcuts[i],
              style: const TextStyle(
                color: Color(0xFFF8F8F2),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF181825),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        children: [
          const Text(
            '❯ ',
            style: TextStyle(
              color: Color(0xFF50FA7B),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              autofocus: false,
              style: const TextStyle(
                color: Color(0xFFF8F8F2),
                fontFamily: 'Courier New',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                hintText: '输入命令...',
                hintStyle: TextStyle(color: Color(0xFF6272A4)),
              ),
              onSubmitted: _sendCommand,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF50FA7B), size: 20),
            onPressed: () => _sendCommand(_inputCtrl.text),
          ),
        ],
      ),
    );
  }

  void _sendCommand(String cmd) {
    if (cmd.isEmpty) return;
    _ssh.sendCommand('$cmd\n');
    _inputCtrl.clear();
  }

  void _sendShortcut(String shortcut) {
    switch (shortcut) {
      case 'Tab':       _ssh.sendRawBytes([0x09]); break;
      case 'Ctrl+C':    _ssh.sendRawBytes([0x03]); break;
      case 'Ctrl+D':    _ssh.sendRawBytes([0x04]); break;
      case 'Ctrl+Z':    _ssh.sendRawBytes([0x1A]); break;
      case '↑':         _ssh.sendRawBytes([0x1B, 0x5B, 0x41]); break;
      case '↓':         _ssh.sendRawBytes([0x1B, 0x5B, 0x42]); break;
      case 'Esc':       _ssh.sendRawBytes([0x1B]); break;
    }
  }

  void _copyOutput() {
    final text = _outputLines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
  }
}

class _TerminalLine {
  final String text;
  final Color? color;
  _TerminalLine({required this.text, this.color});
}
