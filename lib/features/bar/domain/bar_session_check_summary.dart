import 'package:cloud_firestore/cloud_firestore.dart';

class BarSessionCheckSummary {
  const BarSessionCheckSummary({
    required this.id,
    this.status,
    this.totalAmount,
    this.paidAmount,
    this.debtAmount,
    this.itemCount,
    this.createdAt,
  });

  factory BarSessionCheckSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return BarSessionCheckSummary(
      id: snapshot.id,
      status: _asString(data['status']),
      totalAmount: _asNum(data['totalAmount']),
      paidAmount: _asNum(data['paidAmount']),
      debtAmount: _asNum(data['debtAmount']),
      itemCount: _asNum(data['itemCount'])?.toInt(),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  final String id;
  final String? status;
  final num? totalAmount;
  final num? paidAmount;
  final num? debtAmount;
  final int? itemCount;
  final DateTime? createdAt;

  bool get isDraft => status == 'draft';
  bool get isHeld => status == 'held';
  bool get isPaid => status == 'paid';
  bool get isRefunded => status == 'refunded';
  bool get blocksSessionEnd => isDraft || isHeld;
  String get displayStatus => status ?? 'unknown';
}

String buildSessionEndBlockedMessage(
  String clientLabel,
  Iterable<BarSessionCheckSummary> checks,
) {
  final pendingChecks = checks
      .where((check) => check.blocksSessionEnd)
      .toList(growable: false);
  if (pendingChecks.isEmpty) {
    return '';
  }

  final normalizedClientLabel = clientLabel.trim().isEmpty
      ? 'This client'
      : clientLabel.trim();
  final heldCount = pendingChecks.where((check) => check.isHeld).length;

  if (pendingChecks.length == 1 && heldCount == 1) {
    return '$normalizedClientLabel uchun bar\'da yopilmagan chek bor. Avval payment qiling, keyin sessionni yoping.';
  }
  if (pendingChecks.length == 1) {
    return '$normalizedClientLabel uchun bar\'da ochiq chek bor. Avval payment qiling, keyin sessionni yoping.';
  }
  if (heldCount == pendingChecks.length) {
    return '$normalizedClientLabel uchun bar\'da ${pendingChecks.length} ta yopilmagan chek bor. Avval payment qiling, keyin sessionni yoping.';
  }

  return '$normalizedClientLabel uchun bar\'da ${pendingChecks.length} ta ochiq chek bor. Avval payment qiling, keyin sessionni yoping.';
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

  return null;
}
