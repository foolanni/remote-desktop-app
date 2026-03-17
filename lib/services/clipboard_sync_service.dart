import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 剪贴板同步服务
/// 实现本地 ↔ 远程剪贴板双向同步
class ClipboardSyncService {
  String? _lastLocalClipboard;
  String? _lastRemoteClipboard;
  Timer? _pollTimer;
  final void Function(String text) onRemoteClipboard;
  bool _enabled = false;

  ClipboardSyncService({required this.onRemoteClipboard});

  /// 启动剪贴板监听（每500ms轮询本地剪贴板）
  void start() {
    _enabled = true;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_enabled) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text != _lastLocalClipboard) {
        _lastLocalClipboard = text;
        _syncToRemote(text);
      }
    });
  }

  void stop() {
    _enabled = false;
    _pollTimer?.cancel();
  }

  /// 收到远端剪贴板更新时调用
  void onReceiveFromRemote(String text) {
    if (text == _lastRemoteClipboard) return;
    _lastRemoteClipboard = text;
    // 写入本地剪贴板
    Clipboard.setData(ClipboardData(text: text));
    onRemoteClipboard(text);
    debugPrint('📋 远端剪贴板已同步到本地: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}');
  }

  void _syncToRemote(String text) {
    // TODO: 通过 VNC ClientCutText 消息发送到远端
    // RFB协议: type=6, length, text
    debugPrint('📋 本地剪贴板同步到远端: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}');
  }

  /// 手动触发：粘贴到远端
  Future<void> pasteToRemote() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _syncToRemote(data!.text!);
    }
  }
}
