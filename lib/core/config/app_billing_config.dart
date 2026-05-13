import '../../models/auth_bootstrap_models.dart';

const String _androidSubscriptionIdsDefine = String.fromEnvironment(
  'ALLCLUBS_ANDROID_SUBSCRIPTION_IDS',
  defaultValue: '',
);

Set<String> resolveAndroidSubscriptionProductIds(GymProfile? gymProfile) {
  final gymProductIds = gymProfile?.androidSubscriptionProductIds ?? const [];
  if (gymProductIds.isNotEmpty) {
    return gymProductIds.map((entry) => entry.trim()).where((entry) {
      return entry.isNotEmpty;
    }).toSet();
  }

  return _androidSubscriptionIdsDefine
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();
}

bool hasConfiguredAndroidSubscriptionProducts(GymProfile? gymProfile) {
  return resolveAndroidSubscriptionProductIds(gymProfile).isNotEmpty;
}
