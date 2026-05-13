import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/backend_action_error.dart';
import '../../../core/utils/billing_notice.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_control_widgets.dart';
import '../../../core/widgets/app_filter_chip_strip.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../../models/payment_amounts.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/domain/gym_session_summary.dart';
import '../application/bar_actions_service.dart';
import '../application/bar_providers.dart';
import '../domain/bar_category_summary.dart';
import '../domain/bar_check_item.dart';
import '../domain/bar_product_summary.dart';
import '../domain/bar_session_check_summary.dart';

class BarPosScreen extends ConsumerStatefulWidget {
  const BarPosScreen({
    super.key,
    this.clientId,
    this.sessionId,
    this.isGuestMode = false,
  });

  final String? clientId;
  final String? sessionId;
  final bool isGuestMode;

  @override
  ConsumerState<BarPosScreen> createState() => _BarPosScreenState();
}

class _BarPosScreenState extends ConsumerState<BarPosScreen> {
  String? _selectedCategoryId;
  String? _activeCheckId;
  String? _statusMessage;
  bool _statusIsError = false;
  /// Set to `true` after a backend action fails with the gym-read-only
  /// signature, even when the gym profile itself doesn't carry the
  /// `isReadOnly` flag yet. Lets us flip into the friendly billing banner
  /// without a Firestore round-trip.
  bool _backendReportedReadOnly = false;

