import 'package:firebase_auth/firebase_auth.dart';

enum AllClubsRole { owner, staff, superAdmin, unknown }

extension AllClubsRoleParsing on AllClubsRole {
  static AllClubsRole fromWireValue(String? value) {
    return switch (value) {
      'owner' => AllClubsRole.owner,
      'staff' => AllClubsRole.staff,
      'super_admin' => AllClubsRole.superAdmin,
      _ => AllClubsRole.unknown,
    };
  }
}

extension AllClubsRolePresentation on AllClubsRole {
  String get wireValue {
    return switch (this) {
      AllClubsRole.owner => 'owner',
      AllClubsRole.staff => 'staff',
      AllClubsRole.superAdmin => 'super_admin',
      AllClubsRole.unknown => 'unknown',
    };
  }
}

class AuthenticatedUserSnapshot {
  const AuthenticatedUserSnapshot({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    required this.isAnonymous,
    required this.emailVerified,
  });

  factory AuthenticatedUserSnapshot.fromFirebaseUser(User user) {
    return AuthenticatedUserSnapshot(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      isAnonymous: user.isAnonymous,
      emailVerified: user.emailVerified,
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final bool isAnonymous;
  final bool emailVerified;

  String get primaryIdentifier {
    if (email != null && email!.isNotEmpty) {
      return email!;
    }

    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      return phoneNumber!;
    }

    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }

    return uid;
  }
}

class GlobalUserProfile {
  const GlobalUserProfile({
    required this.uid,
    this.email,
    this.gymId,
    this.roleValue,
    this.isActive,
    this.fullName,
    this.firstName,
    this.lastName,
    this.phone,
    this.photo,
    this.photoUrl,
    this.displayName,
  });

  factory GlobalUserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return GlobalUserProfile(
      uid: uid,
      email: _asString(data['email']),
      gymId: _asString(data['gymId']),
      roleValue: _asString(data['role']),
      isActive: _asBool(data['isActive']),
      fullName: _asString(data['fullName']),
      firstName: _asString(data['firstName']),
      lastName: _asString(data['lastName']),
      phone: _asString(data['phone']),
      photo: _asString(data['photo']),
      photoUrl: _asString(data['photoURL']),
      displayName: _asString(data['displayName']),
    );
  }

  final String uid;
  final String? email;
  final String? gymId;
  final String? roleValue;
  final bool? isActive;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? photo;
  final String? photoUrl;
  final String? displayName;

  String get docPath => 'users/$uid';
  AllClubsRole get role => AllClubsRoleParsing.fromWireValue(roleValue);
}

class GymMembershipProfile {
  const GymMembershipProfile({
    required this.gymId,
    required this.uid,
    this.email,
    this.roleValue,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    this.photo,
    this.isActive,
  });

  factory GymMembershipProfile.fromMap(
    String gymId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return GymMembershipProfile(
      gymId: gymId,
      uid: uid,
      email: _asString(data['email']),
      roleValue: _asString(data['role']),
      firstName: _asString(data['firstName']),
      lastName: _asString(data['lastName']),
      fullName: _asString(data['fullName']),
      phone: _asString(data['phone']),
      photo: _asString(data['photo']),
      isActive: _asBool(data['isActive']),
    );
  }

  final String gymId;
  final String uid;
  final String? email;
  final String? roleValue;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? phone;
  final String? photo;
  final bool? isActive;

  String get docPath => 'gyms/$gymId/users/$uid';
  AllClubsRole get role => AllClubsRoleParsing.fromWireValue(roleValue);
}

class GymProfile {
  const GymProfile({
    required this.gymId,
    this.name,
    this.logoUrl,
    this.city,
    this.phone,
    this.ownerId,
    this.billingStatus,
    this.billingProvider,
    this.billingPlanName,
    this.billingPortalUrl,
    this.billingCheckoutUrl,
    this.billingDashboardUrl,
    this.billingCustomerEmail,
    this.androidSubscriptionProductIds = const <String>[],
    this.readOnlyReason,
    this.isReadOnly,
  });

