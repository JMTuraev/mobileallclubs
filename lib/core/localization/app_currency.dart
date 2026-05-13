import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppCurrency { uzs, usd, eur, kzt }

AppCurrency _currentAppCurrency = AppCurrency.uzs;

extension AppCurrencyPresentation on AppCurrency {
  String get code {
    return switch (this) {
      AppCurrency.uzs => 'UZS',
      AppCurrency.usd => 'USD',
      AppCurrency.eur => 'EUR',
      AppCurrency.kzt => 'KZT',
    };
  }

  String get label {
    return switch (this) {
      AppCurrency.uzs => 'Uzbek so\'m',
      AppCurrency.usd => 'US dollar',
      AppCurrency.eur => 'Euro',
      AppCurrency.kzt => 'Kazakh tenge',
    };
  }

  String get shortLabel {
    return switch (this) {
      AppCurrency.uzs => 'So\'m',
      AppCurrency.usd => 'Dollar',
      AppCurrency.eur => 'Yevro',
      AppCurrency.kzt => 'Tenge',
    };
  }
}

final appCurrencyProvider =
    NotifierProvider<AppCurrencyController, AppCurrency>(
      AppCurrencyController.new,
    );

class AppCurrencyController extends Notifier<AppCurrency> {
  @override
  AppCurrency build() => _currentAppCurrency;

  void setCurrency(AppCurrency currency) {
    _currentAppCurrency = currency;
    state = currency;
  }
}

String currentAppCurrencyCode() => _currentAppCurrency.code;

String formatAppMoney(
  num value, {
  AppCurrency? currency,
  bool withUnit = false,
  bool showSign = false,
}) {
  final resolvedCurrency = currency ?? _currentAppCurrency;
  final sign = showSign
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  final absolute = value.abs();
  final raw = absolute == absolute.roundToDouble()
      ? absolute.toInt().toString()
      : absolute.toStringAsFixed(2);
  final formatted = _groupThousands(raw);

  if (!withUnit) {
    return '$sign$formatted';
  }

  return '$sign$formatted ${resolvedCurrency.code}';
}

String _groupThousands(String raw) {
  final parts = raw.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );

  if (parts.length == 1) {
    return whole;
  }

  return '$whole.${parts.last}';
}
