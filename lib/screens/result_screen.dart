// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/duplicate_service.dart';
import '../services/firebase_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String merchant;
  final double amount;
  final DateTime? date;
  final String category;
  final double amountConfidence;
  final String amountConfidenceLabel;
  final List<double> amountAlternatives;
  final String? amountEvidence;
  final List<String> amountReasons;
  final Map<String, dynamic>? gstBreakdown;
  final List<dynamic> items;
  final List<dynamic> blocks;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.amountConfidence,
    required this.amountConfidenceLabel,
    required this.amountAlternatives,
    required this.amountEvidence,
    required this.amountReasons,
    required this.gstBreakdown,
    required this.items,
    required this.blocks,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late TextEditingController merchantController;
  late TextEditingController amountController;
  late String selectedCategory;

  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    merchantController = TextEditingController(text: widget.merchant);
    amountController =
        TextEditingController(text: widget.amount.toStringAsFixed(0));
    selectedDate = widget.date ?? DateTime.now();
    selectedCategory = widget.category;
  }

  Color getConfidenceColor(double value) {
    if (value > 0.75) return Colors.green;
    if (value > 0.5) return Colors.orange;
    return Colors.red;
  }

  /// 📅 Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  /// 🔥 SAVE WITH AI DUPLICATE DETECTION
  Future<void> _handleSave() async {
    final amount =
        double.tryParse(amountController.text) ?? widget.amount;

    // Create temp expense (no ID yet)
    final tempExpense = Expense(
      id: '', // Temp - will be set by Firestore
      merchant: merchantController.text.trim(),
      amount: amount,
      date: selectedDate!,
      category: selectedCategory,
      imagePath: widget.imagePath,
      fraudScore: widget.amountConfidence,
    );

    /// 🧠 AI DUPLICATE CHECK
    final score = await DuplicateService.duplicateScore(tempExpense); 

    if (!mounted) return;

    /// ❌ BLOCK DUPLICATE
    if (score >= 0.75) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ Duplicate detected (${(score * 100).toStringAsFixed(0)}% match)",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    /// 🔥 SINGLE FIRESTORE CALL → LOCAL SYNC
    try {
      // Create in Firestore first
      final firestoreId = await FirebaseService.createExpenseAndReturnId(tempExpense);
      
      // Update with real Firestore ID and mark as synced
      tempExpense.id = firestoreId;
      tempExpense.isSynced = true;
      
      /// ✅ SAVE LOCAL (no duplicate Firestore call)
      ref.read(expenseNotifierProvider.notifier).addExpense(tempExpense);
      
    } catch (e) {
      debugPrint('Save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Expense Saved & Synced"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final confidenceColor = getConfidenceColor(widget.amountConfidence);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Review & Save Bill"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🔥 HERO CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D9E75), Color(0xFF146B59)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Amount",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  "₹ ${widget.amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                /// 🔥 PREMIUM CONFIDENCE BADGE
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: confidenceColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: confidenceColor.withOpacity(0.4),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        "${(widget.amountConfidence * 100).toStringAsFixed(0)}% • ${widget.amountConfidenceLabel}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /// ✏️ EDIT FIELDS
          _buildEditField("Merchant", merchantController),
          _buildEditField("Amount", amountController),

          /// 📂 CATEGORY
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.category, color: Colors.grey),
                const SizedBox(width: 10),
                const Text("Category: "),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      items: (
                        <String>{
                          ...Expense.categoryColors.keys,
                        }
                            .toList()
                            ..removeWhere((c) => c.trim().isEmpty)
                      )
                          .followedBy([if (!Expense.categoryColors.keys.contains('Other')) 'Other'])
                          .toList()
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                       onChanged: (v) {
                         if (v == null) return;
                         setState(() => selectedCategory = v);
                       },
                     ),
                   ),
                 ),
              ],
            ),
          ),

          // Amount alternatives (improve OCR)
          if (widget.amountAlternatives.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.amountAlternatives.map((alt) {
                final label = alt.toStringAsFixed(0);
                return ActionChip(
                  label: Text('Use ₹ $label'),
                  onPressed: () {
                    setState(() {
                      amountController.text = alt.toStringAsFixed(0);
                    });
                  },
                );
              }).toList(),
            ),
          ],

          /// 📅 DATE
          GestureDetector(
            onTap: () => _selectDate(context),
            child: _buildDateField(),
          ),

          const SizedBox(height: 20),

          /// 📦 ITEMS
          if (widget.items.isNotEmpty)
            ExpansionTile(
              title: const Text("Detected Items"),
              children: widget.items
                  .map(
                    (e) => ListTile(
                      title: Text(e['name'].toString()),
                      trailing: Text("₹ ${e['amount']}"),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 30),

          /// 💾 SAVE BUTTON
          ElevatedButton(
            onPressed: _handleSave,
            child: const Text("💾 Save Expense"),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Date: ${DateFormat('dd MMM yyyy').format(selectedDate!)}",
          ),
          const Icon(Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildEditField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: label == "Amount"
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixText: label == "Amount" ? "₹ " : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}