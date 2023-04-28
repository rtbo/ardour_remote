import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'connection.dart';

extension on DateTime? {
  int? get toDb => this?.millisecondsSinceEpoch;
}

extension on int? {
  DateTime? get fromDb {
    final val = this;
    return val != null ? DateTime.fromMillisecondsSinceEpoch(val) : null;
  }
}

class ConnectionDb {
  final Database db;

  ConnectionDb({required this.db});

  static Future<ConnectionDb> load() async {
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

    return ConnectionDb(db: db);
  }

  Future<List<Connection>> getAll() async {
    var connections = <Connection>[];
    var cursor = await db.rawQueryCursor('''
        SELECT id, name, host, send_port, rcv_port, last_used
        FROM connection
        ORDER BY last_used DESC NULLS LAST
      ''', null, bufferSize: 10);
    while (await cursor.moveNext()) {
      connections.add(_fromMap(cursor.current));
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

  Connection _fromMap(Map<String, Object?> map) {
    return Connection(
      id: map["id"] as int?,
      name: map["name"] as String?,
      host: (map["host"] as String?)!,
      sendPort: (map["send_port"] as int?)!,
      rcvPort: (map["rcv_port"] as int?)!,
      lastUsed: (map["last_used"] as int?).fromDb,
    );
  }
}
