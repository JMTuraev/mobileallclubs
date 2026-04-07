import 'package:cloud_firestore/cloud_firestore.dart';

class GymClientDetail {
  const GymClientDetail({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.imageUrl,
    this.cardId,
    this.gender,
    this.age,
    this.type,
    this.lifetimeSpent,
    this.createdAt,
  });

  factory GymClientDetail.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return GymClientDetail(
      id: snapshot.id,
      firstName: _asString(data['firstName']),
      lastName: _asString(data['lastName']),
      phone: _asString(data['phone']),
      email: _asString(data['email']),
      imageUrl: _asString(data['image']),
      cardId: _asString(data['cardId']),
      gender: _asString(data['gender']),
      age: _asInt(data['age']),
      type: _asString(data['type']),
      lifetimeSpent: _asNum(data['lifetimeSpent']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final String? cardId;
  final String? gender;
  final int? age;
  final String? type;
  final num? lifetimeSpent;
  final DateTime? createdAt;

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

    return fullName[0].toUpperCase();
  }
}

class ClientSubscriptionSummary {
  const ClientSubscriptionSummary({
    required this.id,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.packageId,
    this.status,
    this.sessionsCount,
    this.replaceComment,
    this.packageName,
    this.packagePrice,
    this.packageDurationDays,
    this.isUnlimited,
    this.visitLimit,
    this.remainingVisits,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory ClientSubscriptionSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final packageSnapshot = data['packageSnapshot'];
    final packageData = packageSnapshot is Map<String, dynamic>
        ? packageSnapshot
        : packageSnapshot is Map
        ? Map<String, dynamic>.from(packageSnapshot)
        : const <String, dynamic>{};

    return ClientSubscriptionSummary(
      id: snapshot.id,
      clientId: _asString(data['clientId']),
      clientName: _asString(data['clientName']),
      clientPhone: _asString(data['clientPhone']),
      packageId: _asString(data['packageId']) ?? _asString(packageData['id']),
      status: _asString(data['status']),
      sessionsCount: _asInt(data['sessionsCount']),
      replaceComment: _asString(data['replaceComment']),
      packageName: _asString(packageData['name']),
      packagePrice: _asNum(packageData['price']),
      packageDurationDays: _asInt(packageData['duration']),
      isUnlimited: _asBool(packageData['isUnlimited']),
      visitLimit: _asInt(data['visitLimit']),
      remainingVisits: _asInt(data['remainingVisits']),
      startDate: _asDateTime(data['startDate']),
      endDate: _asDateTime(data['endDate']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  final String id;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? packageId;
  final String? status;
  final int? sessionsCount;
  final String? replaceComment;
  final String? packageName;
  final num? packagePrice;
  final int? packageDurationDays;
  final bool? isUnlimited;
  final int? visitLimit;
  final int? remainingVisits;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;

  int get sortPriority {
    return switch (normalizedStatus) {
      'active' => 0,
      'scheduled' => 1,
      'expired' => 2,
      'cancelled' => 3,
      'replaced' => 4,
      _ => 3,
    };
  }

  String get normalizedStatus {
    final rawStatus = status?.trim().toLowerCase();
    if (rawStatus == 'replaced' || rawStatus == 'cancelled') {
      return rawStatus!;
    }

    final now = DateTime.now();
    final start = startDate;
    final end = endDate;

    if (start != null && end != null) {
      if (now.isBefore(start)) {
        return 'scheduled';
      }

      if (now.isAfter(end)) {
        return 'expired';
      }

      return 'active';
    }

    return rawStatus ?? 'active';
  }

  int? get visitsUsed {
    if (visitLimit == null) {
      return null;
    }

    return visitLimit! - (remainingVisits ?? 0);
  }
}

class ClientSessionSummary {
  const ClientSessionSummary({
    required this.id,
    this.clientId,
    this.subscriptionId,
    this.status,
    this.locker,
    this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory ClientSessionSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return ClientSessionSummary(
      id: snapshot.id,
      clientId: _asString(data['clientId']),
      subscriptionId: _asString(data['subscriptionId']),
      status: _asString(data['status']),
      locker: _asString(data['locker']),
      createdAt: _asDateTime(data['createdAt']),
      startedAt: _asDateTime(data['startedAt']),
      endedAt: _asDateTime(data['endedAt']),
    );
  }

  final String id;
  final String? clientId;
  final String? subscriptionId;
  final String? status;
  final String? locker;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  DateTime? get effectiveDate => startedAt ?? endedAt ?? createdAt;
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

num? _asNum(dynamic value) {
  if (value is num) {
    return value;
  }

  if (value is String) {
    return num.tryParse(value.trim());
  }

  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }

  return null;
}