  factory GymProfile.fromMap(String gymId, Map<String, dynamic> data) {
    final nestedSources = _collectGymProfileNestedSources(data);

    return GymProfile(
      gymId: gymId,
      name: _asString(data['name']),
      logoUrl: _firstNonEmptyString(
        data['logoUrl'],
        data['logoURL'],
        data['logo'],
        data['imageUrl'],
        data['image'],
        data['photoUrl'],
        data['photoURL'],
      ),
      city: _asString(data['city']),
      phone: _asString(data['phone']),
      ownerId: _asString(data['ownerId']),
      billingStatus: _firstNonEmptyString(
        data['billingStatus'],
        data['subscriptionStatus'],
        data['entitlementStatus'],
        data['planStatus'],
        _firstStringFromMaps(nestedSources, const [
          'billingStatus',
          'subscriptionStatus',
          'entitlementStatus',
          'planStatus',
          'status',
          'state',
        ]),
      ),
      billingProvider: _firstNonEmptyString(
        data['billingProvider'],
        _firstStringFromMaps(nestedSources, const ['provider', 'providerName']),
      ),
      billingPlanName: _firstNonEmptyString(
        data['billingPlanName'],
        data['planName'],
        _firstStringFromMaps(nestedSources, const ['planName', 'productName']),
      ),
      billingPortalUrl: _firstNonEmptyString(
        data['billingPortalUrl'],
        data['portalUrl'],
        data['customerPortalUrl'],
        _firstStringFromMaps(nestedSources, const [
          'billingPortalUrl',
          'portalUrl',
          'customerPortalUrl',
        ]),
      ),
      billingCheckoutUrl: _firstNonEmptyString(
        data['billingCheckoutUrl'],
        data['checkoutUrl'],
        _firstStringFromMaps(nestedSources, const [
          'billingCheckoutUrl',
          'checkoutUrl',
        ]),
      ),
      billingDashboardUrl: _firstNonEmptyString(
        data['billingDashboardUrl'],
        data['dashboardUrl'],
        _firstStringFromMaps(nestedSources, const [
          'billingDashboardUrl',
          'dashboardUrl',
        ]),
      ),
      billingCustomerEmail: _firstNonEmptyString(
        data['billingCustomerEmail'],
        data['customerEmail'],
        _firstStringFromMaps(nestedSources, const [
          'billingCustomerEmail',
          'customerEmail',
        ]),
      ),
      androidSubscriptionProductIds: _firstNonEmptyStringList(
        _asStringList(data['androidSubscriptionProductIds']),
        _asStringList(data['billingProductIds']),
        _asStringList(data['subscriptionProductIds']),
        _asStringList(data['playProductIds']),
        _firstStringListFromMaps(nestedSources, const [
          'androidSubscriptionProductIds',
          'billingProductIds',
          'subscriptionProductIds',
          'playProductIds',
          'productIds',
        ]),
      ),
      readOnlyReason: _firstNonEmptyString(
        data['readOnlyReason'],
        data['readonlyReason'],
        data['readOnlyMessage'],
        data['billingMessage'],
        data['billingReason'],
        _firstStringFromMaps(nestedSources, const [
          'readOnlyReason',
          'readonlyReason',
          'readOnlyMessage',
          'billingMessage',
          'billingReason',
          'blockedReason',
          'reason',
          'message',
        ]),
      ),
      isReadOnly:
          _asFlexibleBool(data['isReadOnly']) ??
          _asFlexibleBool(data['readOnly']) ??
          _asFlexibleBool(data['readonly']) ??
          _firstFlexibleBoolFromMaps(nestedSources, const [
            'isReadOnly',
            'readOnly',
            'readonly',
            'blocked',
          ]),
    );
  }

