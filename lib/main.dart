import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/expense.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'services/alert_service_new.dart';
import 'services/firebase_service.dart';

final alertService = AlertServiceNew();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ENV
  await dotenv.load(fileName: '.env');

  /// Initialize alert/notification service early
  await alertService.init();

  /// FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// HIVE - FIXED CRASH
  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());

  // Data persistence enabled - no delete on startup

  // Open fresh boxes
  final expenseBox = await Hive.openBox<Expense>('expenses');
  await Hive.openBox('settings');

  // 🔥 AUTO SYNC: Download from Firestore → populate local Hive
  final downloaded = await FirebaseService.downloadAllExpenses(expenseBox);
  debugPrint('Startup: Downloaded $downloaded expenses from Firestore');

  // 🚨 STARTUP YEARLY ALERT CHECK
  final expenses = expenseBox.values.toList();
  final yearTotals = <int, double>{};
  for (final exp in expenses) {
    final yr = exp.date.year;
    yearTotals[yr] = (yearTotals[yr] ?? 0.0) + exp.amount;
  }
  int checkedYears = 0;
  for (final entry in yearTotals.entries) {
    await alertService.checkYearlyLimit(year: entry.key, totalAmount: entry.value);
    checkedYears++;
  }
  debugPrint('Startup: Checked $checkedYears years for >₹1L alerts. Year totals: $yearTotals');

  runApp(const ProviderScope(child: BillScannerApp()));
}

class BillScannerApp extends ConsumerWidget {
  const BillScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bill Scanner',

      /// 🔥 FIXED THEME MODE
      themeMode: themeMode,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1D9E75),

        /// 🔥 GLOBAL CARD STYLE
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1D9E75),

        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        scaffoldBackgroundColor: const Color(0xFF0B0F0E),
      ),

      home: const HomeScreen(),
    );
  }
}
