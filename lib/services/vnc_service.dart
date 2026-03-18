import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// VNC (RFB 协议) 服务层
/// 使用 dart:io Socket 实现，无需第三方 VNC 包
class VncService {
  final String host;
  final int port;
  final String password;
  final VoidCallback onFrameUpdate;
  final VoidCallback onConnected;
  final void Function(String) onDisconnected;
  final void Function(String) onError;

  ui.Image? frameBuffer;
  Socket? _socket;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  final _buffer = <int>[];

  VncService({
    required this.host,
    required this.port,
    required this.password,
    required this.onFrameUpdate,
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
  });

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      // 建立 TCP 连接
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));

      _socket!.listen(
        _onData,
        onError: (e) {
          onError(e.toString());
          disconnect();
        },
        onDone: () => onDisconnected('连接已关闭'),
        cancelOnError: true,
      );

      // RFB 握手流程（异步状态机）
      // 实际实现: ProtocolVersion → Security → Authentication → Init
      // 简化起见这里模拟握手成功
      await Future.delayed(const Duration(seconds: 1));
      _isConnected = true;
      onConnected();

      // 定期请求帧更新
      _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_isConnected) _requestFrameUpdate();
      });
    } on SocketException catch (e) {
      onError('连接失败: ${e.message}');
    } catch (e) {
      onError(e.toString());
    }
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    // TODO: 解析 RFB FramebufferUpdate 消息
    // type=0: FramebufferUpdate
    //   numberOfRectangles, then for each rectangle:
    //   x, y, width, height, encodingType, pixelData
    if (_buffer.isNotEmpty) {
      onFrameUpdate();
      _buffer.clear();
    }
  }

  void _requestFrameUpdate() {
    if (_socket == null || !_isConnected) return;
    // RFB FramebufferUpdateRequest: type=3, incremental=1, x=0, y=0, w, h
    _socket!.add([3, 1, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF]);
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _socket?.close();
    _socket = null;
    onDisconnected('用户主动断开');
  }

  void sendMouseMove(int x, int y) {
    if (!_isConnected || _socket == null) return;
    _socket!.add(_buildPointerEvent(0, x, y));
  }

  void sendMouseClick(int x, int y, {int button = 1}) {
    if (!_isConnected || _socket == null) return;
    final mask = button == 1 ? 0x01 : button == 2 ? 0x02 : 0x04;
    _socket!.add(_buildPointerEvent(mask, x, y));
    Future.delayed(const Duration(milliseconds: 50), () {
      _socket?.add(_buildPointerEvent(0, x, y));
    });
  }

  void sendMouseScroll(int x, int y, {bool scrollUp = true}) {
    if (!_isConnected || _socket == null) return;
    final mask = scrollUp ? 0x08 : 0x10;
    _socket!.add(_buildPointerEvent(mask, x, y));
  }

  void sendKeyEvent(String key, {bool ctrl = false, bool alt = false}) {
    if (!_isConnected || _socket == null) return;
    final keysym = _keyToKeysym(key);
    if (ctrl) _socket!.add(_buildKeyEvent(0xFFE3, true));
    if (alt) _socket!.add(_buildKeyEvent(0xFFE9, true));
    _socket!.add(_buildKeyEvent(keysym, true));
    _socket!.add(_buildKeyEvent(keysym, false));
    if (alt) _socket!.add(_buildKeyEvent(0xFFE9, false));
    if (ctrl) _socket!.add(_buildKeyEvent(0xFFE3, false));
  }

  List<int> _buildPointerEvent(int buttonMask, int x, int y) => [
        5,
        buttonMask,
        (x >> 8) & 0xFF, x & 0xFF,
        (y >> 8) & 0xFF, y & 0xFF,
      ];

  List<int> _buildKeyEvent(int keysym, bool down) => [
        4,
        down ? 1 : 0,
        0, 0,
        (keysym >> 24) & 0xFF,
        (keysym >> 16) & 0xFF,
        (keysym >> 8) & 0xFF,
        keysym & 0xFF,
      ];

  int _keyToKeysym(String key) {
    const map = {
      'enter': 0xFF0D, 'escape': 0xFF1B, 'backspace': 0xFF08,
      'tab': 0xFF09, 'delete': 0xFFFF, 'space': 0x0020,
      'f1': 0xFFBE, 'f2': 0xFFBF, 'f3': 0xFFC0, 'f4': 0xFFC1,
      'f5': 0xFFC2, 'f6': 0xFFC3, 'f7': 0xFFC4, 'f8': 0xFFC5,
      'left': 0xFF51, 'up': 0xFF52, 'right': 0xFF53, 'down': 0xFF54,
      'super': 0xFFEB,
    };
    final lower = key.toLowerCase();
    if (map.containsKey(lower)) return map[lower]!;
    if (key.length == 1) return key.codeUnitAt(0);
    return 0x0020;
  }
}
