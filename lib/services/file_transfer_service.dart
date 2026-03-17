import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/remote_host.dart';

class RemoteFile {
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final String permissions;

  const RemoteFile({
    required this.name,
    required this.isDirectory,
    this.size = 0,
    required this.modified,
    this.permissions = '-rw-r--r--',
  });
}

class TransferTask {
  final String fileName;
  final bool isUpload;
  final int totalSize;
  int transferred;
  bool isCompleted;
  bool hasError;

  TransferTask({
    required this.fileName,
    required this.isUpload,
    required this.totalSize,
    this.transferred = 0,
    this.isCompleted = false,
    this.hasError = false,
  });

  double get progress => totalSize > 0 ? transferred / totalSize : 0;

  String get statusLabel {
    if (hasError) return '失败';
    if (isCompleted) return '完成';
    if (transferred > 0) return '传输中';
    return '等待中';
  }
}

/// 文件传输服务，基于 SFTP (SSH) 协议
class FileTransferService {
  final RemoteHost host;

  FileTransferService({required this.host});

  Future<List<RemoteFile>> listDirectory(String path) async {
    // TODO: 使用 dartssh2 的 SFTP 实现
    // final sftp = await _client.sftp();
    // final dir = await sftp.opendir(path);
    // final entries = await dir.readdir();
    // return entries.map((e) => RemoteFile(
    //   name: e.filename,
    //   isDirectory: e.attr.type == SftpFileType.directory,
    //   size: e.attr.size ?? 0,
    //   modified: DateTime.fromMillisecondsSinceEpoch((e.attr.mtime ?? 0) * 1000),
    // )).toList();

    // 模拟数据
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      RemoteFile(name: 'Documents', isDirectory: true, modified: DateTime.now()),
      RemoteFile(name: 'Downloads', isDirectory: true, modified: DateTime.now()),
      RemoteFile(name: '.bashrc', isDirectory: false, size: 3526, modified: DateTime.now()),
      RemoteFile(name: 'readme.txt', isDirectory: false, size: 1024, modified: DateTime.now()),
      RemoteFile(name: 'app.log', isDirectory: false, size: 204800, modified: DateTime.now()),
    ];
  }

  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    // TODO: 实现 SFTP 上传
    // final sftp = await _client.sftp();
    // final file = await sftp.open(remotePath, mode: SftpFileOpenMode.create | SftpFileOpenMode.write);
    // final localFile = File(localPath);
    // final total = await localFile.length();
    // int sent = 0;
    // await for (final chunk in localFile.openRead()) {
    //   await file.write(Stream.value(Uint8List.fromList(chunk)));
    //   sent += chunk.length;
    //   onProgress?.call(sent, total);
    // }
    debugPrint('Upload: $localPath → $remotePath');
  }

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    // TODO: 实现 SFTP 下载
    debugPrint('Download: $remotePath → $localPath');
  }

  Future<void> deleteFile(String remotePath) async {
    // TODO: sftp.remove(remotePath)
    debugPrint('Delete: $remotePath');
  }

  Future<void> createDirectory(String remotePath) async {
    // TODO: sftp.mkdir(remotePath)
    debugPrint('Mkdir: $remotePath');
  }
}
