import 'package:cloud_firestore/cloud_firestore.dart';

class InviteStaffData {
  const InviteStaffData({this.fullName, this.phone, this.photo});

  factory InviteStaffData.fromMap(Map<String, dynamic> data) {
    return InviteStaffData(
      fullName: _asString(data['fullName']),
      phone: _asString(data['phone']),
      photo: _asString(data['photo']),
    );
  }

  final String? fullName;
  final String? phone;
  final String? photo;
}

class GymInviteSummary {
  const GymInviteSummary({
    required this.id,
    this.email,
    this.roleValue,
    this.status,
    this.gymId,
    this.invitedBy,
    this.token,
    this.attempts,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.acceptedAt,
    this.cancelledAt,
    this.staffData = const InviteStaffData(),
  });

  factory GymInviteSummary.fromMap(String id, Map<String, dynamic> data) {
    final staffDataMap = _asMap(data['staffData']);

    return GymInviteSummary(
      id: id,
      email: _asString(data['email']),
      roleValue: _asString(data['role']),
      status: _asString(data['status']),
      gymId: _asString(data['gymId']),
      invitedBy: _asString(data['invitedBy']),
      token: _asString(data['token']),
      attempts: _asInt(data['attempts']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      expiresAt: _asDateTime(data['expiresAt']),
      acceptedAt: _asDateTime(data['acceptedAt']),
      cancelledAt: _asDateTime(data['cancelledAt']),
      staffData: InviteStaffData.fromMap(staffDataMap),
    );
  }

  final String id;
  final String? email;
  final String? roleValue;
  final String? status;
  final String? gymId;
  final String? invitedBy;
  final String? token;
  final int? attempts;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? cancelledAt;
  final InviteStaffData staffData;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  String get displayRole => roleValue ?? 'staff';
  String get displayStatus => status ?? 'unknown';
  String get displayName => staffData.fullName ?? email ?? id;
  String? get displayPhone => staffData.phone;
}

class InviteTokenValidationResult {
  const InviteTokenValidationResult({
    required this.valid,
    this.errorMessage,
    this.invite,
  });

  final bool valid;
  final String? errorMessage;
  final GymInviteSummary? invite;
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) {
    return null;
  }

  return text.trim();
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

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  return const <String, dynamic>{};
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

  if (value is Map) {
    final normalized = value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
    final seconds = _asInt(normalized['_seconds'] ?? normalized['seconds']);
    final nanoseconds =
        _asInt(normalized['_nanoseconds'] ?? normalized['nanoseconds']) ?? 0;

    if (seconds != null) {
      final milliseconds = (seconds * 1000) + (nanoseconds ~/ 1000000);
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
  }

  return null;
}
