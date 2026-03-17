import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// VNC 协议服务层
/// 实际协议实现基于 dartssh2 + 手写 RFB 协议帧解析
class VncService {
  final String host;
  final int port;
  final String password;
  final VoidCallback onFrameUpdate;
  final VoidCallback onConnected;
  final void Function(String) onDisconnected;
  final void Function(String) onError;

  ui.Image? frameBuffer;
  bool _isConnected = false;
  Timer? _mockTimer; // 开发期间用于模拟帧更新

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
      // TODO: 实现真实 RFB (VNC) 协议连接
      // 1. TCP 连接到 host:port
      // 2. 握手 ProtocolVersion
      // 3. 安全认证（VNC Authentication）
      // 4. ClientInit / ServerInit
      // 5. 启动 FramebufferUpdateRequest 循环
      //
      // 可用库: flutter_vnc 或手写 RFB 3.8 协议
      // 参考: https://www.rfc-editor.org/rfc/rfc6143

      await Future.delayed(const Duration(seconds: 2)); // 模拟连接延迟
      _isConnected = true;
      onConnected();

      // 模拟帧更新（实际应替换为 RFB FramebufferUpdate 消息解析）
      _mockTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        onFrameUpdate();
      });
    } catch (e) {
      onError(e.toString());
    }
  }

  void disconnect() {
    _mockTimer?.cancel();
    _isConnected = false;
    // TODO: 关闭 TCP 连接，发送 disconnect 消息
    onDisconnected('用户主动断开');
  }

  /// 发送鼠标移动事件
  void sendMouseMove(int x, int y) {
    if (!_isConnected) return;
    // RFB PointerEvent: type=5, buttonMask=0, x, y
    _sendRfbMessage(_buildPointerEvent(0, x, y));
  }

  /// 发送鼠标点击事件
  /// button: 1=左键, 2=中键, 3=右键
  void sendMouseClick(int x, int y, {int button = 1}) {
    if (!_isConnected) return;
    final mask = button == 1 ? 0x01 : button == 2 ? 0x02 : 0x04;
    _sendRfbMessage(_buildPointerEvent(mask, x, y));
    // 释放
    Future.delayed(const Duration(milliseconds: 50), () {
      _sendRfbMessage(_buildPointerEvent(0, x, y));
    });
  }

  /// 发送鼠标滚轮事件
  void sendMouseScroll(int x, int y, {bool scrollUp = true}) {
    if (!_isConnected) return;
    final mask = scrollUp ? 0x08 : 0x10;
    _sendRfbMessage(_buildPointerEvent(mask, x, y));
  }

  /// 发送键盘事件
  void sendKeyEvent(String key, {bool ctrl = false, bool alt = false}) {
    if (!_isConnected) return;
    // RFB KeyEvent: type=4, downFlag, keysym
    final keysym = _keyToKeysym(key);
    if (ctrl) _sendRfbMessage(_buildKeyEvent(0xFFE3, true));  // Ctrl down
    if (alt)  _sendRfbMessage(_buildKeyEvent(0xFFE9, true));  // Alt down
    _sendRfbMessage(_buildKeyEvent(keysym, true));   // Key down
    _sendRfbMessage(_buildKeyEvent(keysym, false));  // Key up
    if (alt)  _sendRfbMessage(_buildKeyEvent(0xFFE9, false));
    if (ctrl) _sendRfbMessage(_buildKeyEvent(0xFFE3, false));
  }

  // ── 私有辅助方法 ──────────────────────────────────

  List<int> _buildPointerEvent(int buttonMask, int x, int y) {
    return [
      5,                    // message-type
      buttonMask,           // button-mask
      (x >> 8) & 0xFF, x & 0xFF,  // x-position
      (y >> 8) & 0xFF, y & 0xFF,  // y-position
    ];
  }

  List<int> _buildKeyEvent(int keysym, bool down) {
    return [
      4,                                    // message-type
      down ? 1 : 0,                         // down-flag
      0, 0,                                 // padding
      (keysym >> 24) & 0xFF,
      (keysym >> 16) & 0xFF,
      (keysym >> 8) & 0xFF,
      keysym & 0xFF,
    ];
  }

  void _sendRfbMessage(List<int> bytes) {
    // TODO: 通过 Socket.write 发送字节
    debugPrint('VNC TX: $bytes');
  }

  int _keyToKeysym(String key) {
    const map = {
      'enter': 0xFF0D,
      'escape': 0xFF1B,
      'backspace': 0xFF08,
      'tab': 0xFF09,
      'space': 0x0020,
      'ctrl+alt+delete': 0xFFFF,
      'f1': 0xFFBE, 'f2': 0xFFBF, 'f3': 0xFFC0, 'f4': 0xFFC1,
      'f5': 0xFFC2, 'f6': 0xFFC3, 'f7': 0xFFC4, 'f8': 0xFFC5,
      'left': 0xFF51, 'up': 0xFF52, 'right': 0xFF53, 'down': 0xFF54,
    };
    if (map.containsKey(key.toLowerCase())) return map[key.toLowerCase()]!;
    if (key.length == 1) return key.codeUnitAt(0);
    return 0x0020;
  }
}
