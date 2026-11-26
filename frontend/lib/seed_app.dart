import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_helper.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MaterialApp(home: SeedScreen()));
}

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});
  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  String status = "Ready to reset and seed data.";
  bool isLoading = false;

  Future<void> _runSeed() async {
    setState(() {
      isLoading = true;
      status = "Resetting database...";
    });
    
    // reset database
    await DatabaseHelper.resetDatabase();
    
    // clear prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() => status = "Re-initializing database...");
    final db = await DatabaseHelper.instance.database;

    setState(() => status = "Generating sample data...");
    
    await db.transaction((txn) async {
       // Customers
       await txn.insert(AppConstants.tblCustomers, {
         'business_id': 1,
         'name': 'John Doe (Walk-in)',
         'phone': '9876543210',
         'balance': 0,
       });
       await txn.insert(AppConstants.tblCustomers, {
         'business_id': 1,
         'name': 'Jane Smith (VIP)',
         'phone': '8765432109',
         'balance': 500,
       });

       // Suppliers
       await txn.insert(AppConstants.tblSuppliers, {
         'business_id': 1,
         'name': 'Global Distributors',
         'phone': '1112223334',
         'balance': -1000,
       });

       // Categories
       final cat1 = await txn.insert(AppConstants.tblCategories, {
         'business_id': 1,
         'name': 'Beverages',
       });
       final cat2 = await txn.insert(AppConstants.tblCategories, {
         'business_id': 1,
         'name': 'Snacks',
       });
       final cat3 = await txn.insert(AppConstants.tblCategories, {
         'business_id': 1,
         'name': 'Electronics',
       });

       // Products
       await txn.insert(AppConstants.tblProducts, {
         'business_id': 1,
         'name': 'Coca Cola 1L',
         'barcode': '10001',
         'category_id': cat1,
         'purchase_price': 40,
         'selling_price': 50,
         'stock': 100,
       });
       await txn.insert(AppConstants.tblProducts, {
         'business_id': 1,
         'name': 'Lays Classic',
         'barcode': '10002',
         'category_id': cat2,
         'purchase_price': 15,
         'selling_price': 20,
         'stock': 50,
       });
       await txn.insert(AppConstants.tblProducts, {
         'business_id': 1,
         'name': 'USB-C Cable',
         'barcode': '10003',
         'category_id': cat3,
         'purchase_price': 150,
         'selling_price': 300,
         'stock': 20,
       });
       await txn.insert(AppConstants.tblProducts, {
         'business_id': 1,
         'name': 'Wireless Mouse',
         'barcode': '10004',
         'category_id': cat3,
         'purchase_price': 400,
         'selling_price': 799,
         'stock': 15,
       });
    });

    setState(() {
      isLoading = false;
      status = "Seed complete!\n\nClose this window and run the main app normally.\n(Login with admin / admin123)";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Dummy Data')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            if (isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _runSeed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("RESET & SEED DATA", style: TextStyle(fontSize: 16)),
              )
          ],
        ),
      ),
    );
  }
}
