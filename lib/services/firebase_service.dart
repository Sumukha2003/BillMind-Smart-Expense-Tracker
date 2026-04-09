import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

class FirebaseService {
  /// 🗑️ DELETE FROM FIRESTORE (called after local Hive delete)
  static Future<void> deleteExpenseFromFirestore(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
      debugPrint('✅ Deleted from Firestore: $docId');
    } catch (e) {
      debugPrint('Firestore delete error for $docId: $e');
    }
  }


  static Future<String?> uploadImage(File file) async {
    try {
      if (!await file.exists()) {
        debugPrint('File not found: ${file.path}');
        return null;
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('bills/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getExpenses() {
    return FirebaseFirestore.instance
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Create expense in Firestore and return doc ID for local sync
  static Future<String> createExpenseAndReturnId(Expense expense) async {
    try {
      final docRef = await FirebaseFirestore.instance.collection('expenses').add({
        'merchant': expense.merchant,
        'amount': expense.amount,
        'category': expense.category,
        'date': expense.date.toIso8601String(),
        'imageUrl': expense.firebaseUrl,
        'items': expense.items,
        'month': expense.date.month,
        'year': expense.date.year,
        'confidence': expense.fraudScore,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Firestore create error: $e');
      rethrow;
    }
  }

  /// 🔄 SYNC ALL LOCAL EXPENSES TO FIREBASE
  static Future<int> syncAllExpenses(Box<Expense> box) async {
    int synced = 0;
    final expenses = box.values.toList();

    for (final expense in expenses) {
      // Skip already synced
      if (expense.isSynced) {
        debugPrint('⏭️ Skip synced: ${expense.merchant}');
        continue;
      }

      try {
        // Upload image if path exists
        String? imageUrl;
        if (expense.imagePath.isNotEmpty && File(expense.imagePath).existsSync()) {
          imageUrl = await uploadImage(File(expense.imagePath));
          expense.firebaseUrl = imageUrl ?? '';
          await box.put(expense.key, expense); // Update local with URL
        }

        // Upload expense data
        final firestoreId = await FirebaseService.createExpenseAndReturnId(expense);
        expense.id = firestoreId; // Use Firestore ID
        expense.isSynced = true;
        await box.put(expense.id, expense); // Update with Firestore ID and synced flag
        synced++;
        debugPrint('✅ Synced: ${expense.merchant} (ID: $firestoreId)');
      } catch (e) {
        debugPrint('❌ Sync error for ${expense.merchant}: $e');
      }
    }

    debugPrint('Firebase sync complete: $synced new expenses');
    return synced;
  }

  /// 🔥 DOWNLOAD FROM FIRESTORE → MERGE LOCAL HIVE (Respect local deletes)
  static Future<int> downloadAllExpenses(Box<Expense> box) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .get();

      int downloaded = 0;
      int skipped = 0;
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final expense = Expense(
            id: doc.id,  // Use Firestore doc ID as Hive key
            merchant: data['merchant'] ?? 'Unknown',
            amount: (data['amount'] ?? 0).toDouble(),
            category: data['category'] ?? 'Other',
            date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
            imagePath: '',  // Local path not in Firestore, keep empty or fetch from storage
            firebaseUrl: data['imageUrl'] ?? '',
            items: List<Map<String, dynamic>>.from(data['items'] ?? []),
            fraudScore: data['confidence'] ?? 0.0,
            highValueAlertSent: data['highValueAlertSent'] ?? false,
          );

          // Merge: only add if NOT already in local Hive (respect local deletes)
          if (!box.containsKey(expense.id)) {
            await box.put(expense.id, expense);
            downloaded++;
          } else {
            skipped++;
          }
          debugPrint('Processed ${expense.merchant}: ${box.containsKey(expense.id) ? "skipped (local exists)" : "added"}');
        } catch (e) {
          debugPrint('Download error for ${doc.id}: $e');
        }
      }
      debugPrint('Firestore → Hive MERGE complete: $downloaded new, $skipped skipped');
      return downloaded;
    } catch (e) {
      debugPrint('downloadAllExpenses error: $e');
      return 0;
    }
  }

}
