class Connection {
  final int? id;
  final String? name;
  final String host;
  final int sendPort;
  final int rcvPort;
  final DateTime? lastUsed;

  const Connection({
    this.id,
    this.name,
    required this.host,
    required this.sendPort,
    required this.rcvPort,
    this.lastUsed,
  });

  Connection copyWith({
    int? id,
    String? name,
    String? host,
    int? sendPort,
    int? rcvPort,
    DateTime? lastUsed,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      sendPort: sendPort ?? this.sendPort,
      rcvPort: rcvPort ?? this.rcvPort,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  bool isSame(Connection oth) {
    return oth.host == host &&
        oth.sendPort == sendPort &&
        oth.rcvPort == rcvPort;
  }

  String connectionDesc() {
    return "$host\u2191$sendPort\u2193$rcvPort";
  }
}
