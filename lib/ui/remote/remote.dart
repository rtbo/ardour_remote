import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';

import '../../assets.dart';
import '../../model/ardour_mock.dart';
import '../../model/ardour_remote.dart';
import '../../model/connection.dart';
import 'common.dart';
import 'transport.dart';

const useRemoteMock = true;

class RemotePage extends StatefulWidget {
  const RemotePage({super.key, required this.connection});
  final Connection connection;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  late ArdourRemote remote;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode || widget.connection.host != "mock") {
      remote = ArdourRemoteImpl(widget.connection)..connect();
    } else {
      remote = ArdourRemoteMock(widget.connection)..connect();
    }
  }

  @override
  void dispose() {
    remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: remote),
        ChangeNotifierProvider.value(value: remote.transport),
      ],
      child: RemoteLoader(connection: widget.connection),
    );
  }
}

class RemoteLoader extends StatelessWidget {
  const RemoteLoader({super.key, required this.connection});

  final Connection connection;

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

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      Wakelock.enable();
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid || Platform.isIOS) {
      Wakelock.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final colorAppBar = colorScheme.primary;
    final colorOnAppBar = colorScheme.onPrimary;

    return LayoutBuilder(builder: (context, constraints) {
      final appBarHeight = constraints.maxHeight < Breakpoints.sm ? 48.0 : 56.0;
      return Scaffold(
        appBar: AppBar(
            toolbarHeight: appBarHeight,
            backgroundColor: colorAppBar,
            leading: IconButton(
              style: IconButton.styleFrom(backgroundColor: colorAppBar),
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
                Text(remote.sessionName,
                    style: TextStyle(color: colorOnAppBar)),
              ],
            )),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RemoteBody(constraints: constraints),
        ),
      );
    });
  }
}

class RemoteBody extends StatelessWidget {
  const RemoteBody({super.key, required this.constraints});
  // constraints of the full window, including AppBar!
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final butStyle = IconButton.styleFrom(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.6),
      disabledBackgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
    );

    if (constraints.maxWidth < Breakpoints.md) {
      return Column(children: [
        const TimeInfoRow(),
        const SizedBox(height: 24),
        JumpButtonsRow(butStyle: butStyle),
        const SizedBox(height: 24),
        RecordingButtonsRow(butStyle: butStyle),
        const Spacer(),
        const ConnectInfoRow(),
      ]);
    } else {
      return Column(children: [
        const TimeInfoRow(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JumpButtonsRow(butStyle: butStyle),
            const SizedBox(width: 24),
            RecordingButtonsRow(butStyle: butStyle),
          ],
        ),
        const SizedBox(height: 24),
        const Spacer(),
        const ConnectInfoRow(),
      ]);
    }
  }
}

class ConnectInfoRow extends StatelessWidget {
  const ConnectInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Heartbeat(
            isDark: context.isDarkTheme, isOn: remote.heartbeat, size: 12),
        const SizedBox(width: 8),
        Text(remote.connection.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
      ],
    );
  }
}

class Heartbeat extends StatefulWidget {
  const Heartbeat(
      {super.key,
      required this.isDark,
      required this.isOn,
      required this.size});

  final bool isDark;
  final bool isOn;
  final double size;

  @override
  State<Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<Heartbeat>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late ColorTween tween;
  late Animation<Color?> animation;

  @override
  void initState() {
    super.initState();
    final palette = widget.isDark ? darkButPalette : lightButPalette;
    controller = AnimationController(vsync: this, duration: transitionDuration);
    tween = ColorTween(begin: palette.heartbeatOff, end: palette.heartbeatOn);
    animation = tween
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    animation.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Heartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOn && !widget.isOn) {
      controller.forward();
    } else if (!oldWidget.isOn && widget.isOn) {
      controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.circle, color: animation.value, size: widget.size);
  }
}
