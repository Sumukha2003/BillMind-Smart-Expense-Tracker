import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 0)
class Expense extends HiveObject {

  @HiveField(0)
  late String id;

  @HiveField(1)
  late String merchant;

  @HiveField(2)
  late double amount;

  @HiveField(3)
  late String category;

  @HiveField(4)
  late DateTime date;

  @HiveField(5)
  String? gstNumber;

  @HiveField(6)
  double? cgst;

  @HiveField(7)
  double? sgst;

  @HiveField(8)
  late List<String> items;

  @HiveField(9)
  String? imagePath;

  // For future (PDF support / source tracking)
  @HiveField(10)
  String sourceType; // image / pdf

  Expense({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
    this.gstNumber,
    this.cgst,
    this.sgst,
    List<String>? items,
    this.imagePath,
    this.sourceType = "image",
  }) {
    this.items = items ?? [];
  }

  // Convert to Firebase Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'gstNumber': gstNumber,
      'cgst': cgst ?? 0.0,
      'sgst': sgst ?? 0.0,
      'items': items,
      'imagePath': imagePath,
      'sourceType': sourceType,
    };
  }

  // Create from Firebase Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      merchant: map['merchant'] ?? 'Unknown',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      gstNumber: map['gstNumber'],
      cgst: (map['cgst'] ?? 0).toDouble(),
      sgst: (map['sgst'] ?? 0).toDouble(),
      items: List<String>.from(map['items'] ?? []),
      imagePath: map['imagePath'],
      sourceType: map['sourceType'] ?? 'image',
    );
  }
}