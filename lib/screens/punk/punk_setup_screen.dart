import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/punk/punk_service.dart';

/// PUNK 配对设置页
class PunkSetupScreen extends StatefulWidget {
  const PunkSetupScreen({super.key});

  @override
  State<PunkSetupScreen> createState() => _PunkSetupScreenState();
}

class _PunkSetupScreenState extends State<PunkSetupScreen> {
  final _pairCodeCtrl = TextEditingController();
  final _relayUrlCtrl = TextEditingController(text: 'ws://localhost:3001');
  bool _isLoading = false;
  String? _error;
  int _step = 0; // 0=选择方式 1=输入配对码 2=配对成功

  @override
  void dispose() {
    _pairCodeCtrl.dispose();
    _relayUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo
              const Center(
                child: Column(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 8),
                    Text(
                      'PUNK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Remote control for Claude Code',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              if (_step == 0) _buildStep0(),
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '开始使用',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '在你的电脑上安装 PUNK CLI，然后扫描配对码连接',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),

        // 步骤说明
        _stepGuide('1', '在电脑上安装 CLI',
            'npm i -g @punkcode/cli'),
        const SizedBox(height: 12),
        _stepGuide('2', '运行连接命令',
            'punk connect'),
        const SizedBox(height: 12),
        _stepGuide('3', '输入电脑上显示的配对码', null),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '输入配对码',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: const Icon(Icons.arrow_back, color: Colors.white54),
            ),
            const SizedBox(width: 12),
            const Text(
              '输入配对码',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 配对码输入
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _pairCodeCtrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 24),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20),
              counterText: '',
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 中继服务器地址（高级）
        ExpansionTile(
          title: const Text('高级设置',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          iconColor: Colors.white38,
          collapsedIconColor: Colors.white38,
          children: [
            TextField(
              controller: _relayUrlCtrl,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              decoration: InputDecoration(
                labelText: '中继服务器地址',
                labelStyle: const TextStyle(color: Colors.white38),
                hintText: 'ws://your-server:3001',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1A1A24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
              ),
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _verifyPairCode,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                : const Text('配对',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return const Column(
      children: [
        Center(
          child: Column(
            children: [
              Text('✅', style: TextStyle(fontSize: 64)),
              SizedBox(height: 16),
              Text('配对成功！',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('正在连接到你的电脑...',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _verifyPairCode() async {
    final code = _pairCodeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = '请输入6位配对码');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final relayUrl = _relayUrlCtrl.text.trim();
      final apiUrl = relayUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://');

      // 调用 /api/pair/verify
      final uri = Uri.parse('$apiUrl/api/pair/verify');
      final response = await Future.any([
        _postRequest(uri, {'pairCode': code}),
        Future.delayed(const Duration(seconds: 10),
            () => throw Exception('连接超时')),
      ]);

      setState(() => _step = 2);

      await context.read<PunkService>().connect(
        relayUrl,
        response['token'] as String,
        response['deviceId'] as String,
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '配对失败: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<Map<String, dynamic>> _postRequest(
      Uri uri, Map<String, dynamic> body) async {
    final client = HttpOverride();
    return await client.post(uri, body);
  }

  Widget _stepGuide(String num, String title, String? code) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00FF88).withOpacity(0.15),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
          ),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              if (code != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// 简单 HTTP 辅助
class HttpOverride {
  Future<Map<String, dynamic>> post(Uri uri, Map<String, dynamic> body) async {
    // 使用 dart:io HttpClient
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write('{"pairCode":"${body['pairCode']}"}');
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
