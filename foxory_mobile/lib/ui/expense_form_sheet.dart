import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/database_helper.dart';
import '../models/models.dart';
import '../services/currency_service.dart';

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
  int? tripId = expense?.tripId ?? initialTripId;

  final conn = await db.database;
  final tripRows = await conn.query('trips', orderBy: 'departure ASC');
  final trips = tripRows.map(Trip.fromMap).toList();

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
                    helperText: 'Links this spend to a trip budget',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No trip')),
                    ...trips.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setModalState(() => tripId = v),
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
