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
    this.city,
    this.phone,
    this.ownerId,
  });

  factory GymProfile.fromMap(String gymId, Map<String, dynamic> data) {
    return GymProfile(
      gymId: gymId,
      name: _asString(data['name']),
      city: _asString(data['city']),
      phone: _asString(data['phone']),
      ownerId: _asString(data['ownerId']),
    );
  }

  final String gymId;
  final String? name;
  final String? city;
  final String? phone;
  final String? ownerId;

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

bool? _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  return null;
}
