import 'package:flutter/material.dart';
import '../../services/punk/punk_service.dart';

/// Claude Code 会话详情页 - 输出查看 + 发送指令
class PunkSessionScreen extends StatefulWidget {
  final AgentSession session;
  final PunkService punk;

  const PunkSessionScreen({
    super.key,
    required this.session,
    required this.punk,
  });

  @override
  State<PunkSessionScreen> createState() => _PunkSessionScreenState();
}

class _PunkSessionScreenState extends State<PunkSessionScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isVoiceMode = false;

  @override
  void initState() {
    super.initState();
    widget.punk.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.punk.removeListener(_onUpdate);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.punk.sessions
        .firstWhere((s) => s.id == widget.session.id, orElse: () => widget.session);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Row(
              children: [
                _statusDot(session.status),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(session.status),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (session.status == SessionStatus.running)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
              onPressed: () => widget.punk.abortSession(session.id),
              tooltip: '中止',
            ),
        ],
      ),
      body: Column(
        children: [
          // 待审批权限横幅
          if (session.pendingPermissions.isNotEmpty)
            _buildPermissionBanner(session),

          // 输出区域
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: session.output.length,
              itemBuilder: (_, i) => _buildOutputLine(session.output[i]),
            ),
          ),

          // 输入区
          _buildInputBar(session),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(AgentSession session) {
    final perm = session.pendingPermissions.first;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PunkPermissionsScreen(punk: widget.punk),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '等待权限审批: ${perm.tool}',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    perm.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _quickActionBtn('✓', Colors.green, () {
                  widget.punk.approvePermission(session.id, perm.id);
                }),
                const SizedBox(width: 6),
                _quickActionBtn('✗', Colors.red, () {
                  widget.punk.denyPermission(session.id, perm.id);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildOutputLine(String line) {
    Color color = Colors.white70;
    if (line.startsWith('>')) color = const Color(0xFF00FF88);
    if (line.startsWith('Error') || line.startsWith('✗')) color = Colors.redAccent;
    if (line.startsWith('✓') || line.startsWith('Done')) color = const Color(0xFF00FF88);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        line,
        style: TextStyle(
          color: color,
          fontFamily: 'Courier New',
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildInputBar(AgentSession session) {
    return Container(
      color: const Color(0xFF111118),
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '告诉 Claude 做什么...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendPrompt,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 语音按钮
          GestureDetector(
            onTap: () => setState(() => _isVoiceMode = !_isVoiceMode),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isVoiceMode
                    ? const Color(0xFF00FF88).withOpacity(0.15)
                    : const Color(0xFF1A1A24),
                border: Border.all(
                  color: _isVoiceMode ? const Color(0xFF00FF88) : Colors.white12,
                ),
              ),
              child: Icon(
                _isVoiceMode ? Icons.mic : Icons.mic_none_outlined,
                color: _isVoiceMode ? const Color(0xFF00FF88) : Colors.white38,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          GestureDetector(
            onTap: () => _sendPrompt(_inputCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FF88).withOpacity(0.15),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Color(0xFF00FF88),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendPrompt(String text) {
    if (text.trim().isEmpty) return;
    widget.punk.sendPrompt(widget.session.id, text.trim());
    _inputCtrl.clear();
  }

  Widget _statusDot(SessionStatus status) {
    final color = status == SessionStatus.running
        ? const Color(0xFF00FF88)
        : status == SessionStatus.waiting
            ? Colors.orange
            : Colors.white24;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  String _statusLabel(SessionStatus status) {
    switch (status) {
      case SessionStatus.running: return '运行中';
      case SessionStatus.waiting: return '等待审批';
      case SessionStatus.idle: return '空闲';
    }
  }
}

// 权限审批列表页
class PunkPermissionsScreen extends StatelessWidget {
  final PunkService punk;

  const PunkPermissionsScreen({super.key, required this.punk});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: punk,
      builder: (context, _) {
        final permissions = punk.allPendingPermissions;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0A0F),
            foregroundColor: Colors.white,
            title: Text(
              '待审批权限 (${permissions.length})',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              if (permissions.isNotEmpty)
                TextButton(
                  onPressed: punk.approveAll,
                  child: const Text('全部批准',
                      style: TextStyle(color: Color(0xFF00FF88))),
                ),
            ],
          ),
          body: permissions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✅', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('没有待审批的权限',
                          style: TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: permissions.length,
                  itemBuilder: (_, i) =>
                      _buildPermissionCard(context, permissions[i]),
                ),
        );
      },
    );
  }

  Widget _buildPermissionCard(BuildContext context, PermissionRequest perm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        perm.tool,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(perm.requestedAt),
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  perm.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (perm.args.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      perm.args.toString(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => punk.denyPermission(perm.sessionId, perm.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A1A1A),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, color: Colors.red, size: 16),
                        SizedBox(width: 6),
                        Text('拒绝',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => punk.approvePermission(perm.sessionId, perm.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A2A1A),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, color: Color(0xFF00FF88), size: 16),
                        SizedBox(width: 6),
                        Text('批准',
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }
}
