import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final _timeFormat = DateFormat('hh:mm a');

  static String currency(num? amount, {String symbol = '₹'}) {
    if (amount == null) return '$symbol 0.00';
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  static String dateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  static String time(DateTime? date) {
    if (date == null) return '-';
    return _timeFormat.format(date);
  }

  static String parseAndFormatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return _dateTimeFormat.format(dt);
    } catch (_) {
      return isoString;
    }
  }
}
