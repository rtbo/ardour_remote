import 'package:flutter/material.dart';

import '../assets.dart';
import 'remote.dart';
import '../model/connection.dart';
import '../model/db.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  ConnectionDb? db;
  var connections = <Connection>[];
  var requestNew = false;

  @override
  void initState() {
    super.initState();
    ConnectionDb.load().then((db) async {
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Name (optional)",
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextFormField(
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
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sendPortController,
                        keyboardType: TextInputType.number,
                        validator: validatePort,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "\u2191 Send Port",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: rcvPortController,
                        keyboardType: TextInputType.number,
                        validator: validatePort,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "\u2193 Receive Port",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  icon: Image.asset(Assets.icons.connect_ardour,
                      color: Theme.of(context).colorScheme.primary),
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
    var mainDesc = connection.toString();
    var secondDesc = "";
    if ((connection.name ?? "").isNotEmpty) {
      secondDesc = "  $mainDesc";
      mainDesc = connection.name!;
    }
    var theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Image.asset(
        Assets.icons.connect_ardour,
        color: theme.colorScheme.onSurface,
      ),
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
