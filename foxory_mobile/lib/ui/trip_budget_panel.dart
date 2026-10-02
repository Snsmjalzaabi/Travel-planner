import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/budget_service.dart';
import '../services/currency_service.dart';

/// Live budget readout for one trip: spent, remaining, per-person and
/// per-day, plus a category breakdown. Reads straight from the expenses
/// table so it updates the moment something is added or edited.
class TripBudgetPanel extends StatefulWidget {
  final Trip trip;
  final List<Expense> allExpenses;
  final VoidCallback? onChanged;

  const TripBudgetPanel({
    super.key,
    required this.trip,
    required this.allExpenses,
    this.onChanged,
  });

  @override
  State<TripBudgetPanel> createState() => _TripBudgetPanelState();
}

class _TripBudgetPanelState extends State<TripBudgetPanel> {
  BudgetBreakdown? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant TripBudgetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute when the expense list identity changes.
    if (!identical(oldWidget.allExpenses, widget.allExpenses)) _compute();
  }

  Future<void> _compute() async {
    final data = await const BudgetService().build(
      widget.trip,
      widget.allExpenses,
      currency: CurrencyService(),
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading || _data == null) {
      return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    }

    final d = _data!;
    final cur = widget.trip.baseCurrency;
    final remainingColor = !d.hasBudget
        ? cs.onSurface.withValues(alpha: 0.7)
        : d.remaining < 0
            ? Colors.red
            : d.remaining < d.budget * 0.2
                ? Colors.orange
                : Colors.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.isOverBudget
              ? Colors.red.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text('Budget', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (d.isOverBudget)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text('OVER BUDGET', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Big figures
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _stat('Spent', formatMoney(d.spent, cur), cs.onSurface)),
              Expanded(child: _stat('Remaining', formatMoney(d.remaining, cur), remainingColor)),
              Expanded(child: _stat('Budget', d.hasBudget ? formatMoney(d.budget, cur) : 'Not set', cs.onSurface)),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          if (d.hasBudget) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (d.usedFraction ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(
                  d.remaining < 0 ? Colors.red : (d.remaining < d.budget * 0.2 ? Colors.orange : cs.primary),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(d.usedFraction! * 100).round()}% of budget used',
              style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              d.spent > 0
                  ? 'No budget set on this trip, but ${formatMoney(d.spent, cur)} has been logged against it.'
                  : 'Set a budget on this trip to track spending against it.',
              style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 14),
          ],

          // Per person / per day
          Row(
            children: [
              _pill(Icons.people_outline, 'Per person', formatMoney(d.perTravellerSpent, cur), cs),
              const SizedBox(width: 8),
              if (d.perDaySpent != null)
                _pill(Icons.calendar_today_outlined, 'Per day', formatMoney(d.perDaySpent!, cur), cs),
            ],
          ),

          // Category breakdown
          if (d.byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Where it went', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.8))),
            const SizedBox(height: 8),
            ..._categoryRows(d, cur, cs),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _pill(IconData icon, String label, String value, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55))),
              ],
            ),
            const SizedBox(height: 3),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryRows(BudgetBreakdown d, String cur, ColorScheme cs) {
    final sorted = d.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (a, b) => a + b.value);

    return sorted.take(6).map((e) {
      final pct = total > 0 ? e.value / total : 0.0;
      final color = categoryColor(e.key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _categoryLabel(e.key),
                    style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${(pct * 100).round()}%', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: Text(
                    formatMoney(e.value, cur),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 3,
                backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color categoryColor(String c) => switch (c) {
        'food' => Colors.orange,
        'transport' || 'transportation' => Colors.blue,
        'accommodation' => Colors.purple,
        'activities' => Colors.green,
        'shopping' => Colors.pink,
        'groceries' => Colors.teal,
        _ => Colors.grey,
      };

  String _categoryLabel(String c) => switch (c) {
        'transportation' => 'Transportation',
        'transport' => 'Transportation',
        'food' => 'Food',
        'accommodation' => 'Accommodation',
        'activities' => 'Activities',
        'shopping' => 'Shopping',
        'groceries' => 'Groceries',
        _ => 'Other',
      };
}
