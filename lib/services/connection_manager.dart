import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/remote_host.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionManager extends ChangeNotifier {
  List<RemoteHost> _hosts = [];
  RemoteHost? _activeHost;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;

  List<RemoteHost> get hosts => List.unmodifiable(_hosts);
  RemoteHost? get activeHost => _activeHost;
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  ConnectionManager() {
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('hosts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _hosts = list.map((e) => RemoteHost.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveHosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hosts', jsonEncode(_hosts.map((h) => h.toJson()).toList()));
  }

  void addHost(RemoteHost host) {
    _hosts.add(host);
    _saveHosts();
    notifyListeners();
  }

  void updateHost(RemoteHost host) {
    final idx = _hosts.indexWhere((h) => h.id == host.id);
    if (idx >= 0) {
      _hosts[idx] = host;
      _saveHosts();
      notifyListeners();
    }
  }

  void removeHost(String id) {
    _hosts.removeWhere((h) => h.id == id);
    _saveHosts();
    notifyListeners();
  }

  Future<void> connect(RemoteHost host) async {
    _activeHost = host;
    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: 根据协议实现实际连接逻辑
      // VNC: 使用 flutter_vnc
      // RDP: 使用 freerdp 或 WebSocket 代理
      // SSH: 使用 dartssh2
      await Future.delayed(const Duration(seconds: 1)); // 模拟连接

      _status = ConnectionStatus.connected;

      // 更新最后连接时间
      final updatedHost = host.copyWith(lastConnected: DateTime.now());
      updateHost(updatedHost);
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnected;
    _activeHost = null;
    notifyListeners();
  }
}
