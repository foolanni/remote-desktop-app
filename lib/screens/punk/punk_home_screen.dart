import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/punk/punk_service.dart';
import 'punk_session_screen.dart';
import 'punk_permissions_screen.dart';
import 'punk_setup_screen.dart';

class PunkHomeScreen extends StatefulWidget {
  const PunkHomeScreen({super.key});

  @override
  State<PunkHomeScreen> createState() => _PunkHomeScreenState();
}

class _PunkHomeScreenState extends State<PunkHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // 启动时尝试连接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PunkService>().loadAndConnect();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PunkService>(
      builder: (context, punk, _) {
        if (!punk.isConfigured) {
          return const PunkSetupScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          appBar: _buildAppBar(punk),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildSessionsTab(punk),
              PunkPermissionsScreen(punk: punk),
              _buildSettingsTab(punk),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(punk),
        );
      },
    );
  }

  AppBar _buildAppBar(PunkService punk) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      title: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('PUNK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 2,
              )),
          const SizedBox(width: 12),
          _buildStatusBadge(punk),
        ],
      ),
      actions: [
        if (punk.cliStatus == CliStatus.online)
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => punk.newSession(),
            tooltip: '新建会话',
          ),
      ],
    );
  }

  Widget _buildStatusBadge(PunkService punk) {
    final isOnline = punk.cliStatus == CliStatus.online;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOnline
            ? const Color(0xFF00FF88).withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? const Color(0xFF00FF88) : Colors.red,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF00FF88) : Colors.red,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? '在线' : '离线',
            style: TextStyle(
              color: isOnline ? const Color(0xFF00FF88) : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(PunkService punk) {
    if (punk.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💻', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              '没有活跃的会话',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              punk.cliStatus == CliStatus.online
                  ? '点击右上角 + 新建会话'
                  : '等待本地 Claude Code 连接...',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            if (punk.cliStatus == CliStatus.offline) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('本地运行 CLI：',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 6),
                    const SelectableText(
                      'npm i -g @punkcode/cli\npunk connect',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: punk.sessions.length,
      itemBuilder: (_, i) => _buildSessionCard(punk.sessions[i], punk),
    );
  }

  Widget _buildSessionCard(AgentSession session, PunkService punk) {
    final statusColor = session.status == SessionStatus.running
        ? const Color(0xFF00FF88)
        : session.status == SessionStatus.waiting
            ? Colors.orange
            : Colors.white38;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PunkSessionScreen(session: session, punk: punk),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: session.pendingPermissions.isNotEmpty
                ? Colors.orange.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (session.pendingPermissions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: Text(
                      '${session.pendingPermissions.length} 待审批',
                      style: const TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 最近输出预览
            if (session.output.isNotEmpty)
              Text(
                session.output.last.trim(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            // 模式选择
            Row(
              children: ExecutionMode.values.map((mode) {
                final isSelected = session.mode == mode;
                return GestureDetector(
                  onTap: () => punk.setMode(session.id, mode),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _modeColor(mode).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? _modeColor(mode)
                            : Colors.white12,
                        width: isSelected ? 1 : 0.5,
                      ),
                    ),
                    child: Text(
                      _modeLabel(mode),
                      style: TextStyle(
                        color: isSelected ? _modeColor(mode) : Colors.white38,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(PunkService punk) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _settingsTile('设备 ID', punk.deviceId ?? '-', Icons.devices),
        _settingsTile('中继服务器', '已连接', Icons.cloud_outlined),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PunkSetupScreen()),
            ),
            icon: const Icon(Icons.link),
            label: const Text('重新配对'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav(PunkService punk) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0A0A0F),
      selectedItemColor: const Color(0xFF00FF88),
      unselectedItemColor: Colors.white38,
      currentIndex: _tabCtrl.index,
      onTap: (i) => setState(() => _tabCtrl.animateTo(i)),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.terminal),
          label: '会话',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: punk.totalPendingCount > 0,
            label: Text('${punk.totalPendingCount}'),
            child: const Icon(Icons.approval_outlined),
          ),
          label: '审批',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: '设置',
        ),
      ],
    );
  }

  Color _modeColor(ExecutionMode mode) {
    switch (mode) {
      case ExecutionMode.plan: return Colors.blue;
      case ExecutionMode.ask: return Colors.white70;
      case ExecutionMode.auto: return const Color(0xFF00FF88);
      case ExecutionMode.dangerous: return Colors.red;
    }
  }

  String _modeLabel(ExecutionMode mode) {
    switch (mode) {
      case ExecutionMode.plan: return 'Plan';
      case ExecutionMode.ask: return 'Ask';
      case ExecutionMode.auto: return 'Auto';
      case ExecutionMode.dangerous: return '⚡ YOLO';
    }
  }
}
