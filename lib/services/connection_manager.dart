import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/remote_host.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionManager extends ChangeNotifier {
  List<RemoteHost> _hosts = [];
  List<String> _recentIds = []; // 最近访问顺序（id列表）
  RemoteHost? _activeHost;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;

  List<RemoteHost> get hosts => List.unmodifiable(_hosts);
  RemoteHost? get activeHost => _activeHost;
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 最近使用（按时间倒序，最多10条）
  List<RemoteHost> get recentHosts {
    return _recentIds
        .map((id) => _hosts.where((h) => h.id == id).firstOrNull)
        .whereType<RemoteHost>()
        .toList();
  }

  ConnectionManager() {
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('hosts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _hosts = list.map((e) => RemoteHost.fromJson(e)).toList();
    }
    final recent = prefs.getStringList('recent_ids');
    if (recent != null) _recentIds = recent;
    notifyListeners();
  }

  Future<void> _saveHosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hosts', jsonEncode(_hosts.map((h) => h.toJson()).toList()));
    await prefs.setStringList('recent_ids', _recentIds);
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
    _recentIds.remove(id);
    _saveHosts();
    notifyListeners();
  }

  /// 记录访问历史
  void recordAccess(String hostId) {
    _recentIds.remove(hostId);
    _recentIds.insert(0, hostId);
    if (_recentIds.length > 10) _recentIds = _recentIds.sublist(0, 10);

    // 更新 lastConnected
    final idx = _hosts.indexWhere((h) => h.id == hostId);
    if (idx >= 0) {
      _hosts[idx] = _hosts[idx].copyWith(lastConnected: DateTime.now());
    }
    _saveHosts();
    notifyListeners();
  }

  Future<void> connect(RemoteHost host) async {
    _activeHost = host;
    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      _status = ConnectionStatus.connected;
      recordAccess(host.id);
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
