import 'package:cloud_firestore/cloud_firestore.dart';

class GymPackageSummary {
  const GymPackageSummary({
    required this.id,
    this.name,
    this.price,
    this.duration,
    this.bonusDays,
    this.visitLimit,
    this.isUnlimited,
    this.startTime,
    this.endTime,
    this.freezeEnabled,
    this.maxFreezeDays,
    this.gender,
    this.gradient,
    this.description,
    this.createdAt,
    this.isArchived,
  });

  factory GymPackageSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return GymPackageSummary(
      id: snapshot.id,
      name: _asString(data['name']),
      price: _asNum(data['price']),
      duration: _asInt(data['duration']),
      bonusDays: _asInt(data['bonusDays']),
      visitLimit: _asInt(data['visitLimit']),
      isUnlimited: _asBool(data['isUnlimited']),
      startTime: _asString(data['startTime']),
      endTime: _asString(data['endTime']),
      freezeEnabled: _asBool(data['freezeEnabled']),
      maxFreezeDays: _asInt(data['maxFreezeDays']),
      gender: _asString(data['gender']),
      gradient: _asString(data['gradient']),
      description: _asString(data['description']),
      createdAt: _asDateTime(data['createdAt']),
      isArchived: _asBool(data['isArchived']),
    );
  }

  final String id;
  final String? name;
  final num? price;
  final int? duration;
  final int? bonusDays;
  final int? visitLimit;
  final bool? isUnlimited;
  final String? startTime;
  final String? endTime;
  final bool? freezeEnabled;
  final int? maxFreezeDays;
  final String? gender;
  final String? gradient;
  final String? description;
  final DateTime? createdAt;
  final bool? isArchived;

  int? get effectiveVisitLimit {
    if (isUnlimited == true) {
      return null;
    }

    if (visitLimit != null) {
      return visitLimit;
    }

    if (duration == null && bonusDays == null) {
      return null;
    }

    return (duration ?? 0) + (bonusDays ?? 0);
  }
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }

  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '');
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) {
    return null;
  }

  return text;
}
