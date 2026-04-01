import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> parsedData;
  final String imagePath;

  const ResultScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late TextEditingController _merchantCtrl;
  late TextEditingController _amountCtrl;

  late String _selectedCategory;
  late DateTime _selectedDate;

  bool _isSaving = false;

  static const categories = [
    'Food', 'Grocery', 'Utility', 'Medical',
    'Transport', 'Shopping', 'Entertainment', 'Other',
  ];

  @override
  void initState() {
    super.initState();

    _merchantCtrl =
        TextEditingController(text: widget.parsedData['merchant'] ?? '');

    _amountCtrl = TextEditingController(
        text: (widget.parsedData['amount'] ?? 0.0).toStringAsFixed(2));

    _selectedCategory = categories.contains(widget.parsedData['category'])
        ? widget.parsedData['category']
        : 'Other';

    try {
      _selectedDate = DateTime.parse(widget.parsedData['date'] ?? '');
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;

    if (_merchantCtrl.text.trim().isEmpty) {
      _snack('Enter merchant name');
      return;
    }

    if (amount <= 0) {
      _snack('Enter valid amount');
      return;
    }

    setState(() => _isSaving = true);

    final expense = Expense(
      id: const Uuid().v4(),
      merchant: _merchantCtrl.text.trim(),
      amount: amount,
      category: _selectedCategory,
      date: _selectedDate,
      gstNumber: widget.parsedData['gst_number']?.toString(),
      cgst: (widget.parsedData['cgst'] as num?)?.toDouble(),
      sgst: (widget.parsedData['sgst'] as num?)?.toDouble(),
      items: List<String>.from(widget.parsedData['items'] ?? []),
      imagePath: widget.imagePath,
    );

    await ref.read(expenseNotifierProvider.notifier).addExpense(expense);

    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense saved successfully'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        double.tryParse(_amountCtrl.text) ?? 0.0;

    final items = List<String>.from(widget.parsedData['items'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Review Bill"),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text("Save"),
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 📷 IMAGE PREVIEW
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            // 💰 BIG AMOUNT DISPLAY
            Center(
              child: Column(
                children: [
                  const Text("Total Amount",
                      style: TextStyle(color: Colors.grey)),

                  const SizedBox(height: 6),

                  Text(
                    "₹ ${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D9E75),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🧾 DETAILS CARD
            _card([
              _field("Merchant", _merchantCtrl),
              _divider(),
              _field("Amount", _amountCtrl),
              _divider(),
              _dateRow(),
              _divider(),
              _categoryRow(),
            ]),

            // 📦 ITEMS
            if (items.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Items"),

              const SizedBox(height: 10),

              _card(
                items
                    .map((e) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(e),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D9E75),
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text("Save Expense"),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _dateRow() => ListTile(
        title: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: _pickDate,
      );

  Widget _categoryRow() => Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          items: categories
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) => setState(() => _selectedCategory = val!),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  Widget _divider() => const Divider(height: 1);
}