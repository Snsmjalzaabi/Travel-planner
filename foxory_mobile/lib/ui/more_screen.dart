import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/hotel_booking_form.dart';
import '../core/app_settings.dart';
import '../services/local_pi_sync_service.dart';
import 'recommendations_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  List<Note> _notes = [];
  List<Task> _tasks = [];
  List<Passport> _passports = [];
  List<AppFile> _files = [];
  List<Map<String, dynamic>> _hotels = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _lastSyncMessage;
  bool? _lastSyncSuccess;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;

    final notes = await db.query(
      'notes',
      where: 'is_archived = ?',
      whereArgs: [0],
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    final tasks = await db.query(
      'tasks',
      orderBy: 'priority DESC, due_date ASC',
    );
    final passports = await db.query('passports');
    final files = await db.query(
      'app_files',
      orderBy: 'created_at DESC',
      limit: 20,
    );
    final hotels = await db.query(
      'hotels',
      orderBy: 'check_in DESC',
      limit: 20,
    );

    setState(() {
    _notes = notes.map((m) => Note.fromMap(m)).toList();
    _tasks = tasks.map((m) => Task.fromMap(m)).toList();
    _passports = passports.map((m) => Passport.fromMap(m)).toList();
    _files = files.map((m) => AppFile.fromMap(m)).toList();
    _hotels = hotels.map((m) => m as Map<String, dynamic>).toList();
    _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection('Notes', Icons.note, _notes, (note) {
                  _showNoteDetail(note);
                }),
                _buildSection('Tasks', Icons.task_alt, _tasks, (task) {
                  _showTaskDetail(task);
                }),
                _buildSection('Passports & Visas', Icons.badge, _passports, (p) {
                  _showPassportDetail(p);
                }),
                _buildSection('Files', Icons.folder, _files, (f) {
                  _showFileDetail(f);
                }),
                _buildSection('Hotel Confirmations', Icons.hotel, _hotels, (h) {
                  _showHotelDetail(h);
                }),
                const Divider(),
                _buildSettingsItems(),
                const SizedBox(height: 16),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Quick Add',
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List list, void Function(dynamic)? onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${list.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Center(
              child: Text(
                'No ${title.toLowerCase().replaceAll('&', '').replaceAll(' ', '')} yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
          )
        else
          ...list.take(3).map((item) => _buildListItem(item, icon, onTap)),
        if (list.length > 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              child: Text(
                'See all ${list.length - 3} more',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$list.length $title loaded')),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildListItem(dynamic item, IconData icon, void Function(dynamic)? onTap) {
    String title;
    String subtitle;
    Color dotColor;

    if (item is Note) {
      title = item.title.isEmpty ? 'Untitled' : item.title;
      subtitle = item.content.length > 60
          ? '${item.content.substring(0, 60)}...'
          : item.content;
      dotColor = _priorityColor(TaskPriority.values[(item.priority ?? 0)]);
    } else if (item is Task) {
      title = item.title;
      subtitle = item.dueDate != null
          ? DateFormat('MMM d').format(item.dueDate!)
          : item.category ?? 'No category';
      dotColor = _taskPriorityColor(item.priority.index);
    } else if (item is Passport) {
      title = item.country;
      subtitle = item.expired
          ? 'Expired ${DateFormat('MMM d, y').format(item.expiryDate)}'
          : item.expiringSoon
              ? 'Expires ${DateFormat('MMM d, y').format(item.expiryDate)}'
              : 'Valid until ${DateFormat('MMM d, y').format(item.expiryDate)}';
      dotColor = item.expired ? Colors.red : (item.expiringSoon ? Colors.orange : Colors.green);
    } else if (item is AppFile) {
      title = item.name;
      subtitle = DateFormat('MMM d, y').format(item.createdAt);
      dotColor = Colors.blue;
    } else {
      return const SizedBox();
    }

    return InkWell(
      onTap: () {
        onTap?.call(item);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  Color _taskPriorityColor(int idx) {
    switch (idx) {
      case 0: return Colors.grey;
      case 1: return Colors.orange;
      case 2: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildSettingsItems() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync with Pi'),
          subtitle: const Text('Upload/download data to your Raspberry Pi'),
          trailing: _buildSyncStatus(),
          onTap: () => _showSyncDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('Recommendations'),
          subtitle: const Text('Ideas based on your trip, dates and group'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecommendationsScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('File Storage'),
          subtitle: const Text('Manage files stored on this device'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile'),
          subtitle: const Text('Your device ID and preferences'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & About'),
          subtitle: const Text('Version 1.0.0'),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSyncStatus() {
    if (_isSyncing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_lastSyncSuccess == true) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
    if (_lastSyncSuccess == false) {
      return const Icon(Icons.error_outline, color: Colors.orange, size: 20);
    }
    return const Icon(Icons.cloud_upload_outlined, size: 20, color: Colors.grey);
  }

  Future<void> _showSyncDialog(BuildContext context) async {
    final settings = AppSettings();
    await settings.init();

    final ipController = TextEditingController(text: settings.piAddress);
    final portController = TextEditingController(text: settings.piPort.toString());

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync with Pi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Back up this phone's travel data to the Pi. Keep both devices on the same Wi-Fi.",
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Pi IP address',
                  hintText: '192.168.1.21',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Sync port',
                  hintText: '9101',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Text(
                settings.lastSyncAt.isEmpty
                    ? 'No successful sync yet.'
                    : 'Last sync: ${DateFormat('MMM d, h:mm a').format(DateTime.tryParse(settings.lastSyncAt) ?? DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              if (_lastSyncMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lastSyncMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _lastSyncSuccess == true ? Colors.green : Colors.orange,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Sync Now'),
            onPressed: () async {
              final port = int.tryParse(portController.text.trim()) ?? 9101;
              await settings.setPiAddress(ipController.text);
              await settings.setPiPort(port);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _runSync(settings);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runSync(AppSettings settings) async {
    setState(() {
      _isSyncing = true;
      _lastSyncMessage = 'Syncing to Pi...';
      _lastSyncSuccess = null;
    });

    final result = await LocalPiSyncService(
      settings: settings,
      dbHelper: DatabaseHelper(),
    ).uploadAll();

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncSuccess = result.success;
      _lastSyncMessage = result.message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.40,
        maxChildSize: 0.92,
        builder: (sheetContext, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          children: [
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Add something quickly',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            _addOption(Icons.note, 'Note', 'Write a quick note'),
            _addOption(Icons.task_alt, 'Task', 'Add a new task'),
            _addOption(Icons.attach_money, 'Expense', 'Log an expense'),
            _addOption(Icons.flight, 'Trip', 'Plan a new trip'),
            _addOption(Icons.hotel, 'Hotel', 'Add hotel stay'),
            _addOption(Icons.flight, 'Flight', 'Add flight details'),
            _addOption(Icons.photo_camera, 'Photo', 'Take a photo'),
            _addOption(Icons.inventory_2, 'Packing Item', 'Add packing item'),
            _addOption(Icons.badge, 'Passport/Visa', 'Add document'),
            _addOption(Icons.folder, 'File', 'Add a file'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _quickHotel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const HotelBookingForm(),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _addOption(IconData icon, String label, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(label),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () {
        Navigator.pop(context);
        switch (label) {
          case 'Note':
            _quickNote(context);
            break;
          case 'Task':
            _quickTask(context);
            break;
          case 'Expense':
            _quickExpense(context);
            break;
          case 'Trip':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open the Trips tab to plan a new trip')),
            );
            break;
          case 'Hotel':
            _quickHotel(context);
            break;
          case 'Flight':
          case 'Passport/Visa':
          case 'File':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label — coming soon')),
            );
            break;
          case 'Photo':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo — coming soon')),
            );
            break;
          case 'Packing Item':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Packing — coming soon')),
            );
            break;
        }
      },
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
                      setState(() {});
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
                      setState(() {});
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

  void _quickExpense(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
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
            Text('Quick Expense', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (AED)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount > 0 && titleCtrl.text.isNotEmpty) {
                      final db = DatabaseHelper();
                      db.insert('expenses', {
                        'title': titleCtrl.text,
                        'category': 'other',
                        'amount': amount,
                        'currency': 'AED',
                        'date': DateTime.now().toIso8601String(),
                        'merchant': '',
                        'notes': '',
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense logged')),
                      );
                      setState(() {});
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

  void _showNoteDetail(dynamic note) {
    final n = note as Note;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title.isEmpty ? 'Untitled' : n.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(n.content),
              if (n.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tags: ${n.tags}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTaskDetail(dynamic task) {
    final t = task as Task;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.description?.isNotEmpty == true) Text(t.description!),
              if (t.dueDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Due: ${DateFormat('MMM d, y').format(t.dueDate!)}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPassportDetail(dynamic passport) {
    final p = passport as Passport;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.country),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Number: ${p.passportNumber}'),
              const SizedBox(height: 4),
              Text(
                p.expired
                    ? 'Expired: ${DateFormat('MMM d, y').format(p.expiryDate)}'
                    : 'Expires: ${DateFormat('MMM d, y').format(p.expiryDate)}',
                style: TextStyle(
                  color: p.expired ? Colors.red : (p.expiringSoon ? Colors.orange : Colors.green),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFileDetail(dynamic file) {
    final f = file as AppFile;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f.description?.isNotEmpty == true) Text(f.description!),
              const SizedBox(height: 4),
              Text(
                'Added: ${DateFormat('MMM d, y').format(f.createdAt)}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHotelDetail(dynamic hotelMap) {
    final h = hotelMap as Map<String, dynamic>;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          h['name'] as String? ?? 'Hotel',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((h['address'] as String?)?.isNotEmpty == true)
                Text('Address: ${h['address']}'),
              const SizedBox(height: 4),
              if ((h['city'] as String?)?.isNotEmpty == true ||
                  (h['country'] as String?)?.isNotEmpty == true)
                Text('${h['city']} — ${h['country']}'),
              const SizedBox(height: 4),
              _hotelDetailRow('Check-in', DateFormat('MMM d, y').format(DateTime.tryParse(h['check_in'] as String? ?? '') ?? DateTime.now()), Icons.calendar_today, cs),
              _hotelDetailRow('Check-out', DateFormat('MMM d, y').format(DateTime.tryParse(h['check_out'] as String? ?? '') ?? DateTime.now()), Icons.calendar_today, cs),
              const SizedBox(height: 4),
              if ((h['confirmation_number'] as String?)?.isNotEmpty == true)
                _hotelDetailRow('Confirmation', h['confirmation_number']!, Icons.badge, cs),
              if (((h['cost'] as num?) ?? 0) > 0)
                _hotelDetailRow('Total', '${(h['cost'] as num).toStringAsFixed(2)}  ${h['currency']}', Icons.attach_money, cs),
              if ((h['phone'] as String?)?.isNotEmpty == true)
                _hotelDetailRow('Phone', h['phone']!, Icons.phone, cs),
              if ((h['booking_url'] as String?)?.isNotEmpty == true)
                _hotelDetailRow('Booking', h['booking_url']!, Icons.link, cs),
            ],
          ),
        ),
        actions: [
          if ((h['booking_url'] as String?)?.isNotEmpty == true)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open booking URL (feature coming)')),
                );
              },
              child: Text(
                'Open booking',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hotelDetailRow(String label, String value, IconData icon, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
