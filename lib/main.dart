import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/settings_screen.dart';
import 'services/connection_manager.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const RemoteDesktopApp(),
    ),
  );
}

class RemoteDesktopApp extends StatelessWidget {
  const RemoteDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '远程桌面',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/connect': (context) => const ConnectScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
