// lib/core/utils/currency_formatter.dart

import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compact = NumberFormat.compact(locale: 'en_IN');

  static String format(double amount) => _rupee.format(amount);

  static String compact(double amount) => '₹${_compact.format(amount)}';

  /// Cleanly rounds monetary values to 2 decimal places to eliminate floating point imprecision
  static double round(double amount) {
    return (amount * 100).roundToDouble() / 100.0;
  }

  static String formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty.toStringAsFixed(2);
  }
}
