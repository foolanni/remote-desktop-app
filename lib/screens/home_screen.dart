import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/remote_host.dart';
import '../services/connection_manager.dart';
import '../widgets/host_card.dart';
import 'connect_screen.dart';
import 'remote/remote_desktop_screen.dart';
import 'remote/ssh_terminal_screen.dart';
import 'remote/file_transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程桌面'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.computer_outlined), text: '我的连接'),
            Tab(icon: Icon(Icons.history), text: '最近使用'),
          ],
        ),
      ),
      body: Consumer<ConnectionManager>(
        builder: (context, manager, _) {
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildHostList(context, manager),
              _buildRecentList(context, manager),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/connect'),
        icon: const Icon(Icons.add),
        label: const Text('添加连接'),
      ),
    );
  }

  Widget _buildHostList(BuildContext context, ConnectionManager manager) {
    if (manager.hosts.isEmpty) {
      return _buildEmptyState(context);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: manager.hosts.length,
      itemBuilder: (context, index) {
        final host = manager.hosts[index];
        return HostCard(
          host: host,
          onConnect: () => _launchConnection(context, host),
          onDelete: () => manager.removeHost(host.id),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConnectScreen(existingHost: host),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentList(BuildContext context, ConnectionManager manager) {
    final recent = manager.recentHosts;
    if (recent.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('还没有连接记录', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recent.length,
      itemBuilder: (_, i) {
        final host = recent[i];
        return HostCard(
          host: host,
          onConnect: () => _launchConnection(context, host),
          onDelete: () => manager.removeHost(host.id),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ConnectScreen(existingHost: host)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer_outlined, size: 80,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('还没有远程连接',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 8),
          Text('点击下方按钮添加第一台远程电脑',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/connect'),
            icon: const Icon(Icons.add),
            label: const Text('添加连接'),
          ),
        ],
      ),
    );
  }

  void _launchConnection(BuildContext context, RemoteHost host) {
    // 根据协议打开不同界面
    if (host.protocol == 'SSH') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SshTerminalScreen(host: host)));
    } else {
      // VNC / RDP
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.desktop_windows_outlined),
                title: const Text('远程桌面'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RemoteDesktopScreen(host: host),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('文件传输'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FileTransferScreen(host: host),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: const Text('SSH 终端'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SshTerminalScreen(host: host),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // 记录历史
    context.read<ConnectionManager>().recordAccess(host.id);
  }
}
