import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../widgets/expense_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Food', 'Grocery', 'Utility', 'Medical', 'Transport', 'Shopping', 'Entertainment', 'Other'];

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expenseNotifierProvider);
    final filtered = _filter == 'All' ? all : all.where((e) => e.category == _filter).toList();
    final total = filtered.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('All Expenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final sel = f == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1D9E75) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? const Color(0xFF1D9E75) : const Color(0xFFE5E5E5), width: 0.5)),
                  child: Text(f, style: TextStyle(
                    fontSize: 13, color: sel ? Colors.white : const Color(0xFF444441),
                    fontWeight: sel ? FontWeight.w500 : FontWeight.normal)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${filtered.length} expenses',
                style: const TextStyle(fontSize: 13, color: Color(0xFF888780))),
            Text('Total: ₹${NumberFormat('#,##,###.##').format(total)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No expenses found',
                  style: TextStyle(color: Color(0xFF888780), fontSize: 15)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ExpenseCard(
                    expense: filtered[i],
                    onDelete: () => _confirmDelete(filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Remove "${expense.merchant}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFD85A30)))),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(expenseNotifierProvider.notifier).deleteExpense(expense.id);
    }
  }
}