  final String gymId;
  final String? name;
  final String? logoUrl;
  final String? city;
  final String? phone;
  final String? ownerId;
  final String? billingStatus;
  final String? billingProvider;
  final String? billingPlanName;
  final String? billingPortalUrl;
  final String? billingCheckoutUrl;
  final String? billingDashboardUrl;
  final String? billingCustomerEmail;
  final List<String> androidSubscriptionProductIds;
  final String? readOnlyReason;
  final bool? isReadOnly;

  String get docPath => 'gyms/$gymId';
}

class ResolvedAuthSession {
  const ResolvedAuthSession({
    required this.authUser,
    this.userProfile,
    this.gymMembership,
    this.gym,
  });

  final AuthenticatedUserSnapshot authUser;
  final GlobalUserProfile? userProfile;
  final GymMembershipProfile? gymMembership;
  final GymProfile? gym;

  AllClubsRole get role => userProfile?.role ?? AllClubsRole.unknown;
  bool get hasUserProfile => userProfile != null;
  bool get isSuperAdmin => role == AllClubsRole.superAdmin;
  String? get gymId => userProfile?.gymId;
  bool get needsOnboarding =>
      !isSuperAdmin && (!hasUserProfile || gymId == null || gymId!.isEmpty);
  String get expectedUserDocPath => 'users/${authUser.uid}';
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}

String? _firstNonEmptyString(
  dynamic first, [
  dynamic second,
  dynamic third,
  dynamic fourth,
  dynamic fifth,
  dynamic sixth,
  dynamic seventh,
]) {
  for (final value in [first, second, third, fourth, fifth, sixth, seventh]) {
    final resolved = _asString(value);
    if (resolved != null) {
      return resolved;
    }
  }

  return null;
}

List<Map<String, dynamic>> _collectGymProfileNestedSources(
  Map<String, dynamic> data,
) {
  const candidateKeys = <String>[
    'billing',
    'billingState',
    'billingInfo',
    'subscription',
    'subscriptionInfo',
    'plan',
    'planInfo',
    'contract',
    'access',
    'flags',
    'readOnly',
    'readonly',
  ];

  final sources = <Map<String, dynamic>>[];
  final queue = <Map<String, dynamic>>[];

  void addCandidate(dynamic value) {
    final resolved = _asMap(value);
    if (resolved == null || sources.contains(resolved)) {
      return;
    }

    sources.add(resolved);
    queue.add(resolved);
  }

  for (final key in candidateKeys) {
    addCandidate(data[key]);
  }

  while (queue.isNotEmpty) {
    final source = queue.removeAt(0);
    for (final key in candidateKeys) {
      addCandidate(source[key]);
    }
  }

  return sources;
}

String? _firstStringFromMaps(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    for (final key in keys) {
      final resolved = _asString(source[key]);
      if (resolved != null) {
        return resolved;
      }
    }
  }

  return null;
}

List<String> _firstNonEmptyStringList(
  List<String>? first, [
  List<String>? second,
  List<String>? third,
  List<String>? fourth,
  List<String>? fifth,
]) {
  for (final values in [first, second, third, fourth, fifth]) {
    if (values != null && values.isNotEmpty) {
      return values;
    }
  }

  return const <String>[];
}

List<String>? _firstStringListFromMaps(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    for (final key in keys) {
      final resolved = _asStringList(source[key]);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
  }

  return null;
}

bool? _firstFlexibleBoolFromMaps(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    for (final key in keys) {
      final resolved = _asFlexibleBool(source[key]);
      if (resolved != null) {
        return resolved;
      }
    }
  }

  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }

  return null;
}

List<String>? _asStringList(dynamic value) {
  if (value is Iterable) {
    final items = value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    return items.isEmpty ? null : items;
  }

  if (value is String) {
    final items = value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    return items.isEmpty ? null : items;
  }

  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  return null;
}

bool? _asFlexibleBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }

  return null;
}
