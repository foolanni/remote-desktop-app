import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/remote_host.dart';
import '../../services/file_transfer_service.dart';

class FileTransferScreen extends StatefulWidget {
  final RemoteHost host;
  const FileTransferScreen({super.key, required this.host});

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late FileTransferService _service;
  List<RemoteFile> _remoteFiles = [];
  String _remotePath = '/home';
  bool _loading = false;
  List<TransferTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _service = FileTransferService(host: widget.host);
    _loadRemoteDir(_remotePath);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteDir(String path) async {
    setState(() => _loading = true);
    try {
      final files = await _service.listDirectory(path);
      setState(() {
        _remoteFiles = files;
        _remotePath = path;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('加载目录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('文件传输 - ${widget.host.name}'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined), text: '远程文件'),
            Tab(icon: Icon(Icons.swap_horiz), text: '传输队列'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildRemoteFileList(),
          _buildTransferQueue(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadFile,
        icon: const Icon(Icons.upload_outlined),
        label: const Text('上传文件'),
      ),
    );
  }

  Widget _buildRemoteFileList() {
    return Column(
      children: [
        // 路径导航
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: _remotePath != '/'
                    ? () {
                        final parent = _remotePath.substring(
                            0, _remotePath.lastIndexOf('/'));
                        _loadRemoteDir(parent.isEmpty ? '/' : parent);
                      }
                    : null,
                tooltip: '返回上级',
              ),
              Expanded(
                child: Text(
                  _remotePath,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => _loadRemoteDir(_remotePath),
              ),
            ],
          ),
        ),

        // 文件列表
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _remoteFiles.isEmpty
                  ? const Center(child: Text('目录为空'))
                  : ListView.builder(
                      itemCount: _remoteFiles.length,
                      itemBuilder: (_, i) => _buildFileItem(_remoteFiles[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildFileItem(RemoteFile file) {
    return ListTile(
      leading: Icon(
        file.isDirectory ? Icons.folder : _fileIcon(file.name),
        color: file.isDirectory
            ? Colors.amber
            : Theme.of(context).colorScheme.secondary,
      ),
      title: Text(file.name),
      subtitle: file.isDirectory
          ? null
          : Text(_formatSize(file.size)),
      trailing: file.isDirectory
          ? const Icon(Icons.chevron_right)
          : PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'download') _downloadFile(file);
                if (v == 'delete') _deleteFile(file);
                if (v == 'copy_path') _copyPath(file);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'download', child: Text('下载')),
                const PopupMenuItem(value: 'copy_path', child: Text('复制路径')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
      onTap: file.isDirectory
          ? () => _loadRemoteDir('$_remotePath/${file.name}')
          : () => _downloadFile(file),
    );
  }

  Widget _buildTransferQueue() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('暂无传输任务', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tasks.length,
      itemBuilder: (_, i) => _buildTaskItem(_tasks[i]),
    );
  }

  Widget _buildTaskItem(TransferTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.isUpload ? Icons.upload : Icons.download,
                  size: 16,
                  color: task.isUpload ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: task.isCompleted ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.withOpacity(0.2),
            ),
            const SizedBox(height: 4),
            Text(
              '${(task.progress * 100).toInt()}% · ${_formatSize(task.transferred)} / ${_formatSize(task.totalSize)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile() async {
    // TODO: 使用 file_picker 选择本地文件
    // final result = await FilePicker.platform.pickFiles();
    // if (result == null) return;
    // final task = TransferTask(...);
    // setState(() => _tasks.add(task));
    // await _service.uploadFile(result.files.first.path!, '$_remotePath/${result.files.first.name}', onProgress: ...);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('选择文件上传（需接入 file_picker）')),
    );
  }

  Future<void> _downloadFile(RemoteFile file) async {
    final task = TransferTask(
      fileName: file.name,
      isUpload: false,
      totalSize: file.size,
    );
    setState(() => _tasks.add(task));
    _tabCtrl.animateTo(1);
    // TODO: await _service.downloadFile(...)
  }

  Future<void> _deleteFile(RemoteFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除 ${file.name}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteFile('$_remotePath/${file.name}');
      _loadRemoteDir(_remotePath);
    }
  }

  void _copyPath(RemoteFile file) {
    Clipboard.setData(ClipboardData(text: '$_remotePath/${file.name}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('路径已复制'), duration: Duration(seconds: 1)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': Icons.image_outlined, 'jpeg': Icons.image_outlined,
      'png': Icons.image_outlined, 'gif': Icons.image_outlined,
      'mp4': Icons.video_file_outlined, 'mov': Icons.video_file_outlined,
      'mp3': Icons.audio_file_outlined,
      'pdf': Icons.picture_as_pdf_outlined,
      'zip': Icons.archive_outlined, 'tar': Icons.archive_outlined,
      'sh': Icons.terminal, 'py': Icons.code, 'dart': Icons.code,
    };
    return map[ext] ?? Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }
}
