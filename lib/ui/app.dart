import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/connection.dart';
import 'connect.dart';

class AppState extends ChangeNotifier {
  Connection? _connection;

  Connection? get connection => _connection;

  set connection(Connection? c) {
    _connection = c;
    notifyListeners();
  }
}

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'Ardour Remote',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 75, 51, 180)),
        ),
        home: const ConnectionPage(),
      ),
    );
  }
}
