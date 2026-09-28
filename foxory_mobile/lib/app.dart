import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/database_helper.dart';
import 'ui/home_screen.dart';
import 'ui/trips_screen.dart';
import 'ui/planner_screen.dart';
import 'ui/expenses_screen.dart';
import 'ui/more_screen.dart';

class FoxoryApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final SharedPreferences prefs;

  const FoxoryApp({
    super.key,
    required this.dbHelper,
    required this.prefs,
  });

  @override
  State<FoxoryApp> createState() => _FoxoryAppState();
}

class _FoxoryAppState extends State<FoxoryApp> {
  int _currentIndex = 0;
  bool _isDark = true;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    _saveTheme();
  }

  Future<void> _saveTheme() async {
    await widget.prefs.setBool('dark_mode', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foxory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: MainShell(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
        onThemeToggle: _toggleTheme,
        isDark: _isDark,
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final Function() onThemeToggle;
  final bool isDark;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.onThemeToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foxory'),
        leading: _buildThemeButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Pi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync coming soon')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              HomeScreen(),
              TripsScreen(),
              PlannerScreen(),
              ExpensesScreen(),
              MoreScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_outlined),
            activeIcon: Icon(Icons.flight),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_outlined),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildThemeButton() {
    final icon = isDark ? Icons.light_mode : Icons.dark_mode;
    final tooltip = isDark ? 'Light mode' : 'Dark mode';
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onThemeToggle,
    );
  }
}
