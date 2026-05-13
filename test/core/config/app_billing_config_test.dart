import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/core/config/app_billing_config.dart';
import 'package:mobileallclubs/models/auth_bootstrap_models.dart';

void main() {
  test('resolves android subscription product ids from gym profile', () {
    const gymProfile = GymProfile(
      gymId: 'gym-1',
      androidSubscriptionProductIds: <String>[
        'allclubs.monthly',
        'allclubs.annual',
      ],
    );

    expect(
      resolveAndroidSubscriptionProductIds(gymProfile),
      <String>{'allclubs.monthly', 'allclubs.annual'},
    );
    expect(hasConfiguredAndroidSubscriptionProducts(gymProfile), isTrue);
  });
}
