import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../widgets/quick_capture_widget.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _upcomingTrips = [];
  List<Trip> _recentTrips = [];
  List<Expense> _recentExpenses = [];
  List<Task> _pendingTasks = [];
  List<Passport> _passports = [];
  bool _isLoading = true;
  String _greeting = '';
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setGreeting() {
    final h = DateTime.now().hour;
    setState(() {
      _greeting = h < 12
          ? 'Good morning'
          : h < 17
              ? 'Good afternoon'
              : 'Good evening';
    });
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final trips = await db.query(
      'trips',
      where: 'departure >= ? AND status != ?',
      whereArgs: [now.toIso8601String(), 'COMPLETED'],
      orderBy: 'departure ASC',
      limit: 3,
    );
    _upcomingTrips = trips.map((m) => Trip.fromMap(m)).toList();
    final trips2 = await db.query('trips', orderBy: 'updated_at DESC', limit: 5);
    _recentTrips = trips2.map((m) => Trip.fromMap(m)).toList();
    final exp = await db.query('expenses', orderBy: 'date DESC', limit: 5);
    _recentExpenses = exp.map((m) => Expense.fromMap(m)).toList();
    final tasks = await db.query(
      'tasks',
      where: "status = 'todo' OR (status = 'in_progress' AND due_date <= ?)",
      whereArgs: [now.toIso8601String()],
      orderBy: 'priority DESC, due_date ASC',
      limit: 5,
    );
    _pendingTasks = tasks.map((m) => Task.fromMap(m)).toList();
    final passports = await db.query(
      'passports',
      where: 'expiring_soon = 1 OR expired = 1',
      limit: 3,
    );
    _passports = passports.map((m) => Passport.fromMap(m)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: QuickCaptureWidget(onCapture: _handleQuickCapture),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else
              SliverList(
                delegate: SliverChildListDelegate([
                  if (_upcomingTrips.isNotEmpty) ...[
                    _sectionHeader('Upcoming Trips'),
                    ..._upcomingTrips.map((t) => _tripCard(t)).toList(),
                    const SizedBox(height: 16),
                  ],
                  if (_pendingTasks.isNotEmpty) ...[
                    _sectionHeader('Pending Tasks'),
                    ..._pendingTasks.map((t) => _taskCard(t)).toList(),
                    const SizedBox(height: 16),
                  ],
                  if (_recentExpenses.isNotEmpty) ...[
                    _sectionHeader('Recent Expenses'),
                    ..._recentExpenses.map((e) => _expenseCard(e)).toList(),
                    const SizedBox(height: 16),
                  ],
                  if (_passports.isNotEmpty) ...[
                    _sectionHeader('Document Alerts'),
                    ..._passports.map((p) => _passportCard(p)).toList(),
                    const SizedBox(height: 16),
                  ],
                  if (_recentTrips.isNotEmpty) ...[
                    _sectionHeader('Recent Activity'),
                    ..._recentTrips.map((t) => _recentTripCard(t)).toList(),
                    const SizedBox(height: 16),
                  ],
                  if (_upcomingTrips.isEmpty &&
                      _pendingTasks.isEmpty &&
                      _recentExpenses.isEmpty &&
                      _passports.isEmpty &&
                      _recentTrips.isEmpty)
                    _emptyState(),
                ]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surface,
          ],
        ),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.12))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(DateTime.now().toString().split(' ')[0], style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_outlined, size: 20),
                ),
                onPressed: () => _fireAlertsNow(),
                tooltip: 'Notifications',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tripCard(Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysUntil = trip.departure.difference(DateTime.now()).inDays;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _showTripDetail(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(trip.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.flight, color: _statusColor(trip.status), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${trip.originName} → ${trip.destName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, size: 18),
                    itemBuilder: (c) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showTripDetail(trip);
                      } else if (value == 'delete') {
                        _deleteTrip(trip);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(Icons.calendar_today, DateFormat('MMM d').format(trip.departure)),
                  const SizedBox(width: 6),
                  _chip(Icons.people, '${trip.travelers} traveler${trip.travelers > 1 ? 's' : ''}'),
                  const SizedBox(width: 6),
                  _chip(Icons.local_shipping, trip.transportLabel),
                ],
              ),
              if (trip.distance != null && trip.distance! > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${trip.distance!.toStringAsFixed(0)} km', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    if (trip.travelTime != null) ...[
                      const SizedBox(width: 6),
                      Text(trip.travelTime!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _statusChip(trip.status),
                  if (trip.status == 'COMPLETED') ...[
                    const SizedBox(width: 6),
                    Text('${trip.nights} nights', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                  const Spacer(),
                  if (trip.totalBudget > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Budget', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        Text(_fmtCurrency(trip.baseCurrency, trip.totalBudget), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              if (daysUntil > 0 && trip.status != 'COMPLETED') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (daysUntil <= 7 ? Colors.orange : Colors.blue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    daysUntil <= 0 ? 'Departed' : daysUntil == 1 ? 'Departs tomorrow!' : 'Departs in $daysUntil days',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: daysUntil <= 7 ? Colors.orange : Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Task task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: _priorityColor(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (task.dueDate != null)
                      Text(DateFormat('MMM d, y').format(task.dueDate!), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: task.isOverdue ? Colors.red : Colors.grey)),
                  ],
                ),
              ),
              Checkbox(value: task.isCompleted, onChanged: (v) {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expenseCard(Expense expense) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _expenseColor(expense.category).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_expenseIcon(expense.category), color: _expenseColor(expense.category), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(expense.merchant ?? expense.category, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              Text(_fmtCurrency(expense.currency, expense.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passportCard(Passport passport) {
    final isExpired = passport.expired;
    final accent = isExpired ? Colors.red : (passport.expiringSoon ? Colors.orange : Colors.green);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: accent.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.badge, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passport.country, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(passport.passportNumber, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      isExpired ? 'Expired ${DateFormat('MMM d, y').format(passport.expiryDate)}' : passport.expiringSoon ? 'Expires ${DateFormat('MMM d, y').format(passport.expiryDate)}' : 'Valid until ${DateFormat('MMM d, y').format(passport.expiryDate)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: accent),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentTripCard(Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flight, color: colorScheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${trip.originName} → ${trip.destName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('MMM d').format(trip.departure), style: Theme.of(context).textTheme.bodySmall),
                  if (trip.status == 'COMPLETED') const Icon(Icons.check_circle, color: Colors.green, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey),
          const SizedBox(width: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _emptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No active trips', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Create a trip to start planning', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IDEA': return Colors.grey;
      case 'PLANNING': return Colors.blue;
      case 'READY': return Colors.orange;
      case 'ACTIVE': return Colors.green;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low: return Colors.grey;
      case TaskPriority.medium: return Colors.orange;
      case TaskPriority.high: return Colors.red;
    }
  }

  Color _expenseColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport': return Colors.blue;
      case 'accommodation': return Colors.purple;
      case 'activities': return Colors.green;
      case 'shopping': return Colors.pink;
      default: return Colors.grey;
    }
  }

  IconData _expenseIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'activities': return Icons.event;
      case 'shopping': return Icons.shopping_bag;
      default: return Icons.receipt;
    }
  }

  String _fmtCurrency(String currency, double amount) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'INR': '₹',
      'UZS': 'soʻm',
      'JPY': '¥',
      'CNY': '¥',
      'KRW': '₩',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'CAD': 'C\$',
    };
    return '${symbols[currency] ?? currency}${amount.toStringAsFixed(0)}';
  }

  void _showTripDetail(Trip trip) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip detail — coming soon')),
    );
  }

  void _deleteTrip(Trip trip) async {
    final db = DatabaseHelper();
    await db.delete('trips', where: 'id = ?', whereArgs: [trip.id]);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${trip.name} deleted')),
      );
    }
  }

  void _handleQuickCapture(String type, {String? text, List<String>? tags}) {
    final db = DatabaseHelper();
    switch (type) {
      case 'note':
        if (text != null && text.isNotEmpty) {
          db.insert('notes', {
            'title': text.split('\n').first.trim(),
            'content': text,
            'tags': tags?.join(', ') ?? '',
            'category': 'quick',
            'priority': 0,
            'is_pinned': 0,
            'is_archived': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
            _loadData();
          }
        }
        break;
      case 'task':
        if (text != null && text.isNotEmpty) {
          db.insert('tasks', {
            'title': text,
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added')));
            _loadData();
          }
        }
        break;
      case 'expense':
        if (text != null && text.isNotEmpty) {
          final parts = text.split(RegExp(r'\s+'));
          final amount = double.tryParse(parts[0]) ?? 0;
          final desc = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          db.insert('expenses', {
            'title': desc,
            'category': 'other',
            'amount': amount,
            'currency': 'AED',
            'date': DateTime.now().toIso8601String(),
            'merchant': '',
            'notes': '',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense logged')));
            _loadData();
          }
        }
        break;
      default:
        break;
    }
  }

  void _fireAlertsNow() async {
    final count = await AlertService.instance?.fireAlertsNow() ?? 0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count alert${count == 1 ? "" : "s"} fired')),
      );
    }
  }
}
