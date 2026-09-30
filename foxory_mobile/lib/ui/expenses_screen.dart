import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as _math;
import '../models/models.dart';
import '../services/currency_service.dart';
import '../core/database_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

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
  }

  void _add() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String currency = 'AED';
    final db = DatabaseHelper();
    final currencyService = CurrencyService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 16, left: 16, right: 16),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text('Add Expense', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: ['AED', 'USD', 'EUR', 'GBP', 'SAR', 'INR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => v != null ? setModalState(() => currency = v) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!mounted) return;
                    final title = titleCtrl.text.trim();
                    final amountStr = amountCtrl.text.trim();
                    if (title.isEmpty || amountStr.isEmpty) return;

                    final amount = double.tryParse(amountStr);
                    if (amount == null || amount <= 0) return;

                    final baseAmount = await currencyService.convert(amount, currency, 'USD');

                    final now = DateTime.now().toIso8601String();
                    final row = {
                      'title': title,
                      'category': 'other',
                      'amount': amount,
                      'currency': currency,
                      'base_amount': baseAmount,
                      'date': now,
                      'created_at': now,
                      'updated_at': now,
                      'sync_enabled': 1,
                    };
                    await db.insert('expenses', row);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
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
          expense.merchant ?? expense.category,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          NumberFormat.currency(symbol: _currencySymbol(expense.currency)).format(expense.amount),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.primary),
        ),
        onTap: () {},
      ),
    );
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
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
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
                  Text('Total: ${NumberFormat.currency(symbol: '\$').format(total)}', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
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
                              '${e.key}: ${NumberFormat.currency(symbol: '\$').format(e.value)}',
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
      case 'transport': return Colors.blue;
      case 'accommodation': return Colors.purple;
      case 'activities': return Colors.green;
      case 'shopping': return Colors.pink;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'activities': return Icons.event;
      case 'shopping': return Icons.shopping_bag;
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
      case 'transport': return Colors.blue;
      case 'accommodation': return Colors.purple;
      case 'activities': return Colors.green;
      case 'shopping': return Colors.pink;
      default: return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double cos(double x) => _math.cos(x);
double sin(double x) => _math.sin(x);
