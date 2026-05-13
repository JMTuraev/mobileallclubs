import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final googlePlayBillingServiceProvider = Provider<GooglePlayBillingService>((
  ref,
) {
  return GooglePlayBillingService(InAppPurchase.instance);
});

class GooglePlayBillingService {
  const GooglePlayBillingService(this._inAppPurchase);

  final InAppPurchase _inAppPurchase;

  Stream<List<PurchaseDetails>> get purchaseStream => _inAppPurchase.purchaseStream;

  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  Future<ProductDetailsResponse> queryProducts(Set<String> productIds) {
    return _inAppPurchase.queryProductDetails(productIds);
  }

  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  Future<bool> buySubscription(ProductDetails product) {
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> completePurchase(PurchaseDetails purchaseDetails) {
    return _inAppPurchase.completePurchase(purchaseDetails);
  }
}
