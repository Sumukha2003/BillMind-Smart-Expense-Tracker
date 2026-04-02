import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

class FirebaseService {
  static Future<String> uploadImage(File file) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('bills/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  static Future<void> uploadExpense(Expense expense) async {
    await FirebaseFirestore.instance.collection('bills').add({
      'merchant': expense.merchant,
      'amount': expense.amount,
      'category': expense.category,
      'date': expense.date.toIso8601String(),
      'imageUrl': expense.firebaseUrl,
      'month': expense.date.month,
      'year': expense.date.year,
      'timestamp': DateTime.now(),
    });
  }
}