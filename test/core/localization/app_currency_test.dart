import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/core/localization/app_currency.dart';

void main() {
  test('formats money with the selected app currency code', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(formatAppMoney(120000, withUnit: true), '120 000 UZS');

    container.read(appCurrencyProvider.notifier).setCurrency(AppCurrency.usd);

    expect(container.read(appCurrencyProvider), AppCurrency.usd);
    expect(formatAppMoney(120000, withUnit: true), '120 000 USD');
  });
}
