import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CliStatus { offline, online }
enum SessionStatus { idle, running, waiting }
enum ExecutionMode { plan, ask, auto, dangerous }

class PermissionRequest {
  final String id;
  final String sessionId;
  final String tool;
  final String description;
  final Map<String, dynamic> args;
  final DateTime requestedAt;

  PermissionRequest({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.description,
    required this.args,
    required this.requestedAt,
  });
}

class AgentSession {
  final String id;
  String title;
  SessionStatus status;
  ExecutionMode mode;
  List<String> output;
  List<PermissionRequest> pendingPermissions;
  DateTime lastActivity;

  AgentSession({
    required this.id,
    required this.title,
    this.status = SessionStatus.idle,
    this.mode = ExecutionMode.ask,
    List<String>? output,
    List<PermissionRequest>? pendingPermissions,
    DateTime? lastActivity,
  })  : output = output ?? [],
        pendingPermissions = pendingPermissions ?? [],
        lastActivity = lastActivity ?? DateTime.now();
}

/// PUNK 核心服务 - 管理 WebSocket 连接和会话状态
class PunkService extends ChangeNotifier {
  WebSocketChannel? _channel;
  String? _relayUrl;
  String? _token;
  String? _deviceId;

  CliStatus _cliStatus = CliStatus.offline;
  final Map<String, AgentSession> _sessions = {};
  bool _connected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  CliStatus get cliStatus => _cliStatus;
  bool get connected => _connected;
  String? get deviceId => _deviceId;
  List<AgentSession> get sessions =>
      _sessions.values.toList()
        ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  List<PermissionRequest> get allPendingPermissions =>
      _sessions.values.expand((s) => s.pendingPermissions).toList();

  int get totalPendingCount =>
      _sessions.values.fold(0, (sum, s) => sum + s.pendingPermissions.length);

  Future<void> connect(String relayUrl, String token, String deviceId) async {
    _relayUrl = relayUrl;
    _token = token;
    _deviceId = deviceId;

    await _persistConfig(relayUrl, token, deviceId);
    _doConnect();
  }

