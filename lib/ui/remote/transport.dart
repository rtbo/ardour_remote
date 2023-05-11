import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../assets.dart';
import '../../model/ardour_remote.dart';
import 'common.dart';

final speedFormat = NumberFormat("##0.0#");

class TimeInfoRow extends StatelessWidget {
  const TimeInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<Transport>();
    final isDark = context.isDarkTheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      color: isDark ? Colors.green[400] : Colors.green[800],
      fontSize: 16,
    );
    final speed = transport.speed;
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(transport.timecode, style: style),
            const SizedBox(width: 12),
            Text(transport.bbt, style: style),
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
    final remote = Provider.of<ArdourRemote>(context, listen: false);
    final theme = Theme.of(context);
    final iconCol = theme.colorScheme.onBackground;
    const sz = 36.0;
    const space = 6.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Image.asset(Assets.icons.rewind, width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.rewind();
          },
        ),
        const SizedBox(width: space),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_left_double_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.toStart();
          },
        ),
        const SizedBox(width: space),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_left_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBars(-1);
          },
        ),
        const SizedBox(width: space),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_right_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.jumpBars(1);
          },
        ),
        const SizedBox(width: space),
        IconButton(
          icon: Image.asset(Assets.icons.arrow_right_double_bar,
              width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.toEnd();
          },
        ),
        const SizedBox(width: space),
        IconButton(
          icon:
              Image.asset(Assets.icons.fast_forward, width: sz, color: iconCol),
          iconSize: sz,
          style: butStyle,
          onPressed: () {
            remote.ffwd();
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

  Color get heartbeatOn => stop;
  Color get heartbeatOff => stopDisabled;

  const ButtonPalette(
      {required this.record,
      required this.recordOff,
      required this.recordDisabled,
      required this.play,
      required this.playDisabled,
      required this.stop,
      required this.stopDisabled});
}

const lightButPalette = ButtonPalette(
    record: Color.fromARGB(255, 216, 50, 50),
    recordOff: Color.fromARGB(255, 88, 23, 23),
    recordDisabled: Color.fromARGB(255, 61, 44, 44),
    play: Color.fromARGB(255, 37, 146, 52),
    playDisabled: Color.fromARGB(255, 53, 88, 59),
    stop: Color.fromARGB(255, 66, 108, 245),
    stopDisabled: Color.fromARGB(255, 55, 68, 112));

const darkButPalette = ButtonPalette(
    record: Color.fromARGB(255, 236, 68, 68),
    recordOff: Color.fromARGB(255, 97, 22, 22),
    recordDisabled: Color.fromARGB(255, 61, 44, 44),
    play: Color.fromARGB(255, 122, 214, 135),
    playDisabled: Color.fromARGB(255, 58, 100, 64),
    stop: Color.fromARGB(255, 123, 148, 231),
    stopDisabled: Color.fromARGB(255, 63, 72, 100));

class RecordingButtonsRow extends StatelessWidget {
  const RecordingButtonsRow({super.key, required this.butStyle});

  final ButtonStyle butStyle;

  @override
  Widget build(BuildContext context) {
    const sz = 56.0;
    const space = 18.0;
    final transport = context.watch<Transport>();
    final remote = Provider.of<ArdourRemote>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.isDark;
    final palette = isDark ? darkButPalette : lightButPalette;

    final recordBut = transport.recordBlink
        ? BlinkRecordButton(
            color: palette.record,
            colorOff: palette.recordOff,
            size: sz,
            style: butStyle)
        : SolidRecordButton(
            color: transport.recording ? palette.record : palette.recordOff,
            size: sz,
            style: butStyle);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        recordBut,
        const SizedBox(width: space),
        TransitionIconButton(
          asset: Assets.icons.play,
          size: sz,
          color: transport.playing ? palette.playDisabled : palette.play,
          style: butStyle,
          onPressed: transport.playing
              ? null
              : () {
                  remote.play();
                },
        ),
        const SizedBox(width: space),
        TransitionIconButton(
          asset: Assets.icons.stop,
          size: sz,
          color: transport.stopped ? palette.stopDisabled : palette.stop,
          style: butStyle,
          onPressed: transport.stopped
              ? null
              : () {
                  remote.stop();
                },
        ),
        const SizedBox(width: space),
        TransitionIconButton(
          asset: Assets.icons.stop_trash,
          size: sz,
          color: transport.recording ? palette.record : palette.recordDisabled,
          style: butStyle,
          onPressed: transport.recording
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
        vsync: this, duration: const Duration(milliseconds: 400));
    animation = ColorTween(begin: widget.colorOff, end: widget.color).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutExpo))
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
