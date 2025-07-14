import 'package:flutter/material.dart';

void main() {
  runApp(const LetAgentsDYORApp());
}

class LetAgentsDYORApp extends StatelessWidget {
  const LetAgentsDYORApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LetAgentsDYOR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: const {},
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('LetAgentsDYOR Home')),
    );
  }
}
