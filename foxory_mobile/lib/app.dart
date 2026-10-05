import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/database_helper.dart';
import '../services/notification_service.dart';
import '../core/app_settings.dart';
import '../services/local_pi_sync_service.dart';
import 'ui/home_screen.dart';
import 'ui/trips_screen.dart';
import 'ui/planner_screen.dart';
import 'ui/expenses_screen.dart';
import 'ui/more_screen.dart';

class YourTravelBuddyApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final SharedPreferences prefs;
  final AlertService alerts;

  const YourTravelBuddyApp({
    super.key,
    required this.dbHelper,
    required this.prefs,
    required this.alerts,
  });

  @override
  State<YourTravelBuddyApp> createState() => _YourTravelBuddyAppState();
}

class _YourTravelBuddyAppState extends State<YourTravelBuddyApp> {
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
      title: 'Your Travel Buddy',
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
        title: const Text('Your Travel Buddy'),
        leading: _buildThemeButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Pi',
            onPressed: () => _syncNow(context),
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
            children: [
              const HomeScreen(),
              const TripsScreen(),
              PlannerScreen(isActive: currentIndex == 2),
              const ExpensesScreen(),
              const MoreScreen(),
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

  Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing to Pi...')),
    );

    final settings = AppSettings();
    await settings.init();
    final result = await LocalPiSyncService(
      settings: settings,
      dbHelper: DatabaseHelper(),
    ).uploadAll();

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.orange,
      ),
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
