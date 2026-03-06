import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String currency(double amount, {String currency = 'KZT'}) {
    final format = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: _currencySymbol(currency),
      decimalDigits: currency == 'KZT' ? 0 : 2,
    );
    return format.format(amount);
  }

  static String date(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  static String _currencySymbol(String currency) {
    switch (currency) {
      case 'KZT':
        return '₸';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'RUB':
        return '₽';
      case 'AED':
        return 'د.إ';
      default:
        return currency;
    }
  }
}
