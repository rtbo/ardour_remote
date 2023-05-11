
import 'package:flutter/material.dart';

import '../../model/ardour_remote.dart';

extension DarkTheme on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkTheme {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark;
  }
}

extension Dark on ThemeData {
  /// is dark mode currently enabled?
  bool get isDark {
    return brightness == Brightness.dark;
  }
}

extension Record on Transport {
  bool get recordBlink {
    return recordArmed && !playing;
  }

  bool get recording {
    return recordArmed && playing;
  }
}

class Breakpoints {
  static const sm = 576;
  static const md = 768;
  static const lg = 992;
  static const xl = 1200;
  static const xxl = 1400;
}


const transitionDuration = Duration(milliseconds: 270);

class TransitionIconButton extends StatefulWidget {
  const TransitionIconButton(
      {super.key,
      required this.color,
      required this.asset,
      required this.size,
      required this.style,
      this.onPressed});
  final Color color;
  final String asset;
  final double size;
  final ButtonStyle style;
  final VoidCallback? onPressed;

  @override
  State<TransitionIconButton> createState() => _TransitionIconButtonState();
}

class _TransitionIconButtonState extends State<TransitionIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late ColorTween tween;
  late Animation<Color?> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    tween = ColorTween(begin: widget.color, end: widget.color);
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
  void didUpdateWidget(TransitionIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.color != widget.color) {
      tween.begin = oldWidget.color;
      tween.end = widget.color;
      controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon:
          Image.asset(widget.asset, width: widget.size, color: animation.value),
      iconSize: widget.size,
      style: widget.style,
      onPressed: widget.onPressed,
    );
  }
}