import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/expense.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());

  await Hive.openBox<Expense>('expenses');
  await Hive.openBox('settings'); //  IMPORTANT

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

      themeMode: themeMode,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1D9E75),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1D9E75),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),

      home: const HomeScreen(),
    );
  }
}