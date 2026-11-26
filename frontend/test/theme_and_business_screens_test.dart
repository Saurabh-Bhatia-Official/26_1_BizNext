// test/theme_and_business_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biz_next/core/providers/theme_provider.dart';
import 'package:biz_next/features/auth/screens/create_business_screen.dart';
import 'package:biz_next/features/auth/screens/business_selector_screen.dart';
import 'package:biz_next/features/customers/screens/add_edit_customer_screen.dart';
import 'package:biz_next/features/suppliers/screens/add_edit_supplier_screen.dart';
import 'package:biz_next/features/auth/providers/auth_provider.dart';
import 'package:biz_next/features/auth/models/business_model.dart';
import 'package:biz_next/features/auth/models/user_model.dart';
import 'package:biz_next/features/purchases/screens/add_purchase_screen.dart';
import 'package:biz_next/features/suppliers/providers/supplier_provider.dart';
import 'package:biz_next/features/inventory/providers/inventory_provider.dart';
import 'package:biz_next/features/inventory/screens/add_edit_product_screen.dart';
import 'package:biz_next/features/settings/providers/settings_provider.dart';
import 'package:biz_next/features/accounts/providers/accounts_provider.dart';

void main() {
  group('ThemeMode Default & Toggle Tests', () {
    test('Defaults to ThemeMode.light when no preference is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, equals(ThemeMode.light));
    });

    test('Toggles cleanly between light and dark modes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, equals(ThemeMode.light));

      notifier.toggle();
      expect(notifier.state, equals(ThemeMode.dark));
      expect(prefs.getString('theme_mode'), equals('dark'));

      notifier.toggle();
      expect(notifier.state, equals(ThemeMode.light));
      expect(prefs.getString('theme_mode'), equals('light'));
    });

    test('Loads dark mode only when explicitly saved as dark', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, equals(ThemeMode.dark));
    });
  });

  group('Business Adding Form (CreateBusinessScreen) UI Tests', () {
    testWidgets('Displays visible back arrow and professional header text on desktop', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: CreateBusinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify visible back arrow button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Back to Workspaces'), findsOneWidget);

      // Verify professional header in text bar
      expect(find.text('Register Business Workspace'), findsOneWidget);
      expect(find.text('Enter organization details, contact information, and tax parameters'), findsOneWidget);
    });

    testWidgets('Adapts responsively on phone viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: CreateBusinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Responsive title and button on mobile
      expect(find.text('Register Workspace'), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });

  group('Business Adding Page (BusinessSelectorScreen) UI Tests', () {
    testWidgets('Displays visible back arrow and professional header text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(
              const UserModel(
                id: 1,
                username: 'admin',
                passwordHash: 'hash',
                fullName: 'Saurabh Bhatia',
                role: 'admin',
              ),
            ),
            userBusinessesProvider.overrideWith((ref) async => [
              const BusinessModel(id: 1, ownerId: 1, name: 'Apex Corp', type: 'Retail'),
            ]),
          ],
          child: const MaterialApp(
            home: BusinessSelectorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify visible back arrow in AppBar
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Back to Sign In'), findsOneWidget);

      // Verify professional header in text bar
      expect(find.text('Enterprise Workspace Directory'), findsOneWidget);
      expect(find.text('Select an active workspace or register a new business entity'), findsOneWidget);

      // Verify Register Business card
      expect(find.text('Register Business'), findsOneWidget);
      expect(find.text('Add new enterprise workspace'), findsOneWidget);
    });

    testWidgets('Adapts responsively on phone viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(
              const UserModel(
                id: 1,
                username: 'admin',
                passwordHash: 'hash',
                fullName: 'Saurabh Bhatia',
                role: 'admin',
              ),
            ),
            userBusinessesProvider.overrideWith((ref) async => [
              const BusinessModel(id: 1, ownerId: 1, name: 'Apex Corp', type: 'Retail'),
            ]),
          ],
          child: const MaterialApp(
            home: BusinessSelectorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Compact title on mobile phone
      expect(find.text('Workspaces'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Customer & Supplier Forms Phone Responsiveness Tests', () {
    testWidgets('AddEditCustomerScreen renders phone layout without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: AddEditCustomerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Customer'), findsOneWidget);
      expect(find.text('Customer Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddEditSupplierScreen renders phone layout without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: AddEditSupplierScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register New Supplier'), findsOneWidget);
      expect(find.text('Supplier Display Name *'), findsOneWidget);
      expect(find.text('Company Legal Name'), findsOneWidget);
      expect(find.text('Contact Person / Rep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddPurchaseScreen renders phone layout without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeBusinessIdProvider.overrideWith((ref) => 1),
            suppliersProvider.overrideWith((ref) => Future.value([])),
            productsProvider.overrideWith((ref) => Future.value([])),
            accountsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: AddPurchaseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Purchase Entry'), findsOneWidget);
      expect(find.text('Complete Purchase'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddPurchaseScreen desktop renders cleanly without overlapping elements', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeBusinessIdProvider.overrideWith((ref) => 1),
            suppliersProvider.overrideWith((ref) => Future.value([])),
            productsProvider.overrideWith((ref) => Future.value([])),
            accountsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: AddPurchaseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Purchase Entry'), findsOneWidget);
      expect(find.text('Select Supplier*'), findsOneWidget);
      expect(find.text('Bill Number'), findsOneWidget);
      expect(find.text('Purchase Date'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Multiline Form Fields & Assertion Safety Tests', () {
    testWidgets('AddEditSupplierScreen mounts multiline fields without TextInputType assertion error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeBusinessIdProvider.overrideWith((ref) => 1),
          ],
          child: const MaterialApp(
            home: AddEditSupplierScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Billing / Dispatch Address'), findsOneWidget);
      expect(find.text('Bank Account & NEFT Details'), findsOneWidget);
      expect(find.text('Internal Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddEditCustomerScreen mounts multiline fields without TextInputType assertion error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeBusinessIdProvider.overrideWith((ref) => 1),
          ],
          child: const MaterialApp(
            home: AddEditCustomerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddEditProductScreen mounts multiline fields without TextInputType assertion error', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeBusinessIdProvider.overrideWith((ref) => 1),
            categoriesProvider.overrideWith((ref) => Future.value([])),
            priceCategoriesProvider.overrideWith((ref) => Future.value([])),
            suppliersProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: AddEditProductScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Description & Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CreateBusinessScreen mounts without TextInputType assertion error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: CreateBusinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register Business Workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

