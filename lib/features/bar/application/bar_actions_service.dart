import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

final barActionsServiceProvider = Provider<BarActionsService>((ref) {
  final session = ref.watch(bootstrapControllerProvider).session;

  return BarActionsService(
    firestore: ref.watch(firebaseFirestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    storage: ref.watch(firebaseStorageProvider),
    gymId: session?.gymId,
  );
});

class BarCategoryUpsertRequest {
  const BarCategoryUpsertRequest({required this.name});

  final String name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name.trim()};
  }
}

class BarProductCreateRequest {
  const BarProductCreateRequest({
    required this.categoryId,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  final String categoryId;
  final String name;
  final num price;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categoryId': categoryId.trim(),
      'name': name.trim(),
      'price': price,
      'image': imageUrl?.trim().isEmpty == true ? '' : imageUrl?.trim(),
      'isActive': true,
    };
  }
}

class BarProductUpdateRequest {
  const BarProductUpdateRequest({
    required this.name,
    required this.price,
    this.imageUrl,
  });

  final String name;
  final num price;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'price': price,
      'image': imageUrl?.trim().isEmpty == true ? '' : imageUrl?.trim(),
    };
  }
}

class BarIncomingItemRequest {
  const BarIncomingItemRequest({
    required this.productId,
    required this.quantity,
    required this.purchasePrice,
  });

  final String productId;
  final int quantity;
  final num purchasePrice;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId.trim(),
      'quantity': quantity,
      'purchasePrice': purchasePrice,
    };
  }
}

class BarDebtCheckSnapshot {
  const BarDebtCheckSnapshot({
    required this.id,
    this.status,
    this.totalAmount,
    this.debtAmount,
  });

  factory BarDebtCheckSnapshot.fromMap(Map<String, dynamic> data) {
    return BarDebtCheckSnapshot(
      id: data['id']?.toString() ?? '',
      status: data['status']?.toString(),
      totalAmount: _asNum(data['totalAmount']),
      debtAmount: _asNum(data['debtAmount']),
    );
  }

  final String id;
  final String? status;
  final num? totalAmount;
  final num? debtAmount;
}

class BarClientDebtSnapshot {
  const BarClientDebtSnapshot({
    required this.totalDebt,
    required this.unpaidChecks,
  });

  factory BarClientDebtSnapshot.fromMap(Map<String, dynamic> data) {
    final unpaidChecksValue = data['unpaidChecks'];
    final unpaidChecks = unpaidChecksValue is List
        ? unpaidChecksValue
              .whereType<Map>()
              .map(
                (item) => BarDebtCheckSnapshot.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <BarDebtCheckSnapshot>[];

    return BarClientDebtSnapshot(
      totalDebt: _asNum(data['totalDebt']) ?? 0,
      unpaidChecks: unpaidChecks,
    );
  }

  final num totalDebt;
  final List<BarDebtCheckSnapshot> unpaidChecks;
}

class BarActionsService {
  const BarActionsService({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseStorage storage,
    required this.gymId,
  }) : _firestore = firestore,
       _functions = functions,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final String? gymId;

