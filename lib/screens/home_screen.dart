import 'package:flutter/material.dart';
import '../models/remote_host.dart';
import '../services/connection_manager.dart';
import '../widgets/host_card.dart';
import 'connect_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      ),
      body: Consumer<ConnectionManager>(
        builder: (context, manager, _) {
          if (manager.hosts.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildHostList(context, manager);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/connect'),
        icon: const Icon(Icons.add),
        label: const Text('添加连接'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.computer_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有远程连接',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加第一台远程电脑',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
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

  Widget _buildHostList(BuildContext context, ConnectionManager manager) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: manager.hosts.length,
      itemBuilder: (context, index) {
        final host = manager.hosts[index];
        return HostCard(
          host: host,
          onConnect: () => manager.connect(host),
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
}