  /// Debug-only local-cart mode. When toggled on (long-press the billing
  /// banner in debug builds), POS mutations stay client-side: the
  /// optimistic delta map is updated but no Cloud Function is called. Lets
  /// owners preview the cart UX while their subscription is paused.
  bool _demoLocalCartMode = false;
  final Map<String, _BarProductPreview> _demoProductMeta =
      <String, _BarProductPreview>{};
  bool _isLoadingDraft = true;
  bool _isPaying = false;
  bool _isPreparingCartAction = false;
  bool _isCreatingCategory = false;
  bool _isCategoryComposerVisible = false;
  final Set<String> _syncingProductIds = <String>{};
  final Map<String, int> _queuedProductDeltas = <String, int>{};
  final Map<String, int> _optimisticProductDeltas = <String, int>{};
  final Map<String, _BarProductPreview> _optimisticProductPreviews =
      <String, _BarProductPreview>{};
  final ValueNotifier<_BarActiveCartState> _activeCartStateNotifier =
      ValueNotifier(const _BarActiveCartState());
  _BarActiveCartState? _pendingActiveCartState;
  Map<String, int> _lastServerQuantities = <String, int>{};
  final GlobalKey _cartActionKey = GlobalKey();
  final TextEditingController _newCategoryController = TextEditingController();
  final FocusNode _newCategoryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingDraftCheck());
  }

  Future<void> _loadExistingDraftCheck() async {
    if (widget.isGuestMode) {
      if (mounted) {
        setState(() => _isLoadingDraft = false);
      }
      return;
    }

    try {
      final sessionId = widget.sessionId?.trim() ?? '';
      if (sessionId.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingDraft = false);
        }
        return;
      }

      final checkId = await ref
          .read(barActionsServiceProvider)
          .findDraftCheckId(sessionId: sessionId);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = checkId;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(_readableError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingDraft = false);
      }
    }
  }

  void _setStatus(String message, {required bool isError}) {
    final normalizedMessage = isError
        ? describeBackendActionError(message, fallback: message).trim()
        : message.trim();
    final resolvedMessage = normalizedMessage.isEmpty
        ? (isError ? 'Something went wrong.' : message)
        : normalizedMessage;

    final looksLikeReadOnly =
        isError && isGymBillingReadOnlyError(message);

    setState(() {
      if (looksLikeReadOnly) {
        // Promote the error into the friendly billing banner instead of
        // showing it as a generic red "Bar action failed" card.
        _backendReportedReadOnly = true;
        _statusMessage = null;
        _statusIsError = false;
      } else {
        _statusMessage = resolvedMessage;
        _statusIsError = isError;
      }
    });
  }

  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    final clientId = widget.clientId?.trim() ?? '';
    if (!widget.isGuestMode && clientId.isNotEmpty) {
      context.go(AppRoutes.clientsWithHighlight(clientId));
      return;
    }

    context.go(AppRoutes.barMenu);
  }

  @override
  void dispose() {
    _activeCartStateNotifier.dispose();
    _newCategoryController.dispose();
    _newCategoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addProduct(BarProductSummary product) async {
    if (_isPaying) {
      return;
    }

    final preview = _BarProductPreview(
      productId: product.id,
      name: product.name,
      price: product.price ?? 0,
    );

    if (_demoLocalCartMode) {
      _applyDemoDelta(product.id, 1, preview);
      return;
    }

    _enqueueProductMutation(
      productId: product.id,
      delta: 1,
      preview: preview,
    );
  }

  Future<void> _decrementProduct(BarProductSummary product) async {
    if (_isPaying) {
      return;
    }

    if (_displayedQuantityForProduct(product.id) <= 0) {
      return;
    }

    final preview = _BarProductPreview(
      productId: product.id,
      name: product.name,
      price: product.price ?? 0,
    );

    if (_demoLocalCartMode) {
      _applyDemoDelta(product.id, -1, preview);
      return;
    }

    _enqueueProductMutation(
      productId: product.id,
      delta: -1,
      preview: preview,
    );
  }

  /// Local-only mutation used by [_demoLocalCartMode]. Bypasses the queue
  /// and the backend; touches just the optimistic delta map so the grid +
  /// floating cart pill react instantly.
  void _applyDemoDelta(String productId, int delta, _BarProductPreview preview) {
    final key = productId.trim();
    if (key.isEmpty) return;

    setState(() {
      final current = _optimisticProductDeltas[key] ?? 0;
      final next = math.max(0, current + delta);
      if (next == 0) {
        _optimisticProductDeltas.remove(key);
        _optimisticProductPreviews.remove(key);
        _demoProductMeta.remove(key);
      } else {
        _optimisticProductDeltas[key] = next;
        _optimisticProductPreviews[key] = preview;
        _demoProductMeta[key] = preview;
      }
    });
  }

  Future<void> _increaseItem(BarCheckItem item) async {
    if (_activeCheckId == null || item.productId == null || _isPaying) {
      return;
    }

    _enqueueProductMutation(
      productId: item.productId!,
      delta: 1,
      preview: _BarProductPreview(
        productId: item.productId!,
        name: item.displayName,
        price: item.unitPrice,
      ),
    );
  }

  Future<void> _removeItem(BarCheckItem item) async {
    if (_activeCheckId == null || item.productId == null || _isPaying) {
      return;
    }

    final productId = item.productId!;
    if (_displayedQuantityForProduct(productId) <= 0) {
      return;
    }

    _enqueueProductMutation(
      productId: productId,
      delta: -1,
      preview: _BarProductPreview(
        productId: productId,
        name: item.displayName,
        price: item.unitPrice,
      ),
    );
  }

  Future<bool> _holdCheck() async {
    final checkId = _activeCheckId;
    if (checkId == null || checkId.isEmpty || _isPaying) {
      return false;
    }

    try {
      await ref.read(barActionsServiceProvider).holdCheck(checkId: checkId);

      if (!mounted) {
        return false;
      }

      setState(() {
        _activeCheckId = null;
        _clearLocalCartState();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Receipt saved for later.')),
        );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      _setStatus(_readableError(error), isError: true);
      return false;
    }
  }

  bool get _hasQueuedCartMutations =>
      _syncingProductIds.isNotEmpty ||
      _queuedProductDeltas.values.any((delta) => delta != 0);

  bool get _hasPendingCartActionCapability =>
      (_activeCheckId?.trim().isNotEmpty ?? false) ||
      _queuedProductDeltas.values.any((delta) => delta != 0) ||
      _syncingProductIds.isNotEmpty ||
      _optimisticProductDeltas.values.any((delta) => delta != 0);

  Future<String?> _prepareActiveCartAction() async {
    if (_isPaying || _isPreparingCartAction) {
      return null;
    }

    setState(() => _isPreparingCartAction = true);
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (mounted) {
        final checkId = _activeCheckId?.trim() ?? '';
        if (checkId.isNotEmpty && !_hasQueuedCartMutations) {
          return checkId;
        }

        if (checkId.isEmpty && !_hasPendingCartActionCapability) {
          return null;
        }

        if (DateTime.now().isAfter(deadline)) {
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      if (!mounted) {
        return null;
      }

      _setStatus('Cart is still syncing. Please wait a moment.', isError: true);
      return null;
    } finally {
      if (mounted) {
        setState(() => _isPreparingCartAction = false);
      }
    }
  }

  Future<bool> _payCheckById({
    required String checkId,
    required num total,
    required bool clearActiveOnSuccess,
  }) async {
    if (checkId.trim().isEmpty || total <= 0 || _isPaying) {
      return false;
    }

    final amounts = await showDialog<PaymentAmounts>(
      context: context,
      builder: (context) => _BarPaymentDialog(total: total),
    );

    if (amounts == null) {
      return false;
    }

    setState(() => _isPaying = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .payCheck(checkId: checkId, methods: amounts.toJson());

      if (!mounted) {
        return false;
      }

      setState(() {
        if (clearActiveOnSuccess && _activeCheckId == checkId) {
          _activeCheckId = null;
          _clearLocalCartState();
        }
        _statusMessage = 'Bar check paid successfully.';
        _statusIsError = false;
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      _setStatus(_readableError(error), isError: true);
      return false;
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Future<bool> _deleteCheck(BarSessionCheckSummary check) async {
    if (_isPaying || check.id.trim().isEmpty) {
      return false;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete check'),
        content: const Text('Delete this check?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return false;
    }

    setState(() => _isPaying = true);

    try {
      await ref.read(barActionsServiceProvider).voidCheck(checkId: check.id);

      if (!mounted) {
        return false;
      }

      setState(() {
        if (_activeCheckId == check.id) {
          _activeCheckId = null;
          _clearLocalCartState();
        }
        _statusMessage = 'Check deleted.';
        _statusIsError = false;
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      _setStatus(_readableError(error), isError: true);
      return false;
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Future<void> _openCartPanel() async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonBox =
        _cartActionKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = math.min(420.0, screenSize.width - 24);
    final anchor = buttonBox?.localToGlobal(Offset.zero, ancestor: overlayBox);
    final top = ((anchor?.dy ?? 72) + (buttonBox?.size.height ?? 0) + 8).clamp(
      16.0,
      screenSize.height - 260.0,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cart',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final navigator = Navigator.of(dialogContext, rootNavigator: true);
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: top,
                  right: 12,
                  child: _BarCartPopover(
                    width: panelWidth,
                    maxHeight: math.min(screenSize.height * 0.76, 620.0),
                    activeCartStateListenable: _activeCartStateNotifier,
                    sessionId: widget.sessionId,
                    isBusy: _isPaying || _isPreparingCartAction,
                    onClose: () => Navigator.of(dialogContext).pop(),
                    onIncrease: _increaseItem,
                    onRemove: _removeItem,
                    onHold: () async {
                      final checkId = await _prepareActiveCartAction();
                      if (checkId == null) {
                        return;
                      }
                      if (navigator.mounted) {
                        navigator.pop();
                      }
                      await _holdCheck();
                    },
                    onPayActive: (total) async {
                      final checkId = await _prepareActiveCartAction();
                      if (checkId == null) {
                        return;
                      }
                      final success = await _payCheckById(
                        checkId: checkId,
                        total: total,
                        clearActiveOnSuccess: true,
                      );
                      if (success && navigator.mounted) {
                        navigator.pop();
                      }
                    },
                    onPayHistory: (check) async {
                      final success = await _payCheckById(
                        checkId: check.id,
                        total: check.totalAmount ?? 0,
                        clearActiveOnSuccess: _activeCheckId == check.id,
                      );
                      if (success && navigator.mounted) {
                        navigator.pop();
                      }
                    },
                    onDeleteCheck: (check) async {
                      final success = await _deleteCheck(check);
                      if (success && navigator.mounted) {
                        navigator.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _enqueueProductMutation({
    required String productId,
    required int delta,
    required _BarProductPreview preview,
  }) {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty || delta == 0) {
      return;
    }

    if (delta < 0 && _displayedQuantityForProduct(normalizedProductId) <= 0) {
      return;
    }

    setState(() {
      _optimisticProductPreviews[normalizedProductId] = preview;
      _queuedProductDeltas[normalizedProductId] =
          (_queuedProductDeltas[normalizedProductId] ?? 0) + delta;
      final optimisticDelta =
          (_optimisticProductDeltas[normalizedProductId] ?? 0) + delta;
      if (optimisticDelta == 0) {
        _optimisticProductDeltas.remove(normalizedProductId);
      } else {
        _optimisticProductDeltas[normalizedProductId] = optimisticDelta;
      }
    });

    unawaited(_flushProductMutations(normalizedProductId));
  }

  Future<void> _flushProductMutations(String productId) async {
    if (_syncingProductIds.contains(productId)) {
      return;
    }

    _syncingProductIds.add(productId);
    final service = ref.read(barActionsServiceProvider);

    try {
      while (mounted) {
        final deltaToSync = _takeQueuedProductDelta(productId);
        if (deltaToSync == 0) {
          break;
        }

        try {
          var checkId = _activeCheckId;
          if (deltaToSync > 0) {
            checkId =
                checkId ??
                await service.getOrCreateOpenCheck(
                  clientId: widget.clientId,
                  sessionId: widget.sessionId,
                );

            if (checkId == null || checkId.isEmpty) {
              throw Exception(
                'Unable to create or resolve the current bar check.',
              );
            }

            await service.addItemToCheck(
              checkId: checkId,
              productId: productId,
              qty: deltaToSync,
            );

            if (mounted && _activeCheckId != checkId) {
              setState(() {
                _activeCheckId = checkId;
              });
            }
            continue;
          }

          if (checkId == null || checkId.isEmpty) {
            throw Exception('There is no active bar check to update.');
          }

          await service.removeItemFromCheck(
            checkId: checkId,
            productId: productId,
            qty: deltaToSync.abs(),
          );
        } catch (error) {
          if (!mounted) {
            return;
          }

          _revertOptimisticDelta(productId, deltaToSync);
          _setStatus(_readableError(error), isError: true);
        }
      }
    } finally {
      _syncingProductIds.remove(productId);
      _cleanupOptimisticPreview(productId);
    }
  }

  int _takeQueuedProductDelta(String productId) {
    final delta = _queuedProductDeltas[productId] ?? 0;
    _queuedProductDeltas.remove(productId);
    return delta;
  }

  void _revertOptimisticDelta(String productId, int delta) {
    setState(() {
      final nextDelta = (_optimisticProductDeltas[productId] ?? 0) - delta;
      if (nextDelta == 0) {
        _optimisticProductDeltas.remove(productId);
      } else {
        _optimisticProductDeltas[productId] = nextDelta;
      }
      _cleanupOptimisticPreview(productId);
    });
  }

  int _displayedQuantityForProduct(String productId) {
    final normalizedProductId = productId.trim();
    return math.max(
      0,
      (_lastServerQuantities[normalizedProductId] ?? 0) +
          (_optimisticProductDeltas[normalizedProductId] ?? 0),
    );
  }

  void _reconcileOptimisticItems(List<BarCheckItem> serverItems) {
    final currentQuantities = <String, int>{};
    for (final item in serverItems) {
      final productKey = _productKeyForItem(item);
      if (productKey.isEmpty) {
        continue;
      }
      currentQuantities[productKey] = item.quantity;
    }

    final trackedProductIds = <String>{
      ..._lastServerQuantities.keys,
      ...currentQuantities.keys,
    };

    for (final productId in trackedProductIds) {
      final previousQuantity = _lastServerQuantities[productId] ?? 0;
      final currentQuantity = currentQuantities[productId] ?? 0;
      final reflectedDelta = currentQuantity - previousQuantity;
      if (reflectedDelta == 0) {
        continue;
      }

      final optimisticDelta = _optimisticProductDeltas[productId];
      if (optimisticDelta == null || optimisticDelta == 0) {
        continue;
      }

      final nextDelta = optimisticDelta - reflectedDelta;
      if (nextDelta == 0) {
        _optimisticProductDeltas.remove(productId);
      } else {
        _optimisticProductDeltas[productId] = nextDelta;
      }
    }

    _lastServerQuantities = currentQuantities;
    for (final productId in _optimisticProductPreviews.keys.toList()) {
      _cleanupOptimisticPreview(productId);
    }
  }

  List<BarCheckItem> _displayedCheckItems(List<BarCheckItem> serverItems) {
    _reconcileOptimisticItems(serverItems);

    final serverItemsByProduct = <String, BarCheckItem>{};
    final orderedProductIds = <String>[];
    for (final item in serverItems) {
      final productKey = _productKeyForItem(item);
      if (productKey.isEmpty || serverItemsByProduct.containsKey(productKey)) {
        continue;
      }
      serverItemsByProduct[productKey] = item;
      orderedProductIds.add(productKey);
    }

    for (final productId in _optimisticProductDeltas.keys) {
      if (!serverItemsByProduct.containsKey(productId)) {
        orderedProductIds.add(productId);
      }
    }

    final displayedItems = <BarCheckItem>[];
    for (final productId in orderedProductIds) {
      final baseItem = serverItemsByProduct[productId];
      final nextQuantity = math.max(
        0,
        (baseItem?.quantity ?? 0) + (_optimisticProductDeltas[productId] ?? 0),
      );
      if (nextQuantity <= 0) {
        continue;
      }

      final preview = _optimisticProductPreviews[productId];
      final unitPrice = baseItem?.unitPrice ?? preview?.price ?? 0;
      displayedItems.add(
        BarCheckItem(
          id: baseItem?.id ?? 'optimistic-$productId',
          checkId: baseItem?.checkId ?? _activeCheckId,
          productId: baseItem?.productId ?? productId,
          name: baseItem?.name ?? preview?.name ?? productId,
          price: unitPrice,
          qty: nextQuantity,
          subtotal: unitPrice * nextQuantity,
        ),
      );
    }

    return displayedItems;
  }

  String _productKeyForItem(BarCheckItem item) {
    final productId = item.productId?.trim() ?? '';
    if (productId.isNotEmpty) {
      return productId;
    }

    return item.id.trim();
  }

  void _cleanupOptimisticPreview(String productId) {
    final normalizedProductId = productId.trim();
    final hasServerValue =
        (_lastServerQuantities[normalizedProductId] ?? 0) > 0;
    final hasOptimisticValue =
        (_optimisticProductDeltas[normalizedProductId] ?? 0) != 0;
    final hasQueuedValue =
        (_queuedProductDeltas[normalizedProductId] ?? 0) != 0;

    if (!hasServerValue && !hasOptimisticValue && !hasQueuedValue) {
      _optimisticProductPreviews.remove(normalizedProductId);
    }
  }

  void _clearLocalCartState() {
    _queuedProductDeltas.clear();
    _optimisticProductDeltas.clear();
    _optimisticProductPreviews.clear();
    _lastServerQuantities = <String, int>{};
    _activeCartStateNotifier.value = const _BarActiveCartState();
  }

  void _syncActiveCartState({
    required List<BarCheckItem> items,
    required bool isLoading,
  }) {
    final nextState = _BarActiveCartState(
      activeCheckId: _activeCheckId,
      items: List<BarCheckItem>.unmodifiable(items),
      isLoading: isLoading,
      canSubmit: items.isNotEmpty && _hasPendingCartActionCapability,
    );

    if (_sameBarActiveCartState(_activeCartStateNotifier.value, nextState) &&
        _pendingActiveCartState == null) {
      return;
    }

    _pendingActiveCartState = nextState;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingState = _pendingActiveCartState;
      if (pendingState == null) {
        return;
      }
      _pendingActiveCartState = null;
      if (_sameBarActiveCartState(
        _activeCartStateNotifier.value,
        pendingState,
      )) {
        return;
      }
      _activeCartStateNotifier.value = pendingState;
    });
  }

  GymSessionSummary? _resolveCurrentSession(List<GymSessionSummary>? sessions) {
    final sessionId = widget.sessionId?.trim() ?? '';
    if (sessionId.isEmpty || sessions == null) {
      return null;
    }

    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }

    return null;
  }

  void _showCategoryComposer() {
    if (_isCreatingCategory) {
      return;
    }

    if (_isCategoryComposerVisible) {
      _newCategoryFocusNode.requestFocus();
      return;
    }

    setState(() => _isCategoryComposerVisible = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _newCategoryFocusNode.requestFocus();
    });
  }

  void _hideCategoryComposer() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isCategoryComposerVisible = false;
      _newCategoryController.clear();
    });
  }

  Future<void> _createCategory() async {
    if (_isCreatingCategory) {
      return;
    }

    final normalizedName = _newCategoryController.text.trim();
    if (normalizedName.isEmpty) {
      _setStatus('Category name is required.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isCreatingCategory = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .createCategory(
            request: BarCategoryUpsertRequest(name: normalizedName),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCategoryComposerVisible = false;
        _newCategoryController.clear();
        _statusMessage = 'Category created.';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(_readableError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCreatingCategory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final resolvedSession = ref.watch(bootstrapControllerProvider).session;
    final categoriesAsync = ref.watch(currentGymBarCategoriesProvider);
    final productsAsync = ref.watch(currentGymBarProductsProvider);
    final sessionsAsync = widget.isGuestMode
        ? const AsyncValue<List<GymSessionSummary>>.data(<GymSessionSummary>[])
        : ref.watch(currentGymSessionsStreamProvider);
    final checkItemsAsync = _activeCheckId == null
        ? const AsyncValue<List<BarCheckItem>>.data(<BarCheckItem>[])
        : ref.watch(barCheckItemsProvider(_activeCheckId!));
    final clientAsync = widget.isGuestMode
        ? const AsyncValue<GymClientDetail?>.data(
            GymClientDetail(id: 'guest', firstName: 'Guest'),
          )
        : ref.watch(
            currentGymClientDocumentProvider(widget.clientId?.trim() ?? ''),
          );
    final currentSession = _resolveCurrentSession(
      _asyncValueData<List<GymSessionSummary>>(sessionsAsync),
    );
    final serverCheckItems =
        _asyncValueData<List<BarCheckItem>>(checkItemsAsync) ??
        const <BarCheckItem>[];
    final checkItems = _displayedCheckItems(serverCheckItems);
    final cartItemCount = checkItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    _syncActiveCartState(
      items: checkItems,
      isLoading:
          (_activeCheckId?.trim().isNotEmpty ?? false) &&
          checkItemsAsync.isLoading &&
          checkItems.isEmpty,
    );
    final canManageCategories = resolvedSession?.role == AllClubsRole.owner;
    final gymProfile = resolvedSession?.gym;
    final isReadOnly = !_demoLocalCartMode &&
        (isGymReadOnly(gymProfile) || _backendReportedReadOnly);
    final billingNotice =
        resolveBillingNotice(gymProfile) ?? gymBillingReadOnlyMessage;
    final isOwner = resolvedSession?.role == AllClubsRole.owner;
    final appBarClientName = clientAsync.maybeWhen(
      data: (client) =>
          widget.isGuestMode ? 'Guest' : client?.fullName ?? 'Client',
      orElse: () => widget.isGuestMode ? 'Guest' : 'Client',
    );
    final appBarLockerValue = currentSession?.displayLocker;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Text(
          appBarClientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _BarCartActionButton(
              key: _cartActionKey,
              itemCount: cartItemCount,
              onTap: _openCartPanel,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _BarAppKeyBadge(value: appBarLockerValue),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            maxWidth: 920,
            expandHeight: true,
            child: clientAsync.when(
              loading: () => const _BarLoadingCard(
                title: 'Client',
                message: 'Loading current client for bar POS...',
              ),
              error: (error, stackTrace) => _BarStatusCard(
                title: 'Client unavailable',
                message: error.toString(),
                isError: true,
              ),
              data: (client) {
                try {
                  if (client == null) {
                    return const _BarStatusCard(
                      title: 'Client unavailable',
                      message:
                          'The client document could not be resolved in the current gym.',
                      isError: true,
                    );
                  }

                  if (categoriesAsync.isLoading ||
                      productsAsync.isLoading ||
                      _isLoadingDraft) {
                    return const _BarLoadingCard(
                      title: 'Bar POS',
                      message:
                          'Loading categories, products, and draft checks...',
                    );
                  }

                  if (categoriesAsync.hasError) {
                    return _BarStatusCard(
                      title: 'Categories unavailable',
                      message: categoriesAsync.error.toString(),
                      isError: true,
                    );
                  }

                  if (productsAsync.hasError) {
                    return _BarStatusCard(
                      title: 'Products unavailable',
                      message: productsAsync.error.toString(),
                      isError: true,
                    );
                  }

                  final categories =
                      categoriesAsync.value ?? const <BarCategorySummary>[];
                  final products =
                      productsAsync.value ?? const <BarProductSummary>[];

                  final selectedCategoryIdForView =
                      _selectedCategoryId != null &&
                          categories.any(
                            (category) => category.id == _selectedCategoryId,
                          )
                      ? _selectedCategoryId
                      : categories.isNotEmpty
                      ? categories.first.id
                      : null;

                  final filteredProducts = selectedCategoryIdForView == null
                      ? products
                      : products
                            .where(
                              (product) =>
                                  product.categoryId ==
                                  selectedCategoryIdForView,
                            )
                            .toList(growable: false);

                  final cartTotal = checkItems.fold<num>(
                    0,
                    (sum, item) => sum + item.total,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isReadOnly) ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: kDebugMode
                                  ? () {
                                      setState(() {
                                        _demoLocalCartMode = true;
                                        _backendReportedReadOnly = false;
                                      });
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Demo POS mode ON — cart is '
                                              'local-only, no backend calls.',
                                            ),
                                          ),
                                        );
                                    }
                                  : null,
                              child: _BarBillingNotice(
                                message: billingNotice,
                                canManageBilling: isOwner,
                                onOpenSubscription: () => context.go(
                                  '${AppRoutes.profile}?section=subscription',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (_demoLocalCartMode) ...[
                            _BarDemoModeNotice(
                              onExit: () {
                                setState(() {
                                  _demoLocalCartMode = false;
                                  _optimisticProductDeltas.clear();
                                  _optimisticProductPreviews.clear();
                                  _demoProductMeta.clear();
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else if (_statusMessage != null &&
                              _statusIsError) ...[
                            _BarStatusCard(
                              title: 'Bar action failed',
                              message: _statusMessage!,
                              isError: _statusIsError,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _BarCategoryRail(
                            categories: categories,
                            selectedCategoryId: selectedCategoryIdForView,
                            onSelect: (categoryId) {
                              setState(() {
                                _selectedCategoryId = categoryId;
                              });
                            },
                            onAddCategory: canManageCategories && !isReadOnly
                                ? _showCategoryComposer
                                : null,
                            onCancelAddCategory: _hideCategoryComposer,
                            onSaveCategory: _createCategory,
                            isAddingCategory: _isCreatingCategory,
                            isComposerVisible: _isCategoryComposerVisible,
                            composerController: _newCategoryController,
                            composerFocusNode: _newCategoryFocusNode,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _BarProductGrid(
                              products: filteredProducts,
                              quantityFor: _displayedQuantityForProduct,
                              onAdd: isReadOnly ? null : _addProduct,
                              onRemove: isReadOnly ? null : _decrementProduct,
                              readOnly: isReadOnly,
                            ),
                          ),
                        ],
                      ),
                      // Floating "View cart" pill (Wolt/Glovo style).
                      if (!isReadOnly)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _BarFloatingCartPill(
                                itemCount: cartItemCount,
                                total: cartTotal,
                                onTap: _openCartPanel,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                } catch (error, stackTrace) {
                  debugPrint('[BarPosScreen] build failure: $error');
                  debugPrintStack(
                    label: '[BarPosScreen] build stack',
                    stackTrace: stackTrace,
                  );
                  return _BarStatusCard(
                    title: 'Bar POS build failed',
                    message: error.toString(),
                    isError: true,
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner shown at the top of POS when the gym is in read-only billing
/// state. Replaces the generic "Bar action failed" error so users see a
/// helpful explanation + an action they can take instead of a wall of red.
class _BarBillingNotice extends StatelessWidget {
  const _BarBillingNotice({
    required this.message,
    required this.canManageBilling,
    required this.onOpenSubscription,
  });

  final String message;

  /// Whether the current user can open the subscription page (owner only).
  final bool canManageBilling;

  final VoidCallback onOpenSubscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF5DC), Color(0xFFFCEAB9)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.warningDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'POS is paused',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningDeep,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12.5,
                    color: AppColors.warningDeep.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
                if (canManageBilling) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.warningDeep,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onOpenSubscription,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open subscription',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny "Demo POS mode" indicator shown when [_demoLocalCartMode] is on.
class _BarDemoModeNotice extends StatelessWidget {
  const _BarDemoModeNotice({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppGradients.primarySubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.primaryDeep, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo POS mode — cart is local, backend disabled.',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: onExit,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDeep,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

/// Wolt/Glovo style floating cart pill — only visible when cart not empty.
class _BarFloatingCartPill extends StatelessWidget {
  const _BarFloatingCartPill({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final num total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: itemCount > 0 ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: itemCount > 0 ? 1.0 : 0.0,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: itemCount > 0 ? onTap : null,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$itemCount',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemCount == 1 ? '1 item' : '$itemCount items',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatAppMoney(total, withUnit: true),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View cart',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarAppKeyBadge extends StatelessWidget {
  const _BarAppKeyBadge({this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = value?.trim().isNotEmpty == true ? value!.trim() : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarProductPreview {
  const _BarProductPreview({
    required this.productId,
    required this.name,
    required this.price,
  });

  final String productId;
  final String name;
  final num price;
}

class _BarActiveCartState {
  const _BarActiveCartState({
    this.activeCheckId,
    this.items = const <BarCheckItem>[],
    this.isLoading = false,
    this.canSubmit = false,
  });

  final String? activeCheckId;
  final List<BarCheckItem> items;
  final bool isLoading;
  final bool canSubmit;
}

bool _sameBarActiveCartState(
  _BarActiveCartState left,
  _BarActiveCartState right,
) {
  if (left.activeCheckId != right.activeCheckId ||
      left.isLoading != right.isLoading ||
      left.canSubmit != right.canSubmit ||
      left.items.length != right.items.length) {
    return false;
  }

  for (var index = 0; index < left.items.length; index++) {
    final leftItem = left.items[index];
    final rightItem = right.items[index];
    if (leftItem.id != rightItem.id ||
        leftItem.productId != rightItem.productId ||
        leftItem.quantity != rightItem.quantity ||
        leftItem.unitPrice != rightItem.unitPrice ||
        leftItem.total != rightItem.total) {
      return false;
    }
  }

  return true;
}

class _BarCategoryRail extends StatelessWidget {
  const _BarCategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.isAddingCategory,
    required this.isComposerVisible,
    required this.composerController,
    required this.composerFocusNode,
    this.onAddCategory,
    this.onCancelAddCategory,
    this.onSaveCategory,
  });

  final List<BarCategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAddCategory;
  final VoidCallback? onCancelAddCategory;
  final Future<void> Function()? onSaveCategory;
  final bool isAddingCategory;
  final bool isComposerVisible;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleComposerAction = isComposerVisible
        ? onCancelAddCategory
        : onAddCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Categories', style: theme.textTheme.titleLarge),
            ),
            if (toggleComposerAction != null)
              IgnorePointer(
                ignoring: isAddingCategory,
                child: Opacity(
                  opacity: isAddingCategory ? 0.62 : 1,
                  child: AppGlassIconButton(
                    icon: isComposerVisible
                        ? Icons.close_rounded
                        : Icons.add_rounded,
                    onTap: toggleComposerAction,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isComposerVisible) ...[
          _BarCategoryComposer(
            controller: composerController,
            focusNode: composerFocusNode,
            isBusy: isAddingCategory,
            onCancel: onCancelAddCategory,
            onSave: onSaveCategory,
          ),
          const SizedBox(height: 10),
        ],
        if (categories.isEmpty)
          AppLiquidGlass(
            borderRadius: BorderRadius.circular(22),
            child: Text(
              'No active categories yet.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          AppFilterChipStrip(
            scrollable: true,
            items: categories
                .map(
                  (category) => AppFilterChipStripItem(
                    id: category.id,
                    label: category.name,
                  ),
                )
                .toList(growable: false),
            selectedId: selectedCategoryId ?? '',
            onSelected: onSelect,
          ),
      ],
    );
  }
}

class _BarCategoryComposer extends StatelessWidget {
  const _BarCategoryComposer({
    required this.controller,
    required this.focusNode,
    required this.isBusy,
    this.onCancel,
    this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBusy;
  final VoidCallback? onCancel;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enabled: !isBusy,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'Drinks',
            ),
            onSubmitted: (_) => onSave?.call(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: isBusy ? null : onCancel,
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: isBusy ? null : () => onSave?.call(),
                icon: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isBusy ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarProductGrid extends StatelessWidget {
  const _BarProductGrid({
    required this.products,
    required this.quantityFor,
    required this.onAdd,
    required this.onRemove,
    this.readOnly = false,
  });

  final List<BarProductSummary> products;
  final int Function(String productId) quantityFor;
  final ValueChanged<BarProductSummary>? onAdd;
  final ValueChanged<BarProductSummary>? onRemove;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Menu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: products.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.inbox_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No products in this category yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.mutedInk,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 760 ? 3 : 2;
                    // Tighter card — image area is square so total height
                    // = (cellWidth) + ~92 (text + stepper). Use a ratio that
                    // adapts to give roughly 1:1.32 portrait cards.
                    final cellWidth = width / crossAxisCount;
                    final cellHeight = cellWidth + 96;
                    final ratio = cellWidth / cellHeight;

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final isOutOfStock = product.availableStock <= 0;
                        final quantity = quantityFor(product.id);

                        return _BarProductCard(
                          product: product,
                          isOutOfStock: isOutOfStock,
                          readOnly: readOnly,
                          quantity: quantity,
                          onAdd: (isOutOfStock || readOnly || onAdd == null)
                              ? null
                              : () => onAdd!(product),
                          onRemove:
                              (quantity > 0 && !readOnly && onRemove != null)
                                  ? () => onRemove!(product)
                                  : null,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Modern food-delivery-style product tile.
///
/// Layout:
///   ┌─────────────────────┐
///   │                     │
///   │     [image 1:1]     │   <- square top half, brand-tinted fallback
///   │                     │
///   │              [+]    │   <- floating add / qty stepper (bottom-right)
///   ├─────────────────────┤
///   │  Name (1 line)      │
///   │  Price              │
///   └─────────────────────┘
///
/// When [quantity] is 0 a single `+` FAB shows. When > 0 the same slot
/// expands into a "- N +" stepper with primary fill.
class _BarProductCard extends StatelessWidget {
  const _BarProductCard({
    required this.product,
    required this.isOutOfStock,
    required this.quantity,
    this.readOnly = false,
    this.onAdd,
    this.onRemove,
  });

  final BarProductSummary product;
  final bool isOutOfStock;
  final int quantity;
  final bool readOnly;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedImage = product.image?.trim() ?? '';
    final inCart = quantity > 0;

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOutOfStock ? null : onAdd,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: inCart
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.45),
              width: inCart ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(
                  alpha: inCart ? 0.10 : 0.05,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== Image (square) =====
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(imageUrl: normalizedImage),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black.withValues(alpha: 0.32),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Out of stock',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    else if (product.availableStock <= 5)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${product.availableStock} left',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.warningDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    if (!readOnly)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _QuantityControl(
                          quantity: quantity,
                          isOutOfStock: isOutOfStock,
                          onAdd: onAdd,
                          onRemove: onRemove,
                        ),
                      ),
                  ],
                ),
              ),
              // ===== Text =====
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatAppMoney(product.price ?? 0, withUnit: true),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image slot with deterministic gradient fallback, network image, and
/// a "broken" state for failed URLs. Used by [_BarProductCard].
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _ProductImagePlaceholder(icon: Icons.local_cafe_rounded);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ProductImagePlaceholder(icon: Icons.local_cafe_rounded);
      },
      errorBuilder: (_, _, _) =>
          const _ProductImagePlaceholder(icon: Icons.broken_image_outlined),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF3FF), Color(0xFFE3ECFE)],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 38, color: AppColors.primary.withValues(alpha: 0.55)),
      ),
    );
  }
}

/// Floating add / quantity-stepper control overlaid on a product image.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.isOutOfStock,
    this.onAdd,
    this.onRemove,
  });

  final int quantity;
  final bool isOutOfStock;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (isOutOfStock) {
      return const SizedBox.shrink();
    }

    if (quantity <= 0) {
      // Single "+" FAB — primary fill, soft shadow.
      return Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onAdd,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ),
      );
    }

    // "- N +" stepper — same height as add FAB so the slot doesn't jump.
    final theme = Theme.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: onRemove,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Container(
              key: ValueKey<int>(quantity),
              constraints: const BoxConstraints(minWidth: 20),
              alignment: Alignment.center,
              child: Text(
                '$quantity',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 38,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _BarCartActionButton extends StatelessWidget {
  const _BarCartActionButton({
    super.key,
    required this.itemCount,
    required this.onTap,
  });

  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_basket_rounded,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (itemCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: Text(
                '$itemCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarCartPopover extends ConsumerWidget {
  const _BarCartPopover({
    required this.width,
    required this.maxHeight,
    required this.activeCartStateListenable,
    required this.sessionId,
    required this.isBusy,
    required this.onClose,
    required this.onIncrease,
    required this.onRemove,
    required this.onHold,
    required this.onPayActive,
    required this.onPayHistory,
    required this.onDeleteCheck,
  });

  final double width;
  final double maxHeight;
  final ValueListenable<_BarActiveCartState> activeCartStateListenable;
  final String? sessionId;
  final bool isBusy;
  final VoidCallback onClose;
  final ValueChanged<BarCheckItem> onIncrease;
  final ValueChanged<BarCheckItem> onRemove;
  final Future<void> Function() onHold;
  final Future<void> Function(num total) onPayActive;
  final Future<void> Function(BarSessionCheckSummary check) onPayHistory;
  final Future<void> Function(BarSessionCheckSummary check) onDeleteCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final normalizedSessionId = sessionId?.trim() ?? '';
    final historyAsync = normalizedSessionId.isEmpty
        ? const AsyncValue<List<BarSessionCheckSummary>>.data(
            <BarSessionCheckSummary>[],
          )
        : ref.watch(barSessionChecksProvider(normalizedSessionId));
    final historyChecks = historyAsync.maybeWhen(
      data: (checks) => checks,
      orElse: () => const <BarSessionCheckSummary>[],
    );

    return DefaultTabController(
      length: 2,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_basket_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Cart', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Active'),
                      Tab(text: 'History'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TabBarView(
                  children: [
                    ValueListenableBuilder<_BarActiveCartState>(
                      valueListenable: activeCartStateListenable,
                      builder: (context, activeCartState, child) {
                        final normalizedActiveCheckId =
                            activeCartState.activeCheckId?.trim() ?? '';
                        final activeCheck = _findCheckById(
                          historyChecks,
                          normalizedActiveCheckId,
                        );
                        final activeCheckNumber = _checkNumberForId(
                          historyChecks,
                          normalizedActiveCheckId,
                        );

                        return _BarCartActiveTab(
                          activeCheckId: normalizedActiveCheckId,
                          activeCheck: activeCheck,
                          activeCheckNumber: activeCheckNumber,
                          items: activeCartState.items,
                          isLoading: activeCartState.isLoading,
                          isBusy: isBusy,
                          canSubmit: activeCartState.canSubmit,
                          onIncrease: onIncrease,
                          onRemove: onRemove,
                          onHold: onHold,
                          onPay: onPayActive,
                        );
                      },
                    ),
                    _BarCartHistoryTab(
                      historyAsync: historyAsync,
                      isBusy: isBusy,
                      onPay: onPayHistory,
                      onDelete: onDeleteCheck,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarCartActiveTab extends StatelessWidget {
  const _BarCartActiveTab({
    required this.activeCheckId,
    required this.activeCheck,
    required this.activeCheckNumber,
    required this.items,
    required this.isLoading,
    required this.isBusy,
    required this.canSubmit,
    required this.onIncrease,
    required this.onRemove,
    required this.onHold,
    required this.onPay,
  });

  final String activeCheckId;
  final BarSessionCheckSummary? activeCheck;
  final int? activeCheckNumber;
  final List<BarCheckItem> items;
  final bool isLoading;
  final bool isBusy;
  final bool canSubmit;
  final ValueChanged<BarCheckItem> onIncrease;
  final ValueChanged<BarCheckItem> onRemove;
  final Future<void> Function() onHold;
  final Future<void> Function(num total) onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final total = items.fold<num>(0, (sum, item) => sum + item.total);
    final hasOpenCheck = activeCheckId.isNotEmpty || items.isNotEmpty;
    final canSubmitCart = canSubmit && total > 0 && !isBusy;

    if (!hasOpenCheck || items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _BarCartEmptyState(
          title: 'No active receipt',
          message: 'Tap a menu item to start a receipt.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check #${activeCheckNumber ?? 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _BarCheckStatusPill(status: activeCheck?.status),
                          if (activeCheck?.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatCheckTime(activeCheck!.createdAt!),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAppMoney(total, withUnit: true),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(color: theme.colorScheme.outlineVariant, height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _BarCheckoutItemRow(
                    item: item,
                    isBusy: isBusy,
                    onIncrease: () => onIncrease(item),
                    onRemove: () => onRemove(item),
                    embedded: true,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canSubmitCart ? () => onPay(total) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.payments_rounded),
                    label: Text(isBusy ? 'Please wait...' : 'Payment'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: canSubmitCart ? onHold : null,
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Later'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarCartHistoryTab extends StatelessWidget {
  const _BarCartHistoryTab({
    required this.historyAsync,
    required this.isBusy,
    required this.onPay,
    required this.onDelete,
  });

  final AsyncValue<List<BarSessionCheckSummary>> historyAsync;
  final bool isBusy;
  final Future<void> Function(BarSessionCheckSummary check) onPay;
  final Future<void> Function(BarSessionCheckSummary check) onDelete;

  @override
  Widget build(BuildContext context) {
    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16),
        child: _BarCartEmptyState(
          title: 'History unavailable',
          message: error.toString(),
        ),
      ),
      data: (checks) {
        if (checks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _BarCartEmptyState(
              title: 'No history yet',
              message: 'Checks for this session will appear here.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: checks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final check = checks[index];
            return _BarHistoryCheckCard(
              check: check,
              checkNumber: index + 1,
              isBusy: isBusy,
              onPay: () => onPay(check),
              onDelete: () => onDelete(check),
            );
          },
        );
      },
    );
  }
}

class _BarHistoryCheckCard extends ConsumerStatefulWidget {
  const _BarHistoryCheckCard({
    required this.check,
    required this.checkNumber,
    required this.isBusy,
    required this.onPay,
    required this.onDelete,
  });

  final BarSessionCheckSummary check;
  final int checkNumber;
  final bool isBusy;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  @override
  ConsumerState<_BarHistoryCheckCard> createState() =>
      _BarHistoryCheckCardState();
}

class _BarHistoryCheckCardState extends ConsumerState<_BarHistoryCheckCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final check = widget.check;
    final canPay =
        (check.isDraft || check.isHeld) && (check.totalAmount ?? 0) > 0;
    final canDelete = check.isDraft || check.isHeld;
    final itemsAsync = _isExpanded
        ? ref.watch(barCheckItemsProvider(check.id))
        : const AsyncValue<List<BarCheckItem>>.data(<BarCheckItem>[]);
    final actions = <Widget>[];

    if (canPay) {
      actions.add(
        Expanded(
          child: FilledButton(
            onPressed: widget.isBusy ? null : widget.onPay,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Payment'),
          ),
        ),
      );
    }

    if (canDelete) {
      actions
        ..add(const SizedBox(width: 8))
        ..add(
          Expanded(
            child: FilledButton.tonal(
              onPressed: widget.isBusy ? null : widget.onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              child: const Text('Delete'),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Check #${widget.checkNumber}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      _BarCheckStatusPill(status: check.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatAppMoney(
                            check.totalAmount ?? 0,
                            withUnit: true,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (check.createdAt != null) ...[
                        Text(
                          _formatCheckTime(check.createdAt!),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: actions),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        Divider(color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 10),
                        _BarHistoryItemsSection(itemsAsync: itemsAsync),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BarHistoryItemsSection extends StatelessWidget {
  const _BarHistoryItemsSection({required this.itemsAsync});

  final AsyncValue<List<BarCheckItem>> itemsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          error.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No items found for this check.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        }

        final estimatedHeight = math.min(
          math.max(items.length * 74.0, 76.0),
          220.0,
        );

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Scrollbar(
            thumbVisibility: items.length > 2,
            child: SizedBox(
              height: estimatedHeight,
              child: ListView.separated(
                primary: false,
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _BarHistoryItemRow(item: item);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarCheckStatusPill extends StatelessWidget {
  const _BarCheckStatusPill({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = status?.trim().toLowerCase() ?? 'unknown';
    final Color background;
    final Color foreground;

    switch (normalized) {
      case 'paid':
        background = Colors.green.withValues(alpha: 0.16);
        foreground = Colors.green.shade700;
        break;
      default:
        background = Colors.orange.withValues(alpha: 0.18);
        foreground = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized == 'paid' ? 'Paid' : 'Unpaid',
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BarCartEmptyState extends StatelessWidget {
  const _BarCartEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarCheckoutItemRow extends StatelessWidget {
  const _BarCheckoutItemRow({
    required this.item,
    required this.isBusy,
    required this.onIncrease,
    required this.onRemove,
    this.embedded = false,
  });

  final BarCheckItem item;
  final bool isBusy;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: embedded
          ? const EdgeInsets.symmetric(vertical: 10)
          : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: embedded
            ? Colors.transparent
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${formatAppMoney(item.unitPrice, withUnit: true)} x ${item.quantity}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatAppMoney(item.total, withUnit: true),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: isBusy ? null : onRemove,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
          ),
          IconButton.filledTonal(
            onPressed: isBusy ? null : onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _BarHistoryItemRow extends StatelessWidget {
  const _BarHistoryItemRow({required this.item});

  final BarCheckItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${formatAppMoney(item.unitPrice, withUnit: true)} x ${item.quantity}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatAppMoney(item.total, withUnit: true),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPaymentDialog extends StatefulWidget {
  const _BarPaymentDialog({required this.total});

  final num total;

  @override
  State<_BarPaymentDialog> createState() => _BarPaymentDialogState();
}

enum _PaymentMethod { cash, terminal, click, debt }

class _BarPaymentDialogState extends State<_BarPaymentDialog> {
  late final TextEditingController _cashController;
  late final TextEditingController _terminalController;
  late final TextEditingController _clickController;
  late final TextEditingController _debtController;
  _PaymentMethod _selectedMethod = _PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: _formatMoneyDisplay(widget.total),
    );
    _terminalController = TextEditingController(text: '0');
    _clickController = TextEditingController(text: '0');
    _debtController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _cashController.dispose();
    _terminalController.dispose();
    _clickController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  PaymentAmounts get _amounts => PaymentAmounts(
    cash: _readAmount(_cashController),
    terminal: _readAmount(_terminalController),
    click: _readAmount(_clickController),
    debt: _readAmount(_debtController),
    total: widget.total,
  );

  TextEditingController _controllerFor(_PaymentMethod method) {
    switch (method) {
      case _PaymentMethod.cash:
        return _cashController;
      case _PaymentMethod.terminal:
        return _terminalController;
      case _PaymentMethod.click:
        return _clickController;
      case _PaymentMethod.debt:
        return _debtController;
    }
  }

  String _labelForMethod(_PaymentMethod method) {
    switch (method) {
      case _PaymentMethod.cash:
        return 'Cash';
      case _PaymentMethod.terminal:
        return 'Card';
      case _PaymentMethod.click:
        return 'P2P';
      case _PaymentMethod.debt:
        return 'Debt';
    }
  }

  IconData _iconForMethod(_PaymentMethod method) {
    switch (method) {
      case _PaymentMethod.cash:
        return Icons.payments_rounded;
      case _PaymentMethod.terminal:
        return Icons.credit_card_rounded;
      case _PaymentMethod.click:
        return Icons.phone_android_rounded;
      case _PaymentMethod.debt:
        return Icons.schedule_rounded;
    }
  }

  num _enteredFor(_PaymentMethod method) {
    return _readAmount(_controllerFor(method));
  }

  num _remainingForSelection(_PaymentMethod method) {
    final selectedAmount = _enteredFor(method);
    final enteredWithoutSelected = _amounts.paidTotal - selectedAmount;
    final remaining = widget.total - enteredWithoutSelected;
    return remaining > 0 ? remaining : 0;
  }

  void _selectMethod(_PaymentMethod method) {
    final controller = _controllerFor(method);
    final currentValue = _readAmount(controller);
    final suggestedValue = _remainingForSelection(method);

    setState(() {
      _selectedMethod = method;
      if (currentValue <= 0 && suggestedValue > 0) {
        controller.text = _formatMoneyDisplay(suggestedValue);
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amounts = _amounts;
    final activeController = _controllerFor(_selectedMethod);

    return AlertDialog(
      title: const Text('Pay bar check'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${formatAppMoney(widget.total, withUnit: true)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Remaining ${formatAppMoney(amounts.remaining, withUnit: true)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: amounts.isBalanced
                      ? Colors.green.shade600
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: _PaymentMethod.values
                    .map(
                      (method) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _PaymentMethodNav(
                            label: _labelForMethod(method),
                            icon: _iconForMethod(method),
                            isSelected: _selectedMethod == method,
                            amount: _enteredFor(method),
                            onTap: () => _selectMethod(method),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              _PaymentSingleField(
                controller: activeController,
                label: _labelForMethod(_selectedMethod),
                icon: _iconForMethod(_selectedMethod),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: amounts.isBalanced
              ? () => Navigator.of(context).pop(amounts)
              : null,
          child: const Text('Confirm payment'),
        ),
      ],
    );
  }
}

class _PaymentMethodNav extends StatelessWidget {
  const _PaymentMethodNav({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.amount,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final num amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount > 0 ? _formatMoneyDisplay(amount) : '0',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSingleField extends StatelessWidget {
  const _PaymentSingleField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [_GroupedNumberInputFormatter()],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _GroupedNumberInputFormatter extends TextInputFormatter {
  const _GroupedNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formatted = _formatMoneyDisplay(int.parse(digits));
    final digitsBeforeCursor = _countDigits(
      newValue.text.substring(
        0,
        newValue.selection.extentOffset.clamp(0, newValue.text.length),
      ),
    );
    final selectionOffset = _selectionOffsetForDigits(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }

  int _countDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '').length;
  }

  int _selectionOffsetForDigits(String formatted, int digitCount) {
    if (digitCount <= 0) {
      return 0;
    }

    var seenDigits = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        seenDigits++;
      }
      if (seenDigits >= digitCount) {
        return i + 1;
      }
    }

    return formatted.length;
  }
}

class _BarLoadingCard extends StatelessWidget {
  const _BarLoadingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _BarStatusCard extends StatelessWidget {
  const _BarStatusCard({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedMessage = isError
        ? describeBackendActionError(message, fallback: message).trim()
        : message.trim();
    final visibleMessage = resolvedMessage.isEmpty
        ? (isError ? 'Something went wrong.' : message)
        : resolvedMessage;

    return Card(
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              visibleMessage,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCheckTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

T? _asyncValueData<T>(AsyncValue<T> value) {
  return value.maybeWhen(data: (data) => data, orElse: () => null);
}

BarSessionCheckSummary? _findCheckById(
  List<BarSessionCheckSummary> checks,
  String checkId,
) {
  for (final check in checks) {
    if (check.id == checkId) {
      return check;
    }
  }

  return null;
}

int? _checkNumberForId(List<BarSessionCheckSummary> checks, String checkId) {
  for (var i = 0; i < checks.length; i++) {
    if (checks[i].id == checkId) {
      return i + 1;
    }
  }

  return null;
}

String _readableError(Object error) {
  final normalized = describeBackendActionError(
    error,
    fallback: 'Something went wrong.',
  ).trim();
  if (normalized.isEmpty) {
    return 'Something went wrong.';
  }

  final lines = normalized
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList(growable: false);
  if (lines.isEmpty) {
    return 'Something went wrong.';
  }

  return lines.first;
}

num _readAmount(TextEditingController controller) {
  final normalized = controller.text.replaceAll(' ', '').trim();
  return num.tryParse(normalized) ?? 0;
}

String _formatMoneyDisplay(num value) {
  final isNegative = value < 0;
  final absolute = value.abs();
  final hasFraction = absolute != absolute.roundToDouble();
  final parts =
      (hasFraction ? absolute.toStringAsFixed(2) : absolute.toInt().toString())
          .split('.');
  final groupedWhole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  final formatted = parts.length == 2
      ? '$groupedWhole.${parts[1]}'
      : groupedWhole;
  return isNegative ? '-$formatted' : formatted;
}
