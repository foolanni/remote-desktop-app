# 远程桌面应用 (Remote Desktop App)

跨平台远程桌面应用，支持 **iOS** 和 **Android**，基于 Flutter 开发。

## ✨ 功能特性

- 🖥️ **多协议支持**：VNC、RDP、SSH
- 📱 **跨平台**：iOS + Android 一套代码
- 🔒 **安全认证**：密码加密存储 + 生物识别（指纹/Face ID）
- 🎨 **现代 UI**：Material Design 3，支持深色模式
- 📋 **连接管理**：添加/编辑/删除远程主机
- ⚡ **快速连接**：一键连接常用主机

## 📁 项目结构

```
lib/
├── main.dart                 # 入口文件
├── screens/
│   ├── home_screen.dart      # 主页（连接列表）
│   ├── connect_screen.dart   # 新建/编辑连接
│   └── settings_screen.dart  # 设置页面
├── widgets/
│   └── host_card.dart        # 主机卡片组件
├── models/
│   └── remote_host.dart      # 数据模型
└── services/
    ├── connection_manager.dart  # 连接状态管理
    └── auth_service.dart        # 认证服务
```

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Xcode 14+ (iOS)
- Android Studio (Android)

### 安装依赖
```bash
flutter pub get
```

### 运行
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

### 构建发布版
```bash
# iOS
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

## 🔧 技术栈

| 功能 | 依赖 |
|------|------|
| 状态管理 | provider |
| VNC 协议 | flutter_vnc |
| SSH 协议 | dartssh2 |
| 安全存储 | flutter_secure_storage |
| 生物认证 | local_auth |
| 本地存储 | shared_preferences |

## 📋 开发路线图

- [x] 项目架构搭建
- [x] 连接管理界面
- [x] 添加/编辑连接
- [x] 设置页面
- [ ] VNC 远程桌面视图
- [ ] RDP 连接实现
- [ ] SSH 终端
- [ ] 手势控制（鼠标/键盘）
- [ ] 剪贴板同步
- [ ] 文件传输
- [ ] 连接历史记录
- [ ] iPad/平板优化布局

## 📄 License

MIT License
<!-- build trigger: Wed Mar 18 01:38:25 PM CST 2026 -->
<!-- build trigger: Wed Mar 18 01:50:33 PM CST 2026 -->
