import 'package:cloud_firestore/cloud_firestore.dart';

class BarCheckItem {
  const BarCheckItem({
    required this.id,
    this.checkId,
    this.productId,
    this.name,
    this.price,
    this.qty,
    this.subtotal,
  });

  factory BarCheckItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final price = _asNum(data['price']);
    final qty = _asNum(data['qty'])?.toInt();

    return BarCheckItem(
      id: snapshot.id,
      checkId: _asString(data['checkId']),
      productId: _asString(data['productId']),
      name: _asString(data['name']),
      price: price,
      qty: qty,
      subtotal: _asNum(data['subtotal']) ?? ((price ?? 0) * (qty ?? 0)),
    );
  }

  final String id;
  final String? checkId;
  final String? productId;
  final String? name;
  final num? price;
  final int? qty;
  final num? subtotal;

  String get displayName => name ?? productId ?? id;
  int get quantity => qty ?? 0;
  num get unitPrice => price ?? 0;
  num get total => subtotal ?? (unitPrice * quantity);
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
