import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/models/auth_bootstrap_models.dart';

void main() {
  test('reads nested billing access fields from the gym document', () {
    final profile = GymProfile.fromMap('gym-1', <String, dynamic>{
      'name': 'Rezone',
      'billing': <String, dynamic>{
        'status': 'inactive',
        'provider': 'Lemon Squeezy',
        'planName': 'AllClubs subscription',
        'productIds': <String>['allclubs.monthly', 'allclubs.annual'],
        'portalUrl': 'https://allclubs.lemonsqueezy.com/billing',
        'checkoutUrl':
            'https://allclubs.lemonsqueezy.com/checkout/buy/example',
        'customerEmail': 'owner@example.com',
        'readOnly': <String, dynamic>{
          'reason': 'Gym is in read-only mode until billing is active.',
        },
      },
      'access': <String, dynamic>{'isReadOnly': true},
    });

    expect(profile.billingStatus, 'inactive');
    expect(
      profile.readOnlyReason,
      'Gym is in read-only mode until billing is active.',
    );
    expect(profile.isReadOnly, isTrue);
    expect(profile.billingProvider, 'Lemon Squeezy');
    expect(profile.billingPlanName, 'AllClubs subscription');
    expect(
      profile.billingPortalUrl,
      'https://allclubs.lemonsqueezy.com/billing',
    );
    expect(
      profile.billingCheckoutUrl,
      'https://allclubs.lemonsqueezy.com/checkout/buy/example',
    );
    expect(profile.billingCustomerEmail, 'owner@example.com');
    expect(
      profile.androidSubscriptionProductIds,
      const <String>['allclubs.monthly', 'allclubs.annual'],
    );
  });
}
