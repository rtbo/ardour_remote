import 'package:ardour_remote/model/remote.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'model/connection.dart';

class RemotePage extends StatelessWidget {
  const RemotePage({super.key, required this.connection});
  final Connection connection;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ArdourRemote(connection),
      child: RemoteScreen(connection: connection),
    );
  }
}

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key, required this.connection});

  final Connection connection;

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final remote = Provider.of<ArdourRemote>(context, listen: false);
      remote.init();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final conn = widget.connection;
    Widget body;
    if (remote.connected) {
      body = Text("Connected to ${conn.toString()}");
    } else if (remote.error != null) {
      body = Text("Error: ${remote.error}");
    } else {
      body = const Text("Connecting...");
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: body,
    );
  }
}
