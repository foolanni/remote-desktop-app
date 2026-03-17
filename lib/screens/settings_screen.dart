import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = true;
  bool _keepScreenOn = true;
  String _quality = '高质量';
  double _touchSensitivity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          _sectionHeader('安全'),
          SwitchListTile(
            title: const Text('生物认证'),
            subtitle: const Text('使用指纹 / Face ID 解锁'),
            secondary: const Icon(Icons.fingerprint),
            value: _biometricEnabled,
            onChanged: (v) => setState(() => _biometricEnabled = v),
          ),
          _sectionHeader('显示'),
          SwitchListTile(
            title: const Text('保持屏幕常亮'),
            subtitle: const Text('连接时屏幕不自动熄灭'),
            secondary: const Icon(Icons.brightness_high_outlined),
            value: _keepScreenOn,
            onChanged: (v) => setState(() => _keepScreenOn = v),
          ),
          ListTile(
            leading: const Icon(Icons.hd_outlined),
            title: const Text('画质'),
            subtitle: Text(_quality),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(),
          ),
          _sectionHeader('控制'),
          ListTile(
            leading: const Icon(Icons.touch_app_outlined),
            title: const Text('触控灵敏度'),
            subtitle: Slider(
              value: _touchSensitivity,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: _touchSensitivity.toStringAsFixed(1),
              onChanged: (v) => setState(() => _touchSensitivity = v),
            ),
          ),
          _sectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('开源许可'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['低质量', '中等质量', '高质量', '原始质量'].map((q) {
          return ListTile(
            title: Text(q),
            leading: _quality == q
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : const SizedBox(width: 24),
            onTap: () {
              setState(() => _quality = q);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
