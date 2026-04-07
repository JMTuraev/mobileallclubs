import 'package:cloud_firestore/cloud_firestore.dart';

class BarCategorySummary {
  const BarCategorySummary({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory BarCategorySummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return BarCategorySummary(
      id: snapshot.id,
      name: _asString(data['name']) ?? 'Unnamed category',
      isActive: data['isActive'] == true,
    );
  }

  final String id;
  final String name;
  final bool isActive;
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}
