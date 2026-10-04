import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../services/budget_service.dart';
import '../services/currency_service.dart';

/// Split a trip's budget across categories and see the maths.
///
/// You are the one holding the budget, so this never invents a split - you
/// set what each category gets, and it shows what that leaves you.
class BudgetBreakdownScreen extends StatefulWidget {
  final Trip trip;

  const BudgetBreakdownScreen({super.key, required this.trip});

  @override
  State<BudgetBreakdownScreen> createState() => _BudgetBreakdownScreenState();
}

class _BudgetBreakdownScreenState extends State<BudgetBreakdownScreen> {
  final _service = const BudgetService();
  Map<String, double> _allocations = {};
  BudgetBreakdown? _totals;
  bool _loading = true;

  static const _categories = [
    'transportation',
    'food',
    'accommodation',
    'activities',
    'shopping',
    'groceries',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tripId = widget.trip.id;
    if (tripId == null) return;

    final helper = DatabaseHelper();
    final allocations = await helper.getBudgetAllocations(tripId);
    final db = await helper.database;
    final expenseRows = await db.query('expenses', where: 'deleted_at IS NULL');
    final expenses = expenseRows.map(Expense.fromMap).toList();
    final totals = await _service.build(widget.trip, expenses, currency: CurrencyService());

    if (!mounted) return;
    setState(() {
      _allocations = allocations;
      _totals = totals;
      _loading = false;
    });
  }

  Future<void> _set(String category, double amount) async {
    final tripId = widget.trip.id;
    if (tripId == null) return;
    await DatabaseHelper().setBudgetAllocation(tripId, category, amount);
    await _load();
  }

  String _money(double v) => formatMoney(v, widget.trip.baseCurrency);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading || _totals == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget breakdown')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totals = _totals!;
    final rows = _service.categoryBreakdown(widget.trip, totals, _allocations);
    final allocated = _service.totalAllocated(_allocations);
    final unassigned = _service.unassigned(totals, _allocations);
    final overAllocated = unassigned < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget breakdown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _summaryCard(cs, totals, allocated, unassigned, overAllocated),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Set aside per category', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a category to set what you are holding for it.',
            style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          ..._categories.map((c) => _categoryRow(cs, c, rows, totals, allocated)),
          if (rows.any((r) => r.unbudgeted)) ...[
            const SizedBox(height: 10),
            _warning(cs, rows.where((r) => r.unbudgeted)),
          ],
          if (totals.isOverBudget) ...[
            const SizedBox(height: 10),
            _overBudget(cs, totals),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(ColorScheme cs, BudgetBreakdown totals, double allocated, double unassigned, bool over) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _line('Trip budget', _money(totals.budget), cs.onSurface)),
              Expanded(child: _line('Spent', _money(totals.spent), cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _line(
                  'Set aside',
                  _money(allocated),
                  allocated > 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Expanded(
                child: _line(
                  over ? 'Over by' : 'Still free',
                  _money(unassigned.abs()),
                  over ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              // Allocation as a share of the trip budget, so over-allocation
              // is visible rather than silently clamped.
              value: totals.budget > 0 ? (allocated / totals.budget).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(over ? Colors.red : cs.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totals.budget > 0
                ? '${(allocated / totals.budget * 100).round()}% of the budget assigned'
                : 'No trip budget set - set one on the trip.',
            style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: color.withValues(alpha: 0.65))),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _categoryRow(ColorScheme cs, String category, List<CategoryBudget> rows, BudgetBreakdown totals, double totalAllocated) {
    CategoryBudget match(String c) =>
        rows.firstWhere((r) => r.category == c, orElse: () => CategoryBudget(category: c, allocated: 0, spent: 0));

    final row = match(category);
    final spent = row.spent;
    final color = _categoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _editAllocation(category, row),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: row.isOver ? Colors.red.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _label(category),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 15, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              if (row.hasAllocation) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (row.usedFraction ?? 0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(row.isOver ? Colors.red : color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_money(spent)} of ${_money(row.allocated)} spent'
                  '  •  ${row.remaining >= 0 ? '${_money(row.remaining)} left' : '${_money(row.remaining.abs())} over'}'
                  '  •  ${(row.shareOf(totalAllocated) * 100).round()}% of plan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: row.isOver ? Colors.red : cs.onSurface.withValues(alpha: 0.6),
                    fontWeight: row.isOver ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ] else ...[
                Text(
                  spent > 0
                      ? 'Not budgeted — ${_money(spent)} spent anyway'
                      : 'Not set',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: spent > 0 ? Colors.orange : cs.onSurface.withValues(alpha: 0.45),
                    fontWeight: spent > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAllocation(String category, CategoryBudget row) async {
    final controller = TextEditingController(
      text: row.allocated > 0 ? row.allocated.toStringAsFixed(0) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_label(category)} budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount in ${widget.trip.baseCurrency}',
                border: const OutlineInputBorder(),
              ),
            ),
            if (row.spent > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Already spent: ${_money(row.spent)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          if (row.hasAllocation)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              child: const Text('Clear'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    await _set(category, result < 0 ? 0 : result);
  }

  Widget _warning(ColorScheme cs, Iterable<CategoryBudget> unbudgeted) {
    final lines = unbudgeted.map((r) => '${_label(r.category)} ${_money(r.spent)}').join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Spent outside your plan: $lines',
              style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overBudget(ColorScheme cs, BudgetBreakdown totals) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Over the whole trip budget by ${_money(totals.remaining.abs())}. '
              '${_money(totals.perTravellerSpent)} per traveller so far.',
              style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String c) => switch (c) {
        'transportation' => 'Transportation',
        'transport' => 'Transportation',
        'food' => 'Food',
        'accommodation' => 'Accommodation',
        'activities' => 'Activities',
        'shopping' => 'Shopping',
        'groceries' => 'Groceries',
        'other' => 'Other',
        _ => c,
      };

  Color _categoryColor(String c) => switch (c) {
        'transport' || 'transportation' => Colors.blue,
        'food' => Colors.orange,
        'accommodation' => Colors.purple,
        'activities' => Colors.green,
        'shopping' => Colors.pink,
        'groceries' => Colors.teal,
        _ => Colors.grey,
      };
}
