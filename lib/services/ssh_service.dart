import 'dart:async';
import 'package:flutter/foundation.dart';

/// SSH 服务层，基于 dartssh2 实现
class SshService {
  final String host;
  final int port;
  final String username;
  final String password;
  final void Function(String) onOutput;
  final VoidCallback onConnected;
  final VoidCallback onDisconnected;
  final void Function(String) onError;

  bool _connected = false;
  StreamController<List<int>>? _stdinController;
  // SSHClient? _client;  // 实际使用 dartssh2

  SshService({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.onOutput,
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
  });

  bool get isConnected => _connected;

  Future<void> connect() async {
    try {
      // TODO: 实现真实 SSH 连接
      // import 'package:dartssh2/dartssh2.dart';
      //
      // final socket = await SSHSocket.connect(host, port);
      // _client = SSHClient(
      //   socket,
      //   username: username,
      //   onPasswordRequest: () => password,
      // );
      // await _client!.authenticated;
      // final session = await _client!.shell(
      //   pty: SSHPtyConfig(
      //     type: 'xterm-256color',
      //     width: 80,
      //     height: 24,
      //   ),
      // );
      // _stdinController = StreamController();
      // _stdinController!.stream.pipe(session.stdin);
      // session.stdout.listen((data) => onOutput(String.fromCharCodes(data)));
      // session.stderr.listen((data) => onOutput(String.fromCharCodes(data)));

      await Future.delayed(const Duration(seconds: 1));
      _connected = true;
      onConnected();
      onOutput('Last login: ${DateTime.now()}\r\n');
      onOutput('${username}@${host}:~\$ ');
    } catch (e) {
      onError(e.toString());
    }
  }

  void sendCommand(String command) {
    if (!_connected) return;
    // _stdinController?.add(command.codeUnits);
    debugPrint('SSH CMD: $command');
    // 模拟响应
    onOutput(command);
  }

  void sendRawBytes(List<int> bytes) {
    if (!_connected) return;
    // _stdinController?.add(bytes);
    debugPrint('SSH RAW: $bytes');
  }

  void disconnect() {
    if (!_connected) return;
    _stdinController?.close();
    // _client?.close();
    _connected = false;
    onDisconnected();
  }

  /// 动态调整终端大小
  void resizeTerminal(int width, int height) {
    // session.resizeTerminal(width, height);
    debugPrint('SSH resize: ${width}x${height}');
  }
}
