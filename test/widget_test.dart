import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remote_desktop_app/models/remote_host.dart';
import 'package:remote_desktop_app/services/connection_manager.dart';

void main() {
  // 每个测试前初始化 SharedPreferences mock
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteHost 模型测试', () {
    test('创建 RemoteHost', () {
      final host = RemoteHost(
        id: '1',
        name: '测试主机',
        host: '192.168.1.100',
        port: 5900,
        protocol: 'VNC',
      );
      expect(host.name, '测试主机');
      expect(host.address, '192.168.1.100:5900');
      expect(host.protocol, 'VNC');
    });

    test('JSON 序列化/反序列化', () {
      final host = RemoteHost(
        id: '1',
        name: '测试主机',
        host: '192.168.1.100',
        port: 5900,
        protocol: 'VNC',
      );
      final json = host.toJson();
      final restored = RemoteHost.fromJson(json);
      expect(restored.id, host.id);
      expect(restored.name, host.name);
      expect(restored.host, host.host);
      expect(restored.port, host.port);
    });

    test('copyWith 更新字段', () {
      final host = RemoteHost(
        id: '1',
        name: '原始名称',
        host: '192.168.1.100',
        port: 5900,
        protocol: 'VNC',
      );
      final updated = host.copyWith(name: '新名称', port: 3389);
      expect(updated.id, '1');
      expect(updated.name, '新名称');
      expect(updated.port, 3389);
    });
  });

  group('ConnectionManager 测试', () {
    test('初始状态', () {
      final manager = ConnectionManager();
      expect(manager.isConnected, false);
      expect(manager.activeHost, isNull);
    });

    test('添加主机', () async {
      final manager = ConnectionManager();
      // 等待初始化完成
      await Future.delayed(const Duration(milliseconds: 100));
      final host = RemoteHost(
        id: '1',
        name: '测试',
        host: '192.168.1.1',
        port: 5900,
        protocol: 'VNC',
      );
      manager.addHost(host);
      expect(manager.hosts.length, 1);
      expect(manager.hosts.first.name, '测试');
    });

    test('删除主机', () async {
      final manager = ConnectionManager();
      await Future.delayed(const Duration(milliseconds: 100));
      final host = RemoteHost(
        id: '1',
        name: '测试',
        host: '192.168.1.1',
        port: 5900,
        protocol: 'VNC',
      );
      manager.addHost(host);
      manager.removeHost('1');
      expect(manager.hosts, isEmpty);
    });
  });
}
