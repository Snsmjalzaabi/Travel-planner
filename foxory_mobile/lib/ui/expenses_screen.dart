import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as _math;
import '../models/models.dart';
import '../services/currency_service.dart';
import '../core/database_helper.dart';
import 'expense_form_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _displayCurrency = 'AED';
  int? _tripFilter;
  final Map<String, double> _convertedAmounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('expenses', orderBy: 'created_at DESC');
    setState(() {
      _expenses = rows.map((m) => Expense.fromMap(m)).toList();
      _isLoading = false;
    });
    await _refreshConvertedAmounts();
  }

  void _add() => _showExpenseForm();

  Future<void> _showExpenseForm({Expense? expense}) async {
    final saved = await showExpenseSheet(context, expense: expense, initialTripId: _tripFilter);
    if (saved) await _load();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || expense.id == null) return;
    await DatabaseHelper().delete('expenses', where: 'id = ?', whereArgs: [expense.id]);
    await _load();
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _displayCurrency,
              items: ['AED', 'USD', 'EUR', 'GBP', 'SAR', 'INR', 'UZS']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _displayCurrency = v);
                await _refreshConvertedAmounts();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _add,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showChart(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No expenses yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text('Tap + to add your first expense', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _expenses.length,
                    itemBuilder: (c, i) => _expenseCard(context, _expenses[i]),
                  ),
                ),
    );
  }

  Widget _expenseCard(BuildContext context, Expense expense) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _categoryColor(expense.category).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_categoryIcon(expense.category), color: _categoryColor(expense.category), size: 20),
        ),
        title: Text(
          expense.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          expense.category == 'other' && (expense.notes?.isNotEmpty ?? false)
              ? '${expenseCategoryLabel(expense.category)} • ${expense.notes}'
              : expenseCategoryLabel(expense.category),
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDisplayedAmount(expense),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.primary),
                ),
                if (expense.currency != _displayCurrency)
                  Text(
                    '${NumberFormat.currency(symbol: _currencySymbol(expense.currency)).format(expense.amount)} original',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit') _showExpenseForm(expense: expense);
                if (value == 'delete') _deleteExpense(expense);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => _showExpenseForm(expense: expense),
        onLongPress: () => _deleteExpense(expense),
      ),
    );
  }

  String _formatDisplayedAmount(Expense expense) {
    final key = _expenseConversionKey(expense);
    final amount = expense.currency == _displayCurrency
        ? expense.amount
        : (_convertedAmounts[key] ?? expense.amount);
    return NumberFormat.currency(symbol: _currencySymbol(_displayCurrency)).format(amount);
  }

  String _expenseConversionKey(Expense e) => '${e.id ?? e.createdAt.millisecondsSinceEpoch}_${e.currency}_$_displayCurrency';

  Future<void> _refreshConvertedAmounts() async {
    if (_expenses.isEmpty) return;
    final service = CurrencyService();
    final next = <String, double>{};
    for (final expense in _expenses) {
      final key = _expenseConversionKey(expense);
      if (expense.currency == _displayCurrency) {
        next[key] = expense.amount;
      } else {
        next[key] = await service.convert(expense.amount, expense.currency, _displayCurrency);
      }
    }
    if (!mounted) return;
    setState(() => _convertedAmounts
      ..clear()
      ..addAll(next));
  }

  Widget _showChart(BuildContext context) {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No expenses to chart yet')));
      return const SizedBox();
    }

    // Group expenses by category
    final Map<String, double> categoryTotals = {};
    for (final e in _expenses) {
      final cat = e.category.isNotEmpty ? e.category : 'other';
      final key = _expenseConversionKey(e);
      final displayAmount = e.currency == _displayCurrency ? e.amount : (_convertedAmounts[key] ?? e.amount);
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + displayAmount;
    }

    final entries = categoryTotals.entries.toList();
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spending by Category', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Total: ${NumberFormat.currency(symbol: _currencySymbol(_displayCurrency)).format(total)}', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _SimplePieChart(entries: entries.map((e) => MapEntry(e.key, e.value)).toList(), total: total),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entries.map((e) {
                      final color = _categoryColor(e.key);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${e.key}: ${NumberFormat.currency(symbol: _currencySymbol(_displayCurrency)).format(e.value)}',
                              style: GoogleFonts.inter(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return const SizedBox();
  }



  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport':
      case 'transportation': return Colors.blue;
      case 'accommodation': return Colors.purple;
      case 'activities': return Colors.green;
      case 'shopping': return Colors.pink;
      case 'groceries': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport':
      case 'transportation': return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'activities': return Icons.event;
      case 'shopping': return Icons.shopping_bag;
      case 'groceries': return Icons.local_grocery_store;
      default: return Icons.receipt;
    }
  }

  String _currencySymbol(String currency) {
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
    return symbols[currency] ?? currency;
  }
}

class _SimplePieChart extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;

  const _SimplePieChart({required this.entries, required this.total});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty || total <= 0) return const SizedBox();
    return CustomPaint(size: const Size(200, 200), painter: _PieChartPainter(entries: entries, total: total));
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;

  _PieChartPainter({required this.entries, required this.total});

  static const _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    double startAngle = -90 * _pi / 180;

    for (final entry in entries) {
      final sweepAngle = (entry.value / total) * 2 * _pi;
      final color = _categoryColor(entry.key);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.butt
          ..color = color,
      );
      // Percentage label
      final midAngle = startAngle + sweepAngle / 2;
      final labelR = radius * 0.65;
      final lx = center.dx + cos(midAngle) * labelR;
      final ly = center.dy + sin(midAngle) * labelR;
      final pct = ((entry.value / total) * 100).toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: pct + '%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      startAngle += sweepAngle;
    }
    // Center hole
    canvas.drawCircle(center, radius * 0.38, Paint()..color = Colors.white);
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport':
      case 'transportation': return Colors.blue;
      case 'accommodation': return Colors.purple;
      case 'activities': return Colors.green;
      case 'shopping': return Colors.pink;
      case 'groceries': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double cos(double x) => _math.cos(x);
double sin(double x) => _math.sin(x);
