import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/app_settings.dart';
import '../core/database_helper.dart';
import 'ui/home_screen.dart';
import 'ui/trips_screen.dart';
import 'ui/planner_screen.dart';
import 'ui/expenses_screen.dart' hide Text, Theme, SizedBox;
import 'ui/more_screen.dart';

class FoxoryApp extends StatefulWidget {
  final AppSettings settings;
  final DatabaseHelper dbHelper;

  const FoxoryApp({
    super.key,
    required this.settings,
    required this.dbHelper,
  });

  @override
  State<FoxoryApp> createState() => _FoxoryAppState();
}

class _FoxoryAppState extends State<FoxoryApp> {
  int _currentIndex = 0;
  late ThemeData _theme;
  late AppThemeMode _appThemeMode;

  @override
  void initState() {
    super.initState();
    _appThemeMode = _resolveThemeMode();
    _theme = _appThemeMode == AppThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }

  AppThemeMode _resolveThemeMode() {
    if (widget.settings.useSystemTheme) {
      return AppThemeMode.system;
    }
    return widget.settings.darkMode ? AppThemeMode.dark : AppThemeMode.light;
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _toggleTheme() async {
    if (_appThemeMode == AppThemeMode.system) {
      setState(() {
        _appThemeMode = AppThemeMode.dark;
        _theme = AppTheme.darkTheme;
      });
      widget.settings.darkMode = true;
      widget.settings.useSystemTheme = false;
    } else if (_appThemeMode == AppThemeMode.dark) {
      setState(() {
        _appThemeMode = AppThemeMode.light;
        _theme = AppTheme.lightTheme;
      });
      widget.settings.darkMode = false;
      widget.settings.useSystemTheme = false;
    } else {
      setState(() {
        _appThemeMode = AppThemeMode.system;
        _theme = Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
      });
      widget.settings.useSystemTheme = true;
    }
    final prefs = await SharedPreferences.getInstance();
    await widget.settings.save(prefs);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foxory',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _appThemeMode == AppThemeMode.system
          ? ThemeMode.system
          : _appThemeMode == AppThemeMode.dark
              ? ThemeMode.dark
              : ThemeMode.light,
      home: MainShell(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
        onThemeToggle: _toggleTheme,
        appThemeMode: _appThemeMode,
      ),
    );
  }
}

enum AppThemeMode { light, dark, system }

class MainShell extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final Function() onThemeToggle;
  final AppThemeMode appThemeMode;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.onThemeToggle,
    required this.appThemeMode,
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
              // Navigate to sync screen or show sync dialog
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
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          TripsScreen(),
          PlannerScreen(),
          ExpensesScreen(),
          MoreScreen(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickCaptureOptions(context);
        },
        child: const Icon(Icons.add),
        tooltip: 'Quick Capture',
      ),
    );
  }

  Widget _buildThemeButton() {
    IconData icon;
    String tooltip;
    switch (appThemeMode) {
      case AppThemeMode.light:
        icon = Icons.light_mode;
        tooltip = 'Light mode';
        break;
      case AppThemeMode.dark:
        icon = Icons.dark_mode;
        tooltip = 'Dark mode';
        break;
      case AppThemeMode.system:
        icon = Icons.brightness_auto;
        tooltip = 'Follow system';
        break;
    }
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onThemeToggle,
    );
  }

  void _showQuickCaptureOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Capture',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'What do you want to capture?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            _captureOption(Icons.flight, 'New Trip', 'Start planning a trip', context,
                () => {Navigator.pop(context), _openTripsScreen(context)}),
            _captureOption(Icons.note, 'Note', 'Write a quick note', context,
                () => {Navigator.pop(context), _quickNote(context)}),
            _captureOption(Icons.tag, 'Task', 'Add a new task', context,
                () => {Navigator.pop(context), _quickTask(context)}),
            _captureOption(Icons.attach_money, 'Expense', 'Log an expense', context,
                () => {Navigator.pop(context), _openExpensesScreen(context)}),
            _captureOption(Icons.hotel, 'Hotel', 'Add hotel stay', context,
                () => {Navigator.pop(context), _openMoreScreen(context)}),
            _captureOption(Icons.flight, 'Flight', 'Add flight details', context,
                () => {Navigator.pop(context), _openMoreScreen(context)}),
            _captureOption(Icons.photo_camera, 'Photo', 'Take or add a photo', context,
                () => {Navigator.pop(context), _openMoreScreen(context)}),
            _captureOption(Icons.inventory_2, 'Packing', 'Manage packing list', context,
                () => {Navigator.pop(context), _openPlanner(context)}),
            _captureOption(Icons.badge, 'Passport/Visa', 'Track documents', context,
                () => {Navigator.pop(context), _openMoreScreen(context)}),
            _captureOption(Icons.folder, 'File', 'Add a file', context,
                () => {Navigator.pop(context), _openMoreScreen(context)}),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openTripsScreen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the Trips tab to start a new trip')),
    );
  }

  void _openExpensesScreen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the Expenses tab to log an expense')),
    );
  }

  void _openMoreScreen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the More tab to add hotels, flights, photos, and documents')),
    );
  }

  void _openPlanner(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open the Planner tab to manage your trip')),
    );
  }

  void _quickNote(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Note', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (controller.text.isNotEmpty) {
                      final db = DatabaseHelper();
                      db.insert('notes', {
                        'title': controller.text.split('\n').first.trim(),
                        'content': controller.text,
                        'tags': '',
                        'category': 'quick',
                        'priority': 0,
                        'is_pinned': 0,
                        'is_archived': 0,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _quickTask(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Task', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (controller.text.isNotEmpty) {
                      final db = DatabaseHelper();
                      db.insert('tasks', {
                        'title': controller.text,
                        'description': '',
                        'details': '',
                        'status': 0,
                        'priority': 1,
                        'order_index': 0,
                        'due_date': null,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                        'is_quick': 1,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task added')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _captureOption(IconData icon, String label, String subtitle, BuildContext ctx,
      VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(ctx).colorScheme.primary),
        ),
        title: Text(label),
        subtitle: Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          Navigator.pop(ctx);
          onTap?.call();
        },
      ),
    );
  }
}
