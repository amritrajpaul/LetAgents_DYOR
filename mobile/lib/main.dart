import 'package:flutter/material.dart';

import 'analysis_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadToken();
  runApp(const LetAgentsDYORApp());
}

class LetAgentsDYORApp extends StatelessWidget {
  const LetAgentsDYORApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LetAgentsDYOR',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AuthService.token == null ? const LoginScreen() : const AnalysisScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/history': (_) => const HistoryScreen(),
      },
    );
  }
}
