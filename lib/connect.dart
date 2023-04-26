import 'package:ardour_remote/remote.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

@immutable
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

  Connection.fromMap(Map<String, Object?> map)
      : id = map["id"] as int?,
        name = map["name"] as String?,
        host = (map["host"] as String?)!,
        sendPort = (map["send_port"] as int?)!,
        rcvPort = (map["rcv_port"] as int?)!,
        lastUsed = (map["last_used"] as int?).fromDb;

  bool isSame(Connection oth) {
    return oth.host == host &&
        oth.sendPort == sendPort &&
        oth.rcvPort == rcvPort;
  }

  String connectionDesc() {
    return "$host\u2191$sendPort\u2193$rcvPort";
  }
}

extension on DateTime? {
  int? get toDb => this?.millisecondsSinceEpoch;
}

extension on int? {
  DateTime? get fromDb {
    final val = this;
    return val != null ? DateTime.fromMillisecondsSinceEpoch(val) : null;
  }
}

class _ConnectionDb {
  final Database db;

  _ConnectionDb({required this.db});

  static Future<_ConnectionDb> load() async {
    var path = join(await getDatabasesPath(), "ardour_remote.db");
    var db = await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE connection (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            host TEXT NOT NULL,
            send_port INTEGER NOT NULL,
            rcv_port INTEGER NOT NULL,
            last_used INTEGER
          )
        ''');
      },
      version: 1,
    );

    return _ConnectionDb(db: db);
  }

  Future<List<Connection>> getAll() async {
    var connections = <Connection>[];
    var cursor = await db.rawQueryCursor('''
        SELECT id, name, host, send_port, rcv_port, last_used
        FROM connection
        ORDER BY last_used DESC NULLS LAST
      ''', null, bufferSize: 10);
    while (await cursor.moveNext()) {
      connections.add(Connection.fromMap(cursor.current));
    }
    return connections;
  }

  Future<Connection> insert(Connection c) async {
    final id = await db.rawInsert('''
      INSERT INTO connection (name, host, send_port, rcv_port, last_used)
      VALUES (?, ?, ?, ?, ?)
    ''', [c.name, c.host, c.sendPort, c.rcvPort, c.lastUsed.toDb]);
    return c.copyWith(id: id);
  }

  Future<int> deleteById(int id) async {
    return db.rawDelete('DELETE FROM connection WHERE id = ?', [id]);
  }

  Future<void> close() async {
    return db.close();
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  _ConnectionDb? db;
  var connections = <Connection>[];
  var requestNew = false;

  @override
  void initState() {
    super.initState();
    _ConnectionDb.load().then((db) async {
      var conns = await db.getAll();
      setState(() {
        this.db = db;
        connections = conns;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (db == null) {
      // TODO: manage DB error
      return const SizedBox.shrink();
    }
    if (requestNew || connections.isEmpty) {
      return ConnectNewPage(onConnect: (conn) async {
        final navigator = Navigator.of(context);
        final db = this.db;

        if (db != null) {
          conn = await db.insert(conn);
        }
        setState(() {
          connections.add(conn);
          requestNew = false;
        });
        navigator.push(MaterialPageRoute(
            builder: (context) => RemotePage(connection: conn)));
      });
    } else {
      return ConnectRecentPage(
        connections: connections,
        onRequestNew: () {
          setState(() {
            requestNew = true;
          });
        },
        onRemove: (final Connection conn) async {
          if (conn.id != null) {
            db?.deleteById(conn.id!);
          }
          setState(() {
            if (conn.id != null) {
              connections.removeWhere((c) => c.id == conn.id);
            } else {
              connections.removeWhere((c) => c.isSame(conn));
            }
          });
        },
        onConnect: (Connection c) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => RemotePage(connection: c)));
        },
      );
    }
  }

  Future<void> onConnect(Connection conn) async {}
}

typedef ConnCallback = void Function(Connection conn);

class ConnectNewPage extends StatefulWidget {
  const ConnectNewPage({super.key, required this.onConnect});

  final ConnCallback onConnect;

  @override
  State<ConnectNewPage> createState() => _ConnectNewPageState();
}

class _ConnectNewPageState extends State<ConnectNewPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final hostController = TextEditingController(text: "192.168.1.");
  final sendPortController = TextEditingController(text: "3819");
  final rcvPortController = TextEditingController(text: "8000");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ardour Remote - Connect to host")),
      body: Form(
          key: formKey,
          child: Column(
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "\u{1f4d3} Name (optional)",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: hostController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Provide Ardour station host name or address";
                  } else {
                    return null;
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "\u{1f4bb} Host or IP address",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: sendPortController,
                keyboardType: TextInputType.number,
                validator: validatePort,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "\u2191 Send Port",
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: rcvPortController,
                keyboardType: TextInputType.number,
                validator: validatePort,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "\u2193 Receive Port",
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sensors),
                  label: const Text("Connect"),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      widget.onConnect(Connection(
                        name: nameController.text.isNotEmpty
                            ? nameController.text
                            : null,
                        host: hostController.text,
                        sendPort: int.parse(sendPortController.text),
                        rcvPort: int.parse(rcvPortController.text),
                        lastUsed: DateTime.now(),
                      ));
                    }
                  },
                ),
              )
            ],
          )),
    );
  }
}

String? validatePort(String? portStr) {
  if (portStr == null || portStr.isEmpty) {
    return "Provide a valid port";
  }
  final port = int.tryParse(portStr);
  if (port == null || port < 1024 || port > 65353) {
    return "Provide a valid port";
  }
  return null;
}

class ConnectRecentPage extends StatelessWidget {
  const ConnectRecentPage({
    super.key,
    required this.connections,
    required this.onRequestNew,
    required this.onConnect,
    required this.onRemove,
  });

  final List<Connection> connections;
  final VoidCallback onRequestNew;
  final ConnCallback onConnect;
  final ConnCallback onRemove;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Ardour Remote - Connect to host")),
      body: ListView(
        children: [
          for (final conn in connections)
            ConnectionTile(
                connection: conn,
                onTap: () => onConnect(conn),
                onRemove: () => onRemove(conn)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 5,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: onRequestNew,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ConnectionTile extends StatelessWidget {
  const ConnectionTile({
    super.key,
    required this.connection,
    required this.onTap,
    required this.onRemove,
  });

  final Connection connection;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    var mainDesc = connection.connectionDesc();
    var secondDesc = "";
    if ((connection.name ?? "").isNotEmpty) {
      secondDesc = "  $mainDesc";
      mainDesc = connection.name!;
    }
    var theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.sensors),
      title: Text.rich(TextSpan(
          text: mainDesc,
          style: const TextStyle(fontSize: 16),
          children: <TextSpan>[
            if (secondDesc.isNotEmpty)
              TextSpan(
                  text: secondDesc,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ))
          ])),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () => onRemove(),
      ),
    );
  }
}
