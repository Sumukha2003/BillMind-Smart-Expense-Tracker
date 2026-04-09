import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 0)
class Expense extends HiveObject {
  static const Map<String, int> categoryColors = {
    'Food': 0xFF1D9E75,
    'Grocery': 0xFF378ADD,
    'Shopping': 0xFFD4537E,
    'Education': 0xFF8E63CE,
    'Utility': 0xFFBA7517,
    'Medical': 0xFFD85A30,
    'Health': 0xFFE06C75,
    'Bills': 0xFFB07A10,
    'Fuel': 0xFF4D7CFE,
    'Transport': 0xFF7F77DD,
    'Entertainment': 0xFF639922,
    'Travel': 0xFF2B6CB0,
    'General': 0xFF607D8B,
    'Other': 0xFF888780,
  };

  @HiveField(0)
  String id;

  @HiveField(1)
  String merchant;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String category;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String imagePath;

  @HiveField(6)
  String firebaseUrl;

  // ✅ NEW FIELDS (SAFE ADDITIONS)

  @HiveField(7)
  String paymentMethod; // cash / upi / card

  @HiveField(8)
  bool isDuplicate;

  @HiveField(9)
  String vendorType; // grocery / food / travel

  @HiveField(10)
  String month; // for analytics

  @HiveField(11)
  Map<String, double> gstBreakdown; // CGST/SGST/IGST/subtotal

  @HiveField(12)
  double fraudScore; // 0-1 risk score

  @HiveField(13)
  List<Map<String, dynamic>> items;

@HiveField(14)
  bool highValueAlertSent;

  @HiveField(15)
  bool isSynced = false;

  Expense({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
    required this.imagePath,
    this.firebaseUrl = '',
    this.highValueAlertSent = false,
    Map<String, double>? gstBreakdown,
    List<Map<String, dynamic>>? items,
    this.fraudScore = 0.0,
    this.paymentMethod = 'Unknown',
    this.isDuplicate = false,
    this.vendorType = 'General',
    String? month,
  })  : gstBreakdown = gstBreakdown ?? {'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0, 'subtotal': 0.0},
        month = month ?? "${date.month.toString().padLeft(2, '0')}-${date.year}",
        items = items ?? [];
}

