import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/database_helper.dart';
import '../models/models.dart';
import '../services/currency_service.dart';
import '../services/budget_service.dart';

/// The one expense form. Both the Expenses tab and More -> Quick Add use this,
/// so category, trip and currency behave identically everywhere.
///
/// Returns true when an expense was written, so callers can refresh.
Future<bool> showExpenseSheet(
  BuildContext context, {
  Expense? expense,
  int? initialTripId,
}) async {
  final db = DatabaseHelper();
  final currencyService = CurrencyService();

  final titleCtrl = TextEditingController(text: expense?.title ?? '');
  final amountCtrl = TextEditingController(
    text: expense == null ? '' : expense.amount.toStringAsFixed(2),
  );
  final otherCommentCtrl = TextEditingController(text: expense?.notes ?? '');
  String currency = expense?.currency ?? 'AED';
  String category = normalizeExpenseCategory(expense?.category ?? 'transportation');
  final conn = await db.database;
  final tripRows = await conn.query(
    'trips',
    where: 'deleted_at IS NULL',
    orderBy: 'departure ASC',
  );
  final trips = tripRows.map(Trip.fromMap).toList();

  // Expenses used to default to "No trip", which meant they counted towards
  // no budget at all. Fall back to the trip you are actually on, or the next
  // one starting, so spend lands where it belongs by default.
  int? tripId = expense?.tripId ?? initialTripId ?? defaultTripFor(trips)?.id;

  // Live budget context for the selected trip, so it is obvious which budget
  // this expense is being charged against before saving.
  final existingRows = await conn.query('expenses', where: 'deleted_at IS NULL');
  final allExpenses = existingRows.map(Expense.fromMap).toList();
  final fx = CurrencyService();

  Future<BudgetBreakdown?> budgetFor(int? id) async {
    if (id == null) return null;
    Trip? match;
    for (final x in trips) {
      if (x.id == id) match = x;
    }
    if (match == null) return null;
    return const BudgetService().build(match, allExpenses, currency: fx);
  }

  if (!context.mounted) return false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 16, left: 16, right: 16),
      child: StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                expense == null ? 'Add Expense' : 'Edit Expense',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                autofocus: expense == null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Expense Type', border: OutlineInputBorder()),
                items: kExpenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(expenseCategoryLabel(c))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => category = v);
                },
              ),
              if (category == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: otherCommentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comment for Other',
                    hintText: 'Example: visa fee, gift, emergency item...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
              if (trips.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: trips.any((x) => x.id == tripId) ? tripId : null,
                  decoration: const InputDecoration(
                    labelText: 'Trip',
                    helperText: 'Charged against this trip budget',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No trip (untracked)')),
                    ...trips.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setModalState(() => tripId = v),
                ),
                const SizedBox(height: 8),
                FutureBuilder<BudgetBreakdown?>(
                  future: budgetFor(tripId),
                  builder: (context, snap) {
                    final b = snap.data;
                    if (b == null) return const SizedBox.shrink();
                    var currency = trips.first.baseCurrency;
                    for (final x in trips) {
                      if (x.id == tripId) currency = x.baseCurrency;
                    }
                    return _BudgetContext(
                      spent: b.spent,
                      budget: b.budget,
                      remaining: b.remaining,
                      currency: currency,
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                      items: kExpenseCurrencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => {
                        if (v != null) setModalState(() => currency = v)
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final amountStr = amountCtrl.text.trim().replaceAll(',', '');
                    final otherComment = otherCommentCtrl.text.trim();
                    if (title.isEmpty || amountStr.isEmpty) return;
                    if (category == 'other' && otherComment.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Add a comment when using Other')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountStr);
                    if (amount == null || amount <= 0) return;

                    final baseAmount = await currencyService.convert(amount, currency, 'USD');
                    final now = DateTime.now().toIso8601String();
                    final row = {
                      'trip_id': tripId,
                      'title': title,
                      'category': category,
                      'amount': amount,
                      'currency': currency,
                      'base_amount': baseAmount,
                      'date': expense?.date.toIso8601String() ?? now,
                      'notes': category == 'other' ? otherComment : null,
                      'created_at': expense?.createdAt.toIso8601String() ?? now,
                      'updated_at': now,
                      'sync_enabled': 1,
                    };

                    if (expense?.id == null) {
                      await db.insert('expenses', row);
                    } else {
                      await db.update('expenses', row, where: 'id = ?', whereArgs: [expense!.id]);
                    }

                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text(expense == null ? 'Save' : 'Update'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );

  return saved == true;
}

const List<String> kExpenseCategories = [
  'transportation',
  'food',
  'accommodation',
  'activities',
  'shopping',
  'groceries',
  'other',
];

const List<String> kExpenseCurrencies = ['AED', 'USD', 'EUR', 'GBP', 'SAR', 'INR', 'UZS'];

String expenseCategoryLabel(String category) => switch (category) {
      'transportation' => 'Transportation',
      'transport' => 'Transportation',
      'food' => 'Food',
      'accommodation' => 'Accommodation',
      'activities' => 'Activities',
      'shopping' => 'Shopping',
      'groceries' => 'Groceries',
      'other' => 'Other',
      _ => category.isEmpty ? 'Other' : category,
    };

/// Maps legacy/loose values onto the canonical set.
String normalizeExpenseCategory(String category) {
  final c = category.toLowerCase().trim();
  if (c == 'transport') return 'transportation';
  if (kExpenseCategories.contains(c)) return c;
  return 'other';
}

/// Shows what the selected trip's budget looks like right now, so it is clear
/// which budget this expense is hitting before you save it.
class _BudgetContext extends StatelessWidget {
  final double spent;
  final double budget;
  final double remaining;
  final String currency;

  const _BudgetContext({
    required this.spent,
    required this.budget,
    required this.remaining,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget > 0;
    final over = hasBudget && remaining < 0;
    final color = !hasBudget
        ? Colors.grey
        : over
            ? Colors.red
            : remaining < budget * 0.2
                ? Colors.orange
                : Colors.green;

    final label = !hasBudget
        ? 'This trip has no budget set'
        : over
            ? 'Already ${formatMoney(remaining.abs(), currency)} OVER budget'
            : '${formatMoney(remaining, currency)} left of ${formatMoney(budget, currency)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            !hasBudget
                ? Icons.info_outline
                : over
                    ? Icons.error_outline
                    : Icons.account_balance_wallet_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label • ${formatMoney(spent, currency)} spent',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}