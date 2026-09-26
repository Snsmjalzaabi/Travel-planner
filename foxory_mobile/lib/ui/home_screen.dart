import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../widgets/quick_capture_widget.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good morning';
    } else if (hour < 17) {
      _greeting = 'Good afternoon';
    } else {
      _greeting = 'Good evening';
    }
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();

    // Upcoming trips
    final trips = await db.query(
      'trips',
      where: 'departure >= ? AND status != ?',
      whereArgs: [now.toIso8601String(), 'COMPLETED'],
      orderBy: 'departure ASC',
      limit: 3,
    );
    _upcomingTrips = trips.map((m) => Trip.fromMap(m)).toList();

    // Recent trips (last 5)
    final recentTrips = await db.query(
      'trips',
      orderBy: 'updated_at DESC',
      limit: 5,
    );
    _recentTrips = recentTrips.map((m) => Trip.fromMap(m)).toList();

    // Recent expenses
    final expenses = await db.query(
      'expenses',
      orderBy: 'date DESC',
      limit: 5,
    );
    _recentExpenses = expenses.map((m) => Expense.fromMap(m)).toList();

    // Pending tasks
    final tasks = await db.query(
      'tasks',
      where: "status = ? OR (status = ? AND due_date <= ?)",
      whereArgs: ['todo', 'in_progress', now.toIso8601String()],
      orderBy: 'priority DESC, due_date ASC',
      limit: 5,
    );
    _pendingTasks = tasks.map((m) => Task.fromMap(m)).toList();

    // Expiring passports
    final passports = await db.query(
      'passports',
      where: 'expiring_soon = ? OR expired = ?',
      whereArgs: [1, 1],
      limit: 3,
    );
    _passports = passports.map((m) => Passport.fromMap(m)).toList();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            SliverToBoxAdapter(
              child: QuickCaptureWidget(
                onCapture: _handleQuickCapture,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate([
                  if (_upcomingTrips.isNotEmpty) ...[
                    _buildSectionHeader('Upcoming Trips'),
                    ..._upcomingTrips.map((t) => _buildTripCard(t)),
                    const SizedBox(height: 16),
                  ],
                  if (_pendingTasks.isNotEmpty) ...[
                    _buildSectionHeader('Pending Tasks'),
                    ..._pendingTasks.map((t) => _buildTaskCard(t)),
                    const SizedBox(height: 16),
                  ],
                  if (_recentExpenses.isNotEmpty) ...[
                    _buildSectionHeader('Recent Expenses'),
                    ..._recentExpenses.map((e) => _buildExpenseCard(e)),
                    const SizedBox(height: 16),
                  ],
                  if (_passports.isNotEmpty) ...[
                    _buildSectionHeader('Document Alerts'),
                    ..._passports.map((p) => _buildPassportAlertCard(p)),
                    const SizedBox(height: 16),
                  ],
                  if (_recentTrips.isNotEmpty) ...[
                    _buildSectionHeader('Recent Activity'),
                    ..._recentTrips.map((t) => _buildRecentTripCard(t)),
                    const SizedBox(height: 16),
                  ],
                  if (_upcomingTrips.isEmpty &&
                      _pendingTasks.isEmpty &&
                      _recentExpenses.isEmpty &&
                      _passports.isEmpty &&
                      _recentTrips.isEmpty)
                    _buildEmptyState(),
                ]),
              ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateTime.now().toString().split(' ')[0],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(trip.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.originName} → ${trip.destName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('MMM d').format(trip.departure)} – ${DateFormat('MMM d').format(trip.returnDate)} · ${trip.nights} nights · ${trip.travelers} traveler${trip.travelers > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
              if (trip.distance != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.distance!.toStringAsFixed(0)} km · ${trip.travelTime ?? 'TBD'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ],
              if (trip.totalBudget > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Budget: ${NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'IDEA':
        color = Colors.grey;
        break;
      case 'PLANNING':
        color = Colors.blue;
        break;
      case 'READY':
        color = Colors.orange;
        break;
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'COMPLETED':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _currencySymbol(String currency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'INR': '₹',
      'JPY': '¥',
      'CNY': '¥',
      'KRW': '₩',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'CAD': 'C\$',
    };
    return symbols[currency] ?? currency;
  }

  Widget _buildTaskCard(Task task) {
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
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _taskPriorityColor(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, y').format(task.dueDate!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: task.isOverdue ? Colors.red : Colors.grey,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Checkbox(
                value: task.isCompleted,
                onChanged: (v) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _taskPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  Widget _buildExpenseCard(Expense expense) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _expenseCategoryColor(expense.category).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _expenseCategoryIcon(expense.category),
                  color: _expenseCategoryColor(expense.category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      expense.merchant ?? expense.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                NumberFormat.currency(symbol: _currencySymbol(expense.currency)).format(expense.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _expenseCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'accommodation':
        return Colors.purple;
      case 'activities':
        return Colors.green;
      case 'shopping':
        return Colors.pink;
      case 'other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _expenseCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'activities':
        return Icons.event;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.receipt;
    }
  }

  Widget _buildPassportAlertCard(Passport passport) {
    final isExpired = passport.expired;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: (isExpired ? Colors.red.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.badge,
                  color: (isExpired ? Colors.red : Colors.orange),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passport.country,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      passport.passportNumber,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired
                          ? 'Expired on ${DateFormat('MMM d, y').format(passport.expiryDate)}'
                          : 'Expires ${DateFormat('MMM d, y').format(passport.expiryDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTripCard(Trip trip) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flight,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${trip.originName} → ${trip.destName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('MMM d').format(trip.departure),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (trip.status == 'COMPLETED')
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.travel_explore,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No active trips',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a trip to start planning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note saved')),
            );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task added')),
            );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense logged')),
            );
            _loadData();
          }
        }
        break;
      case 'trip':
        // Handled by the widget — opens create trip dialog
        break;
      case 'photo':
        break;
      case 'flight':
        break;
      case 'hotel':
        break;
      default:
        break;
    }
  }
}
