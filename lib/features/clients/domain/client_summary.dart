import 'package:cloud_firestore/cloud_firestore.dart';

class GymClientSummary {
  const GymClientSummary({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.imageUrl,
    this.cardId,
    this.isArchived = false,
  });

  factory GymClientSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return GymClientSummary(
      id: snapshot.id,
      firstName: _asString(data['firstName']),
      lastName: _asString(data['lastName']),
      phone: _asString(data['phone']),
      email: _asString(data['email']),
      imageUrl: _asString(data['image']),
      cardId: _asString(data['cardId']),
      isArchived: data['isArchived'] == true,
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final String? cardId;
  final bool isArchived;

  String get fullName {
    final parts = <String>[];

    for (final part in [firstName, lastName]) {
      if (part != null && part.trim().isNotEmpty) {
        parts.add(part.trim());
      }
    }

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    if (email != null && email!.isNotEmpty) {
      return email!;
    }

    return 'Client';
  }

  String get initials {
    final firstInitial = firstName?.trim().isNotEmpty == true
        ? firstName!.trim()[0]
        : '';
    final lastInitial = lastName?.trim().isNotEmpty == true
        ? lastName!.trim()[0]
        : '';
    final initials = '$firstInitial$lastInitial'.trim();

    if (initials.isNotEmpty) {
      return initials.toUpperCase();
    }

    if (fullName.isNotEmpty) {
      return fullName[0].toUpperCase();
    }

    return 'C';
  }

  bool matchesSearch(String rawQuery) {
    final trimmedQuery = rawQuery.trim();
    if (trimmedQuery.isEmpty) {
      return true;
    }

    final queryDigits = trimmedQuery.replaceAll(RegExp(r'\D'), '');
    if (queryDigits.isEmpty) {
      return false;
    }

    final phoneDigits = (phone ?? '').replaceAll(RegExp(r'\D'), '');

    return phoneDigits.contains(queryDigits);
  }
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}
