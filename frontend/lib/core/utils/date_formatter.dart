// lib/core/utils/date_formatter.dart

import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _display = DateFormat('dd MMM yyyy');
  static final _displayWithTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _dbFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _invoiceDate = DateFormat('dd/MM/yyyy');

  static String toDisplay(DateTime dt) => _display.format(dt);
  static String toDisplayWithTime(DateTime dt) => _displayWithTime.format(dt);
  static String toDb(DateTime dt) => _dbFormat.format(dt);
  static String toInvoice(DateTime dt) => _invoiceDate.format(dt);

  static DateTime fromDb(String s) => DateTime.parse(s);

  static String today() => toDisplay(DateTime.now());
  static String todayDb() => toDb(DateTime.now());

  static String formatRelative(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is String) {
      dt = DateTime.parse(date);
    } else if (date is DateTime) {
      dt = date;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return toDisplay(dt);
  }
}
