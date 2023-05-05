import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'connect.dart';

const _defaultLightColorScheme = ColorScheme.light();
const _defaultDarkColorScheme = ColorScheme.dark();

const forceLight = false;
const forceDark = false;

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      final light = lightColorScheme ?? _defaultLightColorScheme;
      final dark = darkColorScheme ?? _defaultDarkColorScheme;

      return MaterialApp(
        title: 'Ardour Remote',
        theme: ThemeData(
          colorScheme: forceDark ? dark : light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: forceLight ? light : dark,
          useMaterial3: true,
        ),
        home: const ConnectionPage(),
      );
    });
  }
}
