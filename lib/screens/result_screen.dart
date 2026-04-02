import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/duplicate_service.dart';
import '../services/firebase_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String merchant;
  final String amount;
  final DateTime date;
  final String category;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  static const _categories = [
    'General',
    'Food',
    'Travel',
    'Grocery',
    'Education',
    'Medical',
    'Shopping',
    'Utility',
    'Transport',
    'Entertainment',
    'Other',
  ];

  late TextEditingController _merchantCtrl;
  late TextEditingController _amountCtrl;

  String _selectedCategory = 'General';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _merchantCtrl = TextEditingController(text: widget.merchant);
    _amountCtrl = TextEditingController(text: widget.amount);
    _selectedDate = widget.date;
    _selectedCategory = _categories.contains(widget.category)
        ? widget.category
        : 'General';
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    String vendorType = 'General';
    final merchantLower = _merchantCtrl.text.toLowerCase();

    if (merchantLower.contains('hotel') ||
        merchantLower.contains('restaurant')) {
      vendorType = 'Food';
    } else if (merchantLower.contains('mart') ||
        merchantLower.contains('store')) {
      vendorType = 'Grocery';
    }

    final expense = Expense(
      id: const Uuid().v4(),
      merchant: _merchantCtrl.text.trim(),
      amount: amount,
      category: _selectedCategory,
      date: _selectedDate,
      imagePath: widget.imagePath,
      paymentMethod: 'UPI',
      isDuplicate: false,
      vendorType: vendorType,
    );

    if (DuplicateService.isDuplicate(expense)) {
      setState(() => _isSaving = false);
      _snack('Duplicate bill detected');
      return;
    }

    await ref.read(expenseNotifierProvider.notifier).addExpense(expense);

    try {
      final url = await FirebaseService.uploadImage(File(widget.imagePath));
      expense.firebaseUrl = url;
      await expense.save();
      await FirebaseService.uploadExpense(expense);
    } catch (_) {}

    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense saved successfully'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF151A18) : Colors.white;
    final subtleSurfaceColor = isDark
        ? const Color(0xFF101513)
        : const Color(0xFFF9FCFB);
    final borderColor = isDark
        ? const Color(0xFF2A3430)
        : const Color(0xFFE3ECE7);
    final secondaryTextColor = isDark
        ? const Color(0xFFB6C2BD)
        : const Color(0xFF61706B);
    final amountPreview = double.tryParse(_amountCtrl.text) ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Expense')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A0A0A),
                    Color(0xFF111715),
                  ]
                : const [
                    Color(0xFFF4FBF8),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x14101A18),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Image.file(
                        File(widget.imagePath),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1D9E75,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Review before saving',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _merchantCtrl.text.trim().isEmpty
                                      ? 'Unrecognized merchant'
                                      : _merchantCtrl.text.trim(),
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rs ${amountPreview.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _merchantCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Merchant',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: subtleSurfaceColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(
                          'Bill date',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          _selectedDate.toLocal().toString().split(' ')[0],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save flow',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'The expense is saved locally first so your monthly analytics refresh immediately.',
                    ),
                    SizedBox(height: 6),
                    Text(
                      'After that, the bill image and metadata are uploaded to Firebase automatically.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1D9E75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
