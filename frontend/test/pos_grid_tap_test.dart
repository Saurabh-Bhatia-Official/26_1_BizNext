import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biz_next/core/providers/theme_provider.dart';
import 'package:biz_next/features/auth/providers/auth_provider.dart';
import 'package:biz_next/features/inventory/models/product_model.dart';
import 'package:biz_next/features/inventory/providers/inventory_provider.dart';
import 'package:biz_next/features/customers/providers/customer_provider.dart';
import 'package:biz_next/features/billing/providers/billing_provider.dart';
import 'package:biz_next/features/billing/screens/pos_billing_screen.dart';
import 'package:biz_next/features/settings/models/app_settings.dart';
import 'package:biz_next/features/settings/providers/settings_provider.dart';

class FakeFeatureSettingsNotifier extends StateNotifier<AppFeatureSettings> implements FeatureSettingsNotifier {
  FakeFeatureSettingsNotifier(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Tapping product card and plus button in Grid View adds items to cart', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final testProduct = const Product(
      id: 1,
      name: 'Test Coffee',
      sellingPrice: 150.0,
      stock: 20,
      unit: 'pcs',
      categoryId: 1,
      isActive: true,
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeBusinessIdProvider.overrideWith((ref) => 1),
        productsProvider.overrideWith((ref) => Future.value([testProduct])),
        categoriesProvider.overrideWith((ref) => Future.value([])),
        customersProvider.overrideWith((ref) => Future.value([])),
        allProductTierPricesProvider.overrideWith((ref) => Future.value({})),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PosBillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Coffee'), findsOneWidget);

    // Tap on the product card in Grid View
    await tester.tap(find.text('Test Coffee'));
    await tester.pumpAndSettle();

    var cartItems = container.read(billingProvider).items;
    expect(cartItems.length, 1, reason: 'Cart should contain 1 item after tapping in grid view');
    expect(cartItems.first.quantity, 1.0);

    // Tap the '+' icon in the grid view card (first one in tree)
    final plusBtn = find.byIcon(Icons.add_rounded).first;
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();

    cartItems = container.read(billingProvider).items;
    expect(cartItems.length, 1);
    expect(cartItems.first.quantity, 2.0, reason: 'Quantity should increase to 2 after tapping +');
  });

  testWidgets('When inventory tracking is disabled, products with 0 stock can be added', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final zeroStockProduct = const Product(
      id: 2,
      name: 'Digital Service',
      sellingPrice: 500.0,
      stock: 0,
      unit: 'hrs',
      categoryId: 1,
      isActive: true,
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeBusinessIdProvider.overrideWith((ref) => 1),
        productsProvider.overrideWith((ref) => Future.value([zeroStockProduct])),
        categoriesProvider.overrideWith((ref) => Future.value([])),
        customersProvider.overrideWith((ref) => Future.value([])),
        allProductTierPricesProvider.overrideWith((ref) => Future.value({})),
        featureSettingsProvider.overrideWith((ref) => FakeFeatureSettingsNotifier(AppFeatureSettings(inventoryTrackingEnabled: false))),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PosBillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digital Service'), findsOneWidget);

    // Tap product with 0 stock
    await tester.tap(find.text('Digital Service'));
    await tester.pumpAndSettle();

    final cartItems = container.read(billingProvider).items;
    expect(cartItems.length, 1, reason: 'Item should be added to cart because inventory tracking is disabled');
    expect(cartItems.first.quantity, 1.0);
  });
}
