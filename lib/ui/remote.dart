import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ardour_mock.dart';
import '../assets.dart';
import '../model/ardour_remote.dart';
import '../model/connection.dart';

const useRemoteMock = true;

extension on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkTheme {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark;
  }
}

extension on ThemeData {
  /// is dark mode currently enabled?
  bool get isDark {
    return brightness == Brightness.dark;
  }
}

extension on ArdourRemote {
  bool get recordBlink {
    return recordArmed && !playing;
  }

  bool get recording {
    return recordArmed && playing;
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
          return ArdourRemoteImpl(connection)..connect();
        } else {
          return ArdourRemoteMock(connection)..connect();
        }
      },
      child: RemoteLoader(connection: connection),
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

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final colorAppBar = colorScheme.primary;
    final colorOnAppBar = colorScheme.onPrimary;

    final butStyle = IconButton.styleFrom(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.6),
      disabledBackgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
    );

    return Scaffold(
      appBar: AppBar(
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
              Text(remote.sessionName, style: TextStyle(color: colorOnAppBar)),
            ],
          )),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          const TimeInfoRow(),
          const SizedBox(height: 24),
          JumpButtonsRow(butStyle: butStyle),
          const SizedBox(height: 24),
          RecordingButtonsRow(butStyle: butStyle),
          const Spacer(),
          const ConnectInfoRow(),
        ]),
      ),
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
  const JumpButtonsRow({super.key, required this.butStyle});

  final ButtonStyle butStyle;

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final theme = Theme.of(context);
    final iconCol = theme.colorScheme.onBackground;
    const sz = 36.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Image.asset(Assets.icons.arrow_left_double_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.toStart();
          },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_left_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBars(-1);
          },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_left_quarter,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBeats(-1);
          },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_right_quarter,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBeats(1);
          },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_right_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBars(1);
          },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_right_double_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.toEnd();
          },
        ),
      ],
    );
  }
}

class ButtonPalette {
  final Color record;
  final Color recordOff;
  final Color recordDisabled;
  final Color play;
  final Color playDisabled;
  final Color stop;
  final Color stopDisabled;

  const ButtonPalette(
      {required this.record,
      required this.recordOff,
      required this.recordDisabled,
      required this.play,
      required this.playDisabled,
      required this.stop,
      required this.stopDisabled});
}

class RecordingButtonsRow extends StatelessWidget {
  const RecordingButtonsRow({super.key, required this.butStyle});

  final ButtonStyle butStyle;

  @override
  Widget build(BuildContext context) {
    const sz = 56.0;
    final remote = context.watch<ArdourRemote>();
    final theme = Theme.of(context);
    final isDark = theme.isDark;

    const lightButPalette = ButtonPalette(
        record: Color.fromARGB(255, 216, 50, 50),
        recordOff: Color.fromARGB(255, 88, 23, 23),
        recordDisabled: Color.fromARGB(255, 61, 44, 44),
        play: Color.fromARGB(255, 37, 146, 52),
        playDisabled: Color.fromARGB(255, 53, 88, 59),
        stop: Color.fromARGB(255, 73, 105, 209),
        stopDisabled: Color.fromARGB(255, 55, 68, 112));

    const darkButPalette = ButtonPalette(
        record: Color.fromARGB(255, 236, 68, 68),
        recordOff: Color.fromARGB(255, 131, 30, 30),
        recordDisabled: Color.fromARGB(255, 61, 44, 44),
        play: Color.fromARGB(255, 122, 214, 135),
        playDisabled: Color.fromARGB(255, 58, 100, 64),
        stop: Color.fromARGB(255, 123, 148, 231),
        stopDisabled: Color.fromARGB(255, 63, 72, 100));

    final butPalette = isDark ? darkButPalette : lightButPalette;
    final recordBut = remote.recordBlink
        ? BlinkRecordButton(
            color: butPalette.record,
            colorOff: butPalette.recordOff,
            size: sz,
            style: butStyle)
        : SolidRecordButton(
            color: remote.recording ? butPalette.record : butPalette.recordOff,
            size: sz,
            style: butStyle);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        recordBut,
        IconButton(
          icon: Image.asset(Assets.icons.play,
              width: sz,
              height: sz,
              color:
                  remote.playing ? butPalette.playDisabled : butPalette.play),
          iconSize: sz,
          style: butStyle,
          onPressed: remote.playing
              ? null
              : () {
                  remote.play();
                },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.stop,
              width: sz,
              color:
                  remote.stopped ? butPalette.stopDisabled : butPalette.stop),
          iconSize: sz,
          style: butStyle,
          onPressed: remote.stopped
              ? null
              : () {
                  remote.stop();
                },
        ),
        IconButton(
          icon: Image.asset(Assets.icons.stop_trash,
              width: sz,
              color: remote.recording
                  ? butPalette.record
                  : butPalette.recordDisabled),
          iconSize: sz,
          style: butStyle,
          onPressed: remote.recording
              ? () {
                  remote.stopAndTrash();
                }
              : null,
        ),
      ],
    );
  }
}

class SolidRecordButton extends StatelessWidget {
  final Color? color;
  final double size;

  const SolidRecordButton(
      {super.key,
      required this.color,
      required this.size,
      required this.style});

  final ButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    return IconButton(
      icon: Image.asset(Assets.icons.record, width: size, color: color),
      iconSize: size,
      style: style,
      onPressed: () {
        remote.recordArmToggle();
      },
    );
  }
}

class BlinkRecordButton extends StatefulWidget {
  const BlinkRecordButton(
      {super.key,
      required this.color,
      required this.colorOff,
      required this.size,
      required this.style});

  final Color? color;
  final Color? colorOff;
  final double size;
  final ButtonStyle style;

  @override
  State<BlinkRecordButton> createState() => _BlinkRecordButtonState();
}

class _BlinkRecordButtonState extends State<BlinkRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Color?> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    animation = ColorTween(begin: widget.colorOff, end: widget.color).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutQuart))
      ..addListener(() {
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
    final remote = context.watch<ArdourRemote>();
    return IconButton(
      icon: Image.asset(Assets.icons.record,
          width: widget.size, color: animation.value),
      iconSize: widget.size,
      style: widget.style,
      onPressed: () {
        remote.recordArmToggle();
      },
    );
  }
}

class ConnectInfoRow extends StatelessWidget {
  const ConnectInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<ArdourRemote>();
    final isDark = context.isDarkTheme;
    final onSwatch = isDark ? 400 : 500;
    final offSwatch = isDark ? 800 : 900;
    final colorHb =
        remote.heartbeat ? Colors.blue[onSwatch] : Colors.blue[offSwatch];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, color: colorHb, size: 12),
        const SizedBox(width: 8),
        Text(remote.connection.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
      ],
    );
  }
}
