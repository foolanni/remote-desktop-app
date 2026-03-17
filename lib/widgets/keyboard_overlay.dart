import 'package:flutter/material.dart';

class KeyboardOverlay extends StatelessWidget {
  final void Function(String key, {bool ctrl, bool alt}) onKeyPress;
  final VoidCallback onClose;

  const KeyboardOverlay({
    super.key,
    required this.onKeyPress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE6212121),
      padding: const EdgeInsets.all(8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 关闭行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('虚拟键盘', style: TextStyle(color: Colors.white70, fontSize: 12)),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 功能键行
            _buildKeyRow([
              _Key('Esc', 'escape'),
              _Key('F1', 'f1'), _Key('F2', 'f2'), _Key('F3', 'f3'),
              _Key('F4', 'f4'), _Key('F5', 'f5'), _Key('F6', 'f6'),
              _Key('F7', 'f7'), _Key('F8', 'f8'),
            ]),
            const SizedBox(height: 6),

            // 方向键行
            _buildKeyRow([
              _Key('↑', 'up'), _Key('↓', 'down'),
              _Key('←', 'left'), _Key('→', 'right'),
              _Key('Tab', 'tab'), _Key('Enter', 'enter'),
              _Key('Del', 'delete'), _Key('Back', 'backspace'),
            ]),
            const SizedBox(height: 6),

            // 修饰键 + 常用
            _buildKeyRow([
              _Key('Ctrl+C', 'c', ctrl: true),
              _Key('Ctrl+V', 'v', ctrl: true),
              _Key('Ctrl+Z', 'z', ctrl: true),
              _Key('Ctrl+A', 'a', ctrl: true),
              _Key('Ctrl+S', 's', ctrl: true),
              _Key('Win', 'super'),
              _Key('Alt+F4', 'f4', alt: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<_Key> keys) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final k = keys[i];
          return _buildKey(k);
        },
      ),
    );
  }

  Widget _buildKey(_Key k) {
    return GestureDetector(
      onTap: () => onKeyPress(k.key, ctrl: k.ctrl, alt: k.alt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF424242),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          k.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _Key {
  final String label;
  final String key;
  final bool ctrl;
  final bool alt;

  const _Key(this.label, this.key, {this.ctrl = false, this.alt = false});
}
