import 'package:cloud_firestore/cloud_firestore.dart';

class GymStaffSummary {
  const GymStaffSummary({
    required this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.imageUrl,
    this.roleValue,
    this.isActive,
    this.createdAtEpochMillis,
  });

  factory GymStaffSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return GymStaffSummary.fromMap(snapshot.id, snapshot.data());
  }

  factory GymStaffSummary.fromMap(String id, Map<String, dynamic> data) {
    return GymStaffSummary(
      id: id,
      fullName: _asString(data['fullName']),
      firstName: _asString(data['firstName']),
      lastName: _asString(data['lastName']),
      phone: _asString(data['phone']),
      email: _asString(data['email']),
      imageUrl:
          _asString(data['image']) ??
          _asString(data['photo']) ??
          _asString(data['photoURL']),
      roleValue: _asString(data['role']),
      isActive: _asBool(data['isActive']),
      createdAtEpochMillis: _asEpochMillis(data['createdAt']),
    );
  }

  final String id;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final String? roleValue;
  final bool? isActive;
  final int? createdAtEpochMillis;

  bool get isStaffRole => roleValue == 'staff';
  bool get isActiveByDefault => isActive ?? true;

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }

    final parts = <String>[
      if (firstName != null && firstName!.isNotEmpty) firstName!,
      if (lastName != null && lastName!.isNotEmpty) lastName!,
    ];

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    return 'No name';
  }

  String get displayPhone {
    if (phone != null && phone!.isNotEmpty) {
      return phone!;
    }

    return '-';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'NA';
    }

    return parts
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }
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

int? _asEpochMillis(dynamic value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }

  if (value is DateTime) {
    return value.millisecondsSinceEpoch;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return null;
}
