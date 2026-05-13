import 'package:cloud_firestore/cloud_firestore.dart';

class GymTransactionSummary {
  const GymTransactionSummary({
    required this.id,
    this.clientId,
    this.subscriptionId,
    this.subscriptionStatus,
    this.status,
    this.type,
    this.category,
    this.paymentMethod,
    this.amount,
    this.comment,
    this.createdAt,
    this.sourceCollection,
  });

  factory GymTransactionSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return GymTransactionSummary(
      id: snapshot.id,
      clientId: _asString(data['clientId']),
      subscriptionId: _asString(data['subscriptionId']),
      subscriptionStatus: _asString(data['subscriptionStatus']),
      status: _asString(data['status']),
      type: _normalizeType(_asString(data['type'])),
      category: _asString(data['category']),
      paymentMethod: _resolvePaymentMethod(data),
      amount: _asNum(data['amount']),
      comment: _asString(data['comment']),
      createdAt: _asDateTime(data['createdAt']),
      sourceCollection: snapshot.reference.parent.id,
    );
  }

  final String id;
  final String? clientId;
  final String? subscriptionId;
  final String? subscriptionStatus;
  final String? status;
  final String? type;
  final String? category;
  final String? paymentMethod;
  final num? amount;
  final String? comment;
  final DateTime? createdAt;
  final String? sourceCollection;

  bool get canDeleteFromGymTransactions => sourceCollection == 'transactions';

  GymTransactionSummary copyWith({
    String? subscriptionStatus,
    String? status,
    String? type,
    String? paymentMethod,
    String? sourceCollection,
  }) {
    return GymTransactionSummary(
      id: id,
      clientId: clientId,
      subscriptionId: subscriptionId,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      status: status ?? this.status,
      type: type ?? this.type,
      category: category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount,
      comment: comment,
      createdAt: createdAt,
      sourceCollection: sourceCollection ?? this.sourceCollection,
    );
  }
}

String? _normalizeType(String? value) {
  if (value == 'bar_sale') {
    return 'bar';
  }

  return value;
}

String? _resolvePaymentMethod(Map<String, dynamic> data) {
  final direct = _asString(data['paymentMethod']);
  if (direct != null) {
    return direct;
  }

  final methods = data['methods'];
  if (methods is List && methods.isNotEmpty) {
    return _asString(methods.first);
  }

  return _asString(methods);
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
