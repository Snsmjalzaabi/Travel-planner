import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('expenses', orderBy: 'created_at DESC');
    if (!mounted) return;
    setState(() {
      _expenses = rows.map((m) => Expense.fromMap(m)).toList();
    });
  }

  void _add() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final titleCtrl = TextEditingController();
        final amountCtrl = TextEditingController();
        final currencyCtrl = TextEditingController(text: 'AED');
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Add Expense'),
                subtitle: const Text('Enter details below'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currencyCtrl.text,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: ['AED', 'USD', 'EUR', 'GBP', 'SAR'].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) currencyCtrl.text = v;
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
                    final db = DatabaseHelper();
                    await db.insert('expenses', {
                      'title': titleCtrl.text,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'currency': currencyCtrl.text,
                      'merchant': '',
                      'category': '',
                      'trip_id': null,
                      'notes': '',
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      _load();
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _add,
          ),
        ],
      ),
      body: _expenses.isEmpty
          ? const Center(child: Text('No expenses yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (ctx, i) {
                final e = _expenses[i];
                return ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text(e.title),
                  subtitle: Text('${e.amount} ${e.currency}'),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () {},
                );
              },
            ),
    );
  }
}
