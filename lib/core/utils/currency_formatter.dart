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

  static String formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty.toStringAsFixed(2);
  }
}
