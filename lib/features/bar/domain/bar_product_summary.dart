import 'package:cloud_firestore/cloud_firestore.dart';

class BarProductSummary {
  const BarProductSummary({
    required this.id,
    required this.name,
    this.categoryId,
    this.image,
    this.price,
    this.stock,
    required this.isActive,
  });

  factory BarProductSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return BarProductSummary(
      id: snapshot.id,
      name: _asString(data['name']) ?? 'Unnamed product',
      categoryId: _asString(data['categoryId']),
      image: _asString(data['image']),
      price: _asNum(data['price']),
      stock: _asNum(data['stock'])?.toInt(),
      isActive: data['isActive'] == true,
    );
  }

  final String id;
  final String name;
  final String? categoryId;
  final String? image;
  final num? price;
  final int? stock;
  final bool isActive;

  int get availableStock => stock ?? 0;
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
