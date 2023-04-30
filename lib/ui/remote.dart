import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../assets.dart';
import '../model/ardour_remote.dart';
import '../model/connection.dart';

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
    final theme = Theme.of(context);
    final conn = widget.connection;
    Widget body;
    if (remote.connected) {
      body = Text("Connected to ${conn.toString()}");
    } else if (remote.error != null) {
      return RemoteError(errorText: remote.error!);
    } else {
      return const WaitConnection();
    }

    final colorAppBar = theme.colorScheme.primary;
    final colorOnAppBar = theme.colorScheme.onPrimary;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: colorAppBar,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: colorOnAppBar,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Row(
            children: [
              Image.asset(Assets.icons.connect_ardour, color: colorOnAppBar),
              const SizedBox(width: 8),
              Text(remote.sessionName, style: TextStyle(color: colorOnAppBar)),
            ],
          )),
      body: body,
    );
  }
}

class RemoteError extends StatelessWidget {
  final String errorText;

  const RemoteError({super.key, required this.errorText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
              child: Column(children: <Widget>[
            ListTile(
              leading: Icon(Icons.error, color: theme.colorScheme.error),
              title: const Text("Error: Can't connect to Ardour"),
              subtitle: Text(errorText),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
              TextButton(
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("BACK TO CONNECTION SETUP"),
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            ])
          ])),
        ],
      )),
    );
  }
}

class WaitConnection extends StatefulWidget {
  const WaitConnection({super.key});

  @override
  State<WaitConnection> createState() => _WaitConnectionState();
}

class _WaitConnectionState extends State<WaitConnection>
    with TickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    controller.addListener(() {
      setState(() {});
    });
    controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          value: controller.value,
          semanticsLabel: "Waiting for Ardour",
        ),
      ],
    ));
  }
}
