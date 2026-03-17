import 'package:flutter/material.dart';
import '../models/remote_host.dart';
import '../services/connection_manager.dart';
import 'package:provider/provider.dart';

class ConnectScreen extends StatefulWidget {
  final RemoteHost? existingHost;
  const ConnectScreen({super.key, this.existingHost});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5900');
  final _passwordCtrl = TextEditingController();
  String _protocol = 'VNC';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingHost != null) {
      final h = widget.existingHost!;
      _nameCtrl.text = h.name;
      _hostCtrl.text = h.host;
      _portCtrl.text = h.port.toString();
      _protocol = h.protocol;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingHost != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑连接' : '新建连接'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('基本信息'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '连接名称',
                  hintText: '例如：家里的 Mac',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? '请填写名称' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostCtrl,
                decoration: const InputDecoration(
                  labelText: '主机地址',
                  hintText: '192.168.1.100 或 example.com',
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? '请填写主机地址' : null,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _protocol,
                      decoration: const InputDecoration(
                        labelText: '协议',
                        border: OutlineInputBorder(),
                      ),
                      items: ['VNC', 'RDP', 'SSH']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _protocol = v!;
                          _portCtrl.text = v == 'VNC'
                              ? '5900'
                              : v == 'RDP'
                                  ? '3389'
                                  : '22';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final port = int.tryParse(v ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '无效端口';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionLabel('认证'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(isEdit ? Icons.save_outlined : Icons.link),
                  label: Text(isEdit ? '保存' : '连接'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final manager = context.read<ConnectionManager>();
    final host = RemoteHost(
      id: widget.existingHost?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text),
      protocol: _protocol,
      password: _passwordCtrl.text,
    );
    if (widget.existingHost != null) {
      manager.updateHost(host);
    } else {
      manager.addHost(host);
    }
    Navigator.pop(context);
  }
}
