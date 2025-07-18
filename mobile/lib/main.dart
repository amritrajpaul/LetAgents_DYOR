import 'package:flutter/material.dart';

import 'analysis_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'services/auth_service.dart';
import 'dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC6),
          background: Color(0xFF1c1f26),
          surface: Color(0xFF262b33),
          onSurface: Color(0xFFE2E8F0),
          secondary: Color(0xFFA0AEC0),
        ),
        textTheme: GoogleFonts.soraTextTheme(),
        cardTheme: const CardThemeData(
          color: Color(0xFF262b33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          elevation: 4,
          shadowColor: Colors.black54,
        ),
      ),
      home: AuthService.token == null ? const LoginScreen() : DashboardScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/dashboard': (_) => DashboardScreen(),
        '/history': (_) => const HistoryScreen(),
      },
    );
  }
}