  Future<String?> findDraftCheckId({required String sessionId}) async {
    final normalizedSessionId = sessionId.trim();
    final normalizedGymId = gymId?.trim();

    if (normalizedGymId == null ||
        normalizedGymId.isEmpty ||
        normalizedSessionId.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('barChecks')
        .where('sessionId', isEqualTo: normalizedSessionId)
        .where('status', isEqualTo: 'draft')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first.id;
  }

  Future<String?> getOrCreateOpenCheck({
    String? clientId,
    String? sessionId,
  }) async {
    final normalizedGymId = gymId?.trim();
    final normalizedClientId = clientId?.trim();
    final normalizedSessionId = sessionId?.trim();

    if (normalizedGymId == null || normalizedGymId.isEmpty) {
      throw Exception('Missing bar POS contract inputs.');
    }

    if (normalizedSessionId != null && normalizedSessionId.isNotEmpty) {
      final existingCheckId = await findDraftCheckId(
        sessionId: normalizedSessionId,
      );
      if (existingCheckId != null && existingCheckId.isNotEmpty) {
        return existingCheckId;
      }
    }

    final response = await _functions.httpsCallable('createCheck').call(
      <String, dynamic>{
        'clientId':
            normalizedClientId == null || normalizedClientId.isEmpty
            ? null
            : normalizedClientId,
        'sessionId':
            normalizedSessionId == null || normalizedSessionId.isEmpty
            ? null
            : normalizedSessionId,
      },
    );

    final data = _asMap(response.data);
    final nestedCheck = _asMap(data['check']);
    final checkId =
        data['checkId']?.toString() ?? nestedCheck['id']?.toString();

    if (checkId == null || checkId.trim().isEmpty) {
      throw Exception('createCheck did not return a checkId.');
    }

    return checkId.trim();
  }

  Future<void> addItemToCheck({
    required String checkId,
    required String productId,
    int qty = 1,
  }) async {
    await _functions.httpsCallable('addItem').call(<String, dynamic>{
      'checkId': checkId.trim(),
      'productId': productId.trim(),
      'qty': qty,
    });
  }

  Future<void> removeItemFromCheck({
    required String checkId,
    required String productId,
    int qty = 1,
  }) async {
    await _functions.httpsCallable('removeItem').call(<String, dynamic>{
      'checkId': checkId.trim(),
      'productId': productId.trim(),
      'qty': qty,
    });
  }

  Future<void> payCheck({
    required String checkId,
    required Map<String, num> methods,
  }) async {
    final payments = methods.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => <String, dynamic>{
            'method': entry.key,
            'amount': entry.value,
          },
        )
        .toList(growable: false);

    if (payments.isEmpty) {
      throw Exception('At least one bar payment method is required.');
    }

    await _functions.httpsCallable('payCheck').call(<String, dynamic>{
      'checkId': checkId.trim(),
      'payments': payments,
      'idempotencyKey':
          '${checkId.trim()}-${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  Future<void> voidCheck({required String checkId}) async {
    try {
      await _functions.httpsCallable('voidCheck').call(<String, dynamic>{
        'checkId': checkId.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to void check'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> holdCheck({required String checkId}) async {
    try {
      await _functions.httpsCallable('holdCheck').call(<String, dynamic>{
        'checkId': checkId.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to hold check'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> refundCheck({required String checkId}) async {
    final normalizedCheckId = checkId.trim();
    if (normalizedCheckId.isEmpty) {
      throw Exception('Missing checkId');
    }

    try {
      await _functions.httpsCallable('refundCheck').call(<String, dynamic>{
        'checkId': normalizedCheckId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to refund check'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<BarClientDebtSnapshot> checkClientDebt({
    required String clientId,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    try {
      final result = await _functions.httpsCallable('checkClientDebt').call(
        <String, dynamic>{'clientId': normalizedClientId},
      );
      final data = _asMap(result.data);
      return BarClientDebtSnapshot.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to check client debt'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> createCategory({
    required BarCategoryUpsertRequest request,
  }) async {
    if (request.name.trim().isEmpty) {
      throw Exception('Category name is required');
    }

    try {
      await _functions
          .httpsCallable('createBarCategory')
          .call(request.toJson());
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create category'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> updateCategory({
    required String categoryId,
    required BarCategoryUpsertRequest request,
  }) async {
    final normalizedCategoryId = categoryId.trim();
    if (normalizedCategoryId.isEmpty) {
      throw Exception('Missing categoryId');
    }

    if (request.name.trim().isEmpty) {
      throw Exception('Category name is required');
    }

    try {
      await _functions.httpsCallable('updateBarCategory').call(
        <String, dynamic>{
          'categoryId': normalizedCategoryId,
          ...request.toJson(),
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to update category'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> deleteCategory({required String categoryId}) async {
    final normalizedCategoryId = categoryId.trim();
    if (normalizedCategoryId.isEmpty) {
      throw Exception('Missing categoryId');
    }

    try {
      await _functions.httpsCallable('deleteBarCategory').call(
        <String, dynamic>{'categoryId': normalizedCategoryId},
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to delete category'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final normalizedFileName = fileName.trim();
    if (bytes.isEmpty) {
      throw Exception('Missing image bytes');
    }

    final extension = _fileExtension(normalizedFileName);
    final fileSuffix = extension == null ? '' : '.$extension';
    final baseName = normalizedFileName.isEmpty
        ? 'product'
        : normalizedFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final uploadPath =
        'barProducts/${DateTime.now().millisecondsSinceEpoch}-$baseName$fileSuffix';
    final ref = _storage.ref().child(uploadPath);

    try {
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> createProduct({required BarProductCreateRequest request}) async {
    if (request.categoryId.trim().isEmpty) {
      throw Exception('Category is required');
    }

    if (request.name.trim().isEmpty) {
      throw Exception('Product name is required');
    }

    try {
      await _functions.httpsCallable('createBarProduct').call(<String, dynamic>{
        'data': request.toJson(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create product'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> updateProduct({
    required String productId,
    required BarProductUpdateRequest request,
  }) async {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) {
      throw Exception('Missing productId');
    }

    if (request.name.trim().isEmpty) {
      throw Exception('Product name is required');
    }

    try {
      await _functions.httpsCallable('updateBarProduct').call(<String, dynamic>{
        'productId': normalizedProductId,
        'updates': request.toJson(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to update product'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> deleteProduct({required String productId}) async {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) {
      throw Exception('Missing productId');
    }

    try {
      await _functions.httpsCallable('deleteBarProduct').call(<String, dynamic>{
        'productId': normalizedProductId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to delete product'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> createIncoming({
    required List<BarIncomingItemRequest> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('At least one incoming item is required');
    }

    try {
      await _functions.httpsCallable('createBarIncoming').call(
        <String, dynamic>{
          'items': items.map((item) => item.toJson()).toList(growable: false),
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create incoming'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> deleteIncoming({required String incomingId}) async {
    final normalizedIncomingId = incomingId.trim();
    if (normalizedIncomingId.isEmpty) {
      throw Exception('Missing incomingId');
    }

    try {
      await _functions.httpsCallable('deleteBarIncoming').call(
        <String, dynamic>{'incomingId': normalizedIncomingId},
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to delete incoming'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  return const <String, dynamic>{};
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

String? _fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }

  return fileName.substring(dotIndex + 1).trim();
}

String _firebaseMessage(FirebaseFunctionsException error, String fallback) {
  return error.details?.toString() ?? error.message ?? fallback;
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
