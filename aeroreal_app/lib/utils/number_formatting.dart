import 'package:intl/intl.dart';

class NumberFormatting {
  static String withCommas(dynamic value, {int decimalDigits = 0}) {
    final valueString = value.toString();
    final isNegative = valueString.startsWith('-');
    final normalized = isNegative ? valueString.substring(1) : valueString;
    final parts = normalized.split('.');
    final whole = parts.first;
    final formattedWhole = whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    if (decimalDigits == 0 || parts.length == 1) {
      return '${isNegative ? '-' : ''}$formattedWhole';
    }

    final decimals = parts[1]
        .padRight(decimalDigits, '0')
        .substring(0, decimalDigits);
    return '${isNegative ? '-' : ''}$formattedWhole.$decimals';
  }

  static String money(num value, {int decimalDigits = 2}) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: decimalDigits,
    ).format(value);
  }
}