  Future<void> loadAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    _relayUrl = prefs.getString('punk_relay_url');
    _token = prefs.getString('punk_token');
    _deviceId = prefs.getString('punk_device_id');
    if (_relayUrl != null && _token != null) {
      _doConnect();
    }
  }

  void _doConnect() {
    if (_relayUrl == null || _token == null) return;
    try {
      final uri = Uri.parse('$_relayUrl?token=$_token&role=phone');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;
      notifyListeners();

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 心跳
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _send({'type': 'ping'});
      });
    } catch (e) {
      debugPrint('PunkService connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      _handleMessage(msg);
    } catch (e) {
      debugPrint('PunkService parse error: $e');
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'connected':
        _cliStatus = (msg['cliOnline'] as bool? ?? false)
            ? CliStatus.online
            : CliStatus.offline;
        break;

      case 'cli_online':
        _cliStatus = CliStatus.online;
        break;

      case 'cli_offline':
        _cliStatus = CliStatus.offline;
        break;

      case 'session_update':
        _updateSession(msg['session'] as Map<String, dynamic>);
        break;

      case 'session_list':
        final list = msg['sessions'] as List<dynamic>? ?? [];
        for (final s in list) {
          _updateSession(s as Map<String, dynamic>);
        }
        break;

      case 'output':
        final sessionId = msg['sessionId'] as String;
        final session = _sessions[sessionId];
        if (session != null) {
          session.output.add(msg['data'] as String);
          if (session.output.length > 500) session.output.removeAt(0);
          session.lastActivity = DateTime.now();
        }
        break;

      case 'permission_request':
        final sessionId = msg['sessionId'] as String;
        final session = _sessions.putIfAbsent(
          sessionId,
          () => AgentSession(id: sessionId, title: 'Session'),
        );
        session.status = SessionStatus.waiting;
        session.pendingPermissions.add(PermissionRequest(
          id: msg['permissionId'] as String,
          sessionId: sessionId,
          tool: msg['tool'] as String,
          description: msg['description'] as String,
          args: (msg['args'] as Map<String, dynamic>?) ?? {},
          requestedAt: DateTime.now(),
        ));
        break;
    }
    notifyListeners();
  }

  void _updateSession(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final existing = _sessions[id];
    if (existing != null) {
      existing.title = data['title'] as String? ?? existing.title;
      existing.status = _parseStatus(data['status'] as String?);
      existing.mode = _parseMode(data['mode'] as String?);
      existing.lastActivity = DateTime.now();
    } else {
      _sessions[id] = AgentSession(
        id: id,
        title: data['title'] as String? ?? 'Session',
        status: _parseStatus(data['status'] as String?),
        mode: _parseMode(data['mode'] as String?),
      );
    }
  }

  // ── 手机端操作 ──────────────────────────────────────────────────────────────

  void sendPrompt(String sessionId, String text) {
    _send({'type': 'send_prompt', 'sessionId': sessionId, 'text': text});
    final session = _sessions[sessionId];
    if (session != null) {
      session.status = SessionStatus.running;
      session.output.add('> $text');
      session.lastActivity = DateTime.now();
      notifyListeners();
    }
  }

  void approvePermission(String sessionId, String permissionId) {
    _send({
      'type': 'permission_response',
      'sessionId': sessionId,
      'permissionId': permissionId,
      'approved': true,
    });
    _removePermission(sessionId, permissionId);
  }

  void denyPermission(String sessionId, String permissionId) {
    _send({
      'type': 'permission_response',
      'sessionId': sessionId,
      'permissionId': permissionId,
      'approved': false,
    });
    _removePermission(sessionId, permissionId);
  }

  void approveAll() {
    for (final session in _sessions.values) {
      for (final perm in List.from(session.pendingPermissions)) {
        approvePermission(session.id, perm.id);
      }
    }
  }

  void setMode(String sessionId, ExecutionMode mode) {
    _send({
      'type': 'set_mode',
      'sessionId': sessionId,
      'mode': mode.name,
    });
    _sessions[sessionId]?.mode = mode;
    notifyListeners();
  }

  void newSession() {
    _send({'type': 'new_session'});
  }

  void abortSession(String sessionId) {
    _send({'type': 'abort_session', 'sessionId': sessionId});
    _sessions[sessionId]?.status = SessionStatus.idle;
    notifyListeners();
  }

  void _removePermission(String sessionId, String permissionId) {
    _sessions[sessionId]?.pendingPermissions
        .removeWhere((p) => p.id == permissionId);
    // 如果没有更多待审批，恢复 running 状态
    final session = _sessions[sessionId];
    if (session != null && session.pendingPermissions.isEmpty) {
      session.status = SessionStatus.running;
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(msg));
      } catch (e) {
        debugPrint('PunkService send error: $e');
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('PunkService WS error: $error');
    _connected = false;
    _cliStatus = CliStatus.offline;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    _connected = false;
    _cliStatus = CliStatus.offline;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnect);
  }

  Future<void> _persistConfig(String url, String token, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('punk_relay_url', url);
    await prefs.setString('punk_token', token);
    await prefs.setString('punk_device_id', deviceId);
  }

  SessionStatus _parseStatus(String? s) {
    switch (s) {
      case 'running': return SessionStatus.running;
      case 'waiting': return SessionStatus.waiting;
      default: return SessionStatus.idle;
    }
  }

  ExecutionMode _parseMode(String? m) {
    switch (m) {
      case 'plan': return ExecutionMode.plan;
      case 'auto': return ExecutionMode.auto;
      case 'dangerous': return ExecutionMode.dangerous;
      default: return ExecutionMode.ask;
    }
  }

  bool get isConfigured => _token != null;

  @override
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
