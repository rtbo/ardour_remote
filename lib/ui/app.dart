import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'connect.dart';

const _defaultLightColorScheme = ColorScheme.light();
const _defaultDarkColorScheme = ColorScheme.dark();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Ardour Remote',
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
          useMaterial3: true,
        ),
        home: const ConnectionPage(),
      );
    });
  }
}
