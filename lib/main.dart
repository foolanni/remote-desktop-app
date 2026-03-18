import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/punk/punk_home_screen.dart';
import 'services/connection_manager.dart';
import 'services/auth_service.dart';
import 'services/punk/punk_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PunkService()),
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
      home: const MainTabScreen(),
      routes: {
        '/connect': (context) => const ConnectScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// 主 Tab 界面：远程桌面 + PUNK Agent 控制
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    PunkHomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<PunkService>(
        builder: (context, punk, _) => NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.computer_outlined),
              selectedIcon: Icon(Icons.computer),
              label: '远程桌面',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: punk.totalPendingCount > 0,
                label: Text('${punk.totalPendingCount}'),
                child: const Text('⚡',
                    style: TextStyle(fontSize: 20)),
              ),
              label: 'PUNK',
            ),
          ],
        ),
      ),
    );
  }
}
