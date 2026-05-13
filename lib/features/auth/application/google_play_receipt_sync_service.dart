import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/firebase_clients.dart';

final googlePlayReceiptSyncServiceProvider = Provider<GooglePlayReceiptSyncService>((
  ref,
) {
  return GooglePlayReceiptSyncService(ref.watch(firebaseFirestoreProvider));
});

class GooglePlayReceiptSyncService {
  const GooglePlayReceiptSyncService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> queuePurchase({
    required String gymId,
    required String userId,
    required PurchaseDetails purchase,
  }) async {
    final normalizedGymId = gymId.trim();
    final normalizedUserId = userId.trim();

    if (normalizedGymId.isEmpty || normalizedUserId.isEmpty) {
      throw Exception('Missing gymId or userId for Google Play sync.');
    }

    final purchaseKey = _purchaseKey(purchase);
    final receiptRef = _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('billingPurchaseQueue')
        .doc(purchaseKey);

    await receiptRef.set(<String, dynamic>{
      'source': 'google_play',
      'status': purchase.status.name,
      'gymId': normalizedGymId,
      'userId': normalizedUserId,
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'transactionDate': purchase.transactionDate,
      'verificationData': <String, dynamic>{
        'serverVerificationData':
            purchase.verificationData.serverVerificationData,
        'localVerificationData': purchase.verificationData.localVerificationData,
        'source': purchase.verificationData.source,
      },
      'queuedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

String _purchaseKey(PurchaseDetails purchase) {
  final purchaseId = purchase.purchaseID?.trim();
  if (purchaseId != null && purchaseId.isNotEmpty) {
    return purchaseId;
  }

  final transactionDate = purchase.transactionDate?.trim();
  if (transactionDate != null && transactionDate.isNotEmpty) {
    return '${purchase.productID}_$transactionDate';
  }

  return '${purchase.productID}_${DateTime.now().millisecondsSinceEpoch}';
}
