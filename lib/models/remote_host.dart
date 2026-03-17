class RemoteHost {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final String? username;
  final String? password;
  final bool savePassword;
  final DateTime? lastConnected;

  const RemoteHost({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.username,
    this.password,
    this.savePassword = true,
    this.lastConnected,
  });

  String get address => '$host:$port';

  String get protocolIcon {
    switch (protocol) {
      case 'VNC':
        return '🖥️';
      case 'RDP':
        return '🪟';
      case 'SSH':
        return '🔒';
      default:
        return '💻';
    }
  }

  RemoteHost copyWith({
    String? name,
    String? host,
    int? port,
    String? protocol,
    String? username,
    String? password,
    DateTime? lastConnected,
  }) {
    return RemoteHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      username: username ?? this.username,
      password: password ?? this.password,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'protocol': protocol,
        'username': username,
        'savePassword': savePassword,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory RemoteHost.fromJson(Map<String, dynamic> json) => RemoteHost(
        id: json['id'],
        name: json['name'],
        host: json['host'],
        port: json['port'],
        protocol: json['protocol'],
        username: json['username'],
        savePassword: json['savePassword'] ?? true,
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'])
            : null,
      );
}
