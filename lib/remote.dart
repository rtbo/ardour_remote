import 'package:flutter/material.dart';

import 'model/connection.dart';

class RemotePage extends StatefulWidget {
  const RemotePage({super.key, required this.connection});

  final Connection connection;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.connection;
    final desc = "Connected to ${conn.toString()}";
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Text(desc),
    );
  }
}
