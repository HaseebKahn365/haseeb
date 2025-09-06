import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/custom_list.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/models/planned_activity.dart';
import 'package:haseeb/providers/theme_provider.dart';
import 'package:haseeb/screens/agent_chat_screen.dart';
import 'package:haseeb/screens/home_screen.dart';
import 'package:haseeb/screens/settings_screen.dart';
import 'package:haseeb/screens/widget_preview_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ActivityAdapter());
  Hive.registerAdapter(CountActivityAdapter());
  Hive.registerAdapter(DurationActivityAdapter());
  Hive.registerAdapter(PlannedActivityAdapter());
  Hive.registerAdapter(CustomListAdapter());
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final lightTheme = ref.watch(themeDataProvider);
    final darkTheme = ref.watch(darkThemeDataProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeState.mode,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AgentChatScreen(),
    const SettingsScreen(),
    const WidgetPreviewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'Agent Chat', 'Settings', 'Widget Preview'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_currentIndex])),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            developer.log('Navigation tapped: $index');
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.6),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 24),
              label: 'Home',
              tooltip: 'Home Screen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat, size: 24),
              label: 'Agent',
              tooltip: 'AI Agent Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings, size: 24),
              label: 'Settings',
              tooltip: 'App Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.widgets, size: 24),
              label: 'Widgets',
              tooltip: 'Widget Preview',
            ),
          ],
        ),
      ),
    );
  }
}
