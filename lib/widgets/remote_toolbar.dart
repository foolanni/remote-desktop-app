import 'package:flutter/material.dart';

class RemoteToolbar extends StatelessWidget {
  final String hostName;
  final bool isConnected;
  final String statusMsg;
  final VoidCallback onDisconnect;
  final VoidCallback onKeyboard;
  final VoidCallback onSendCtrlAltDel;
  final VoidCallback onScreenshot;
  final VoidCallback onFitScreen;

  const RemoteToolbar({
    super.key,
    required this.hostName,
    required this.isConnected,
    required this.statusMsg,
    required this.onDisconnect,
    required this.onKeyboard,
    required this.onSendCtrlAltDel,
    required this.onScreenshot,
    required this.onFitScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.black.withOpacity(0)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onDisconnect,
                tooltip: '断开连接',
              ),

              // 主机名 + 状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hostName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? Colors.greenAccent : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusMsg,
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 工具按钮
              _toolBtn(Icons.fit_screen, '适应屏幕', onFitScreen),
              _toolBtn(Icons.keyboard_outlined, '键盘', onKeyboard),
              _toolBtn(Icons.camera_alt_outlined, '截图', onScreenshot),

              // 更多菜单
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) {
                  if (v == 'ctrlaltdel') onSendCtrlAltDel();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'ctrlaltdel',
                    child: ListTile(
                      leading: Icon(Icons.keyboard_command_key),
                      title: Text('发送 Ctrl+Alt+Del'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onTap,
      tooltip: tip,
      iconSize: 22,
    );
  }
}
