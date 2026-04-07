import 'package:cloud_firestore/cloud_firestore.dart';

class BarIncomingInvoiceSummary {
  const BarIncomingInvoiceSummary({
    required this.id,
    this.invoiceNumber,
    required this.items,
    this.total,
    this.createdAt,
  });

  factory BarIncomingInvoiceSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => BarIncomingInvoiceItem(
                  productId: _asString(item['productId']) ?? '',
                  name: _asString(item['name']),
                  quantity: _asNum(item['quantity'])?.toInt() ?? 0,
                  purchasePrice: _asNum(item['purchasePrice']) ?? 0,
                ),
              )
              .toList(growable: false)
        : const <BarIncomingInvoiceItem>[];

    return BarIncomingInvoiceSummary(
      id: snapshot.id,
      invoiceNumber: _asString(data['invoiceNumber']),
      items: items,
      total: _asNum(data['total']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  final String id;
  final String? invoiceNumber;
  final List<BarIncomingInvoiceItem> items;
  final num? total;
  final DateTime? createdAt;

  int get totalQuantity =>
      items.fold<int>(0, (acc, item) => acc + item.quantity);
}

class BarIncomingInvoiceItem {
  const BarIncomingInvoiceItem({
    required this.productId,
    this.name,
    required this.quantity,
    required this.purchasePrice,
  });

  final String productId;
  final String? name;
  final int quantity;
  final num purchasePrice;

  num get lineTotal => quantity * purchasePrice;
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
