import 'package:cloud_firestore/cloud_firestore.dart';

class GymSessionSummary {
  const GymSessionSummary({
    required this.id,
    this.clientId,
    this.clientName,
    this.packageName,
    this.locker,
    this.status,
    this.paid,
    this.staffName,
    this.createdBy,
    this.totalAmount,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.transactions = const <GymSessionTransactionSummary>[],
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
    final transactions = _asMapList(data['transactions']);

    return GymSessionSummary(
      id: snapshot.id,
      clientId: _asString(data['clientId']),
      clientName: _asString(data['clientName']) ?? _asString(data['client']),
      packageName:
          _asString(data['packageName']) ?? _asString(packageData['name']),
      locker: _asString(data['locker']),
      status: _asString(data['status']),
      paid: _asBool(data['paid']),
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
      transactions: List<GymSessionTransactionSummary>.unmodifiable(
        transactions.asMap().entries.map(
          (entry) => GymSessionTransactionSummary.fromMap(
            entry.value,
            fallbackId: '${snapshot.id}-tx-${entry.key}',
          ),
        ),
      ),
    );
  }

  final String id;
  final String? clientId;
  final String? clientName;
  final String? packageName;
  final String? locker;
  final String? status;
  final bool? paid;
  final String? staffName;
  final String? createdBy;
  final num? totalAmount;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<GymSessionTransactionSummary> transactions;

  String get displayClientName => clientName ?? 'Unknown client';
  String get displayPackageName => packageName ?? '-';
  String get displayLocker => locker ?? '-';

  String get displayStaffName {
    return staffName ?? createdBy ?? '-';
  }

  bool get isOnline => endedAt == null;

  bool get isActive => status == 'active';

  bool get isClosed => status == 'closed' || status == 'completed';

  bool get isPaid => paid == true;

  num get resolvedTotalAmount {
    final direct = totalAmount;
    if (direct != null) {
      return direct;
    }

    return transactions.fold<num>(
      0,
      (total, transaction) => total + (transaction.amount ?? 0),
    );
  }

  num transactionTotalByGroup(String group) {
    final normalizedGroup = group.trim().toLowerCase();
    return transactions.fold<num>(0, (total, transaction) {
      return total +
          (transaction.matchesGroup(normalizedGroup)
              ? (transaction.amount ?? 0)
              : 0);
    });
  }
}

class GymSessionTransactionSummary {
  const GymSessionTransactionSummary({
    required this.id,
    this.name,
    this.title,
    this.type,
    this.category,
    this.paymentMethod,
    this.amount,
    this.createdAt,
  });

  factory GymSessionTransactionSummary.fromMap(
    Map<String, dynamic> data, {
    String? fallbackId,
  }) {
    return GymSessionTransactionSummary(
      id:
          _asString(data['id']) ??
          _asString(data['transactionId']) ??
          fallbackId ??
          'session-tx',
      name: _asString(data['name']) ?? _asString(data['serviceName']),
      title: _asString(data['title']),
      type: _normalizeTransactionGroup(_asString(data['type'])),
      category: _normalizeTransactionGroup(_asString(data['category'])),
      paymentMethod: _asString(data['paymentMethod']),
      amount: _asNum(data['amount']),
      createdAt: _asDateTime(data['createdAt']) ?? _asDateTime(data['date']),
    );
  }

  final String id;
  final String? name;
  final String? title;
  final String? type;
  final String? category;
  final String? paymentMethod;
  final num? amount;
  final DateTime? createdAt;

  String get displayTitle => name ?? title ?? 'Service';

  String? get group => category ?? type;

  bool matchesGroup(String group) {
    final normalizedGroup = group.trim().toLowerCase();
    return this.group?.trim().toLowerCase() == normalizedGroup ||
        type?.trim().toLowerCase() == normalizedGroup ||
        category?.trim().toLowerCase() == normalizedGroup;
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

num? _asNum(dynamic value) {
  if (value is num) {
    return value;
  }

  if (value is String) {
    return num.tryParse(value.trim());
  }

  return null;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  final items = <Map<String, dynamic>>[];
  for (final entry in value) {
    if (entry is Map<String, dynamic>) {
      items.add(entry);
      continue;
    }

    if (entry is Map) {
      items.add(Map<String, dynamic>.from(entry));
    }
  }

  return items;
}

String? _normalizeTransactionGroup(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  switch (normalized) {
    case 'bar_sale':
      return 'bar';
    case 'coach':
      return 'trainer';
    default:
      return normalized;
  }
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
