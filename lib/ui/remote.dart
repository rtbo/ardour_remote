import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ardour_mock.dart';
import '../assets.dart';
import '../model/ardour_remote.dart';
import '../model/connection.dart';

const useRemoteMock = true;

extension on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkMode {
    final brightness = MediaQuery.of(this).platformBrightness;
    return brightness == Brightness.dark;
  }
}

class RemotePage extends StatelessWidget {
  const RemotePage({super.key, required this.connection});
  final Connection connection;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        if (kReleaseMode) {
          return ArdourRemoteImpl(connection);
        } else {
          return ArdourRemoteMock(connection);
        }
      },
      child: RemoteLoader(connection: connection),
    );
  }
}

class RemoteLoader extends StatefulWidget {
  const RemoteLoader({super.key, required this.connection});

  final Connection connection;

  @override
  State<RemoteLoader> createState() => _RemoteLoaderState();
}

class _RemoteLoaderState extends State<RemoteLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final remote = Provider.of<ArdourRemote>(context, listen: false);
      remote.connect();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    if (remote.connected) {
      return const RemoteScreen();
    } else if (remote.error != null) {
      return RemoteError(errorText: remote.error!);
    } else {
      return const WaitConnection();
    }
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

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final theme = Theme.of(context);

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
              Image.asset(Assets.icons.ardour_connect, color: colorOnAppBar),
              const SizedBox(width: 8),
              Text(remote.sessionName, style: TextStyle(color: colorOnAppBar)),
            ],
          )),
      body: Column(children: const [
        TimeInfoRow(),
        ConnectInfoRow(),
      ]),
    );
  }
}

final speedFormat = NumberFormat("##0.0#");

class TimeInfoRow extends StatelessWidget {
  const TimeInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final isDark = context.isDarkTheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      color: isDark ? Colors.green[400] : Colors.green[800],
      fontSize: 16,
    );
    final speed = remote.speed;
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(remote.timecode, style: style),
            const SizedBox(width: 12),
            Text(remote.bbt, style: style),
          ],
        ),
        if (speed != 0 && speed != 1)
          Positioned(
              left: MediaQuery.of(context).size.width / 2 + 132,
              bottom: 0,
              child: Text(
                "${speedFormat.format(speed)}x",
                style: style.copyWith(fontSize: 12),
              )),
      ],
    );
  }
}

class JumpButtonsRow extends StatelessWidget {
  const JumpButtonsRow({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

class RecordingButtonsRow extends StatelessWidget {
  const RecordingButtonsRow({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

class ConnectInfoRow extends StatelessWidget {
  const ConnectInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final colorHb = remote.heartbeat ? Colors.blue[600] : Colors.blue[900];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, color: colorHb, size: 12),
        const SizedBox(width: 8),
        Text(remote.connection.toString()),
      ],
    );
  }
}
