import 'package:cloud_firestore/cloud_firestore.dart';

class GymSessionSummary {
  const GymSessionSummary({
    required this.id,
    this.clientId,
    this.clientName,
    this.packageName,
    this.locker,
    this.status,
    this.staffName,
    this.createdBy,
    this.totalAmount,
    this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory GymSessionSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final packageSnapshot = data['packageSnapshot'];
    final packageData = packageSnapshot is Map<String, dynamic>
        ? packageSnapshot
        : packageSnapshot is Map
        ? Map<String, dynamic>.from(packageSnapshot)
        : const <String, dynamic>{};
    final staff = data['staff'];
    final staffData = staff is Map<String, dynamic>
        ? staff
        : staff is Map
        ? Map<String, dynamic>.from(staff)
        : const <String, dynamic>{};

    return GymSessionSummary(
      id: snapshot.id,
      clientId: _asString(data['clientId']),
      clientName: _asString(data['clientName']),
      packageName: _asString(packageData['name']),
      locker: _asString(data['locker']),
      status: _asString(data['status']),
      staffName: _asString(data['staffName']) ?? _asString(staffData['name']),
      createdBy: _asString(data['createdBy']),
      totalAmount: _asNum(data['totalAmount']),
      createdAt: _asDateTime(data['createdAt']),
      startedAt:
          _asDateTime(data['startedAt']) ??
          _asDateTime(data['checkIn']) ??
          _asDateTime(data['checkInAt']),
      endedAt:
          _asDateTime(data['endedAt']) ??
          _asDateTime(data['checkOut']) ??
          _asDateTime(data['checkOutAt']),
    );
  }

  final String id;
  final String? clientId;
  final String? clientName;
  final String? packageName;
  final String? locker;
  final String? status;
  final String? staffName;
  final String? createdBy;
  final num? totalAmount;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  String get displayClientName => clientName ?? 'Unknown client';
  String get displayPackageName => packageName ?? '-';
  String get displayLocker => locker ?? '-';

  String get displayStaffName {
    return staffName ?? createdBy ?? '-';
  }

  bool get isOnline => endedAt == null;

  bool get isActive => status == 'active';

  bool get isClosed => status == 'closed' || status == 'completed';
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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
