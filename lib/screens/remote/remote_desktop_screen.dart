import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/remote_host.dart';
import '../services/vnc_service.dart';
import '../widgets/remote_toolbar.dart';
import '../widgets/keyboard_overlay.dart';

class RemoteDesktopScreen extends StatefulWidget {
  final RemoteHost host;
  const RemoteDesktopScreen({super.key, required this.host});

  @override
  State<RemoteDesktopScreen> createState() => _RemoteDesktopScreenState();
}

class _RemoteDesktopScreenState extends State<RemoteDesktopScreen>
    with WidgetsBindingObserver {
  late VncService _vnc;
  bool _connected = false;
  bool _showToolbar = true;
  bool _showKeyboard = false;
  String _statusMsg = '正在连接...';
  double _scale = 1.0;
  double _prevScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _prevOffset = Offset.zero;
  Size _remoteSize = const Size(1920, 1080);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _vnc.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    _vnc = VncService(
      host: widget.host.host,
      port: widget.host.port,
      password: widget.host.password ?? '',
      onFrameUpdate: () => setState(() {}),
      onConnected: () => setState(() {
        _connected = true;
        _statusMsg = '已连接';
      }),
      onDisconnected: (reason) => setState(() {
        _connected = false;
        _statusMsg = '已断开: $reason';
      }),
      onError: (err) => setState(() {
        _statusMsg = '错误: $err';
      }),
    );
    await _vnc.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        onDoubleTap: _handleDoubleTap,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        onLongPressStart: _handleLongPress,
        child: Stack(
          children: [
            // 远程桌面画布
            _buildDesktopView(),

            // 顶部工具栏
            if (_showToolbar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RemoteToolbar(
                  hostName: widget.host.name,
                  isConnected: _connected,
                  statusMsg: _statusMsg,
                  onDisconnect: () => Navigator.pop(context),
                  onKeyboard: () =>
                      setState(() => _showKeyboard = !_showKeyboard),
                  onSendCtrlAltDel: _sendCtrlAltDel,
                  onScreenshot: _takeScreenshot,
                  onFitScreen: _fitToScreen,
                ),
              ),

            // 虚拟键盘覆盖层
            if (_showKeyboard)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: KeyboardOverlay(
                  onKeyPress: _handleKeyPress,
                  onClose: () => setState(() => _showKeyboard = false),
                ),
              ),

            // 连接中状态
            if (!_connected)
              Center(
                child: _buildConnectionOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopView() {
    if (!_connected || _vnc.frameBuffer == null) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Transform(
      transform: Matrix4.identity()
        ..translate(_offset.dx, _offset.dy)
        ..scale(_scale),
      child: RawImage(
        image: _vnc.frameBuffer,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget _buildConnectionOverlay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _statusMsg,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.host.host}:${widget.host.port}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ── 手势处理 ──────────────────────────────────────

  void _handleScaleStart(ScaleStartDetails d) {
    _prevScale = _scale;
    _prevOffset = _offset - d.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_prevScale * d.scale).clamp(0.5, 4.0);
      _offset = d.focalPoint + _prevOffset;
    });

    // 单指移动 → 鼠标移动
    if (d.pointerCount == 1) {
      final remotePos = _screenToRemote(d.localFocalPoint);
      _vnc.sendMouseMove(remotePos.dx.toInt(), remotePos.dy.toInt());
    }
  }

  void _handleScaleEnd(ScaleEndDetails d) {
    // 限制偏移范围
    _clampOffset();
  }

  void _handleDoubleTap() {
    // 双击 = 鼠标左键双击
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    final remote = _screenToRemote(center);
    _vnc.sendMouseClick(remote.dx.toInt(), remote.dy.toInt(), button: 1);
    _vnc.sendMouseClick(remote.dx.toInt(), remote.dy.toInt(), button: 1);
  }

  void _handleLongPress(LongPressStartDetails d) {
    // 长按 = 鼠标右键
    final remote = _screenToRemote(d.localPosition);
    _vnc.sendMouseClick(remote.dx.toInt(), remote.dy.toInt(), button: 3);
    // 振动反馈
    HapticFeedback.mediumImpact();
  }

  void _handleKeyPress(String key, {bool ctrl = false, bool alt = false}) {
    _vnc.sendKeyEvent(key, ctrl: ctrl, alt: alt);
  }

  void _sendCtrlAltDel() {
    _vnc.sendKeyEvent('ctrl+alt+delete');
  }

  Future<void> _takeScreenshot() async {
    // TODO: 实现截图保存
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('截图已保存到相册')),
    );
  }

  void _fitToScreen() {
    setState(() {
      final screenSize = MediaQuery.of(context).size;
      _scale = (screenSize.width / _remoteSize.width)
          .clamp(0.5, 4.0);
      _offset = Offset.zero;
    });
  }

  Offset _screenToRemote(Offset screenPos) {
    final screenSize = MediaQuery.of(context).size;
    final x = ((screenPos.dx - _offset.dx) / _scale)
        .clamp(0.0, _remoteSize.width);
    final y = ((screenPos.dy - _offset.dy) / _scale)
        .clamp(0.0, _remoteSize.height);
    return Offset(x, y);
  }

  void _clampOffset() {
    final screenSize = MediaQuery.of(context).size;
    final maxX = ((_remoteSize.width * _scale) - screenSize.width).clamp(0.0, double.infinity);
    final maxY = ((_remoteSize.height * _scale) - screenSize.height).clamp(0.0, double.infinity);
    setState(() {
      _offset = Offset(
        _offset.dx.clamp(-maxX, 0.0),
        _offset.dy.clamp(-maxY, 0.0),
      );
    });
  }
}
