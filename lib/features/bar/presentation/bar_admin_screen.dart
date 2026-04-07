import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/bar_actions_service.dart';
import '../application/bar_providers.dart';
import '../domain/bar_category_summary.dart';
import '../domain/bar_incoming_invoice_summary.dart';
import '../domain/bar_product_summary.dart';

class BarAdminScreen extends ConsumerStatefulWidget {
  const BarAdminScreen({super.key});

  @override
  ConsumerState<BarAdminScreen> createState() => _BarAdminScreenState();
}

class _BarAdminScreenState extends ConsumerState<BarAdminScreen> {
  final TextEditingController _newCategoryController = TextEditingController();
  final Map<String, _IncomingDraftItem> _incomingDraft =
      <String, _IncomingDraftItem>{};

  _BarAdminSection _selectedSection = _BarAdminSection.categories;
  String? _selectedProductCategoryId;
  String? _selectedIncomingCategoryId;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isCategoryBusy = false;
  bool _isProductBusy = false;
  bool _isIncomingBusy = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  void _ensureCategoryDefaults(List<BarCategorySummary> categories) {
    if (categories.isEmpty) {
      return;
    }

    if (_selectedProductCategoryId == null ||
        !categories.any(
          (category) => category.id == _selectedProductCategoryId,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedProductCategoryId = categories.first.id);
        }
      });
    }

    if (_selectedIncomingCategoryId == null ||
        !categories.any(
          (category) => category.id == _selectedIncomingCategoryId,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIncomingCategoryId = categories.first.id);
        }
      });
    }
  }

  Future<void> _createCategory() async {
    if (_isCategoryBusy) {
      return;
    }

    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      _setStatus('Category name is required.', isError: true);
      return;
    }

    setState(() => _isCategoryBusy = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .createCategory(request: BarCategoryUpsertRequest(name: name));
      if (!mounted) {
        return;
      }

      _newCategoryController.clear();
      _setStatus('Category created.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCategoryBusy = false);
      }
    }
  }

  Future<void> _editCategory(BarCategorySummary category) async {
    if (_isCategoryBusy) {
      return;
    }

    final nextName = await _showTextPrompt(
      title: 'Edit category',
      label: 'Category name',
      initialValue: category.name,
    );
    if (nextName == null || nextName.trim().isEmpty) {
      return;
    }

    setState(() => _isCategoryBusy = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .updateCategory(
            categoryId: category.id,
            request: BarCategoryUpsertRequest(name: nextName),
          );
      if (!mounted) {
        return;
      }

      _setStatus('Category updated.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCategoryBusy = false);
      }
    }
  }

  Future<void> _deleteCategory(BarCategorySummary category) async {
    if (_isCategoryBusy) {
      return;
    }

    final shouldDelete = await _confirmAction(
      title: 'Delete category?',
      message:
          'This matches the web flow and archives the category by marking it inactive.',
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() => _isCategoryBusy = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .deleteCategory(categoryId: category.id);
      if (!mounted) {
        return;
      }

      _setStatus('Category archived.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCategoryBusy = false);
      }
    }
  }

  Future<void> _createProduct(List<BarCategorySummary> categories) async {
    if (_isProductBusy) {
      return;
    }

    final selectedCategoryId = _selectedProductCategoryId;
    if (selectedCategoryId == null || selectedCategoryId.isEmpty) {
      _setStatus('Select a category before creating a product.', isError: true);
      return;
    }

    final draft = await showDialog<_BarProductDraft>(
      context: context,
      builder: (context) => _BarProductEditorDialog(
        categories: categories,
        initialCategoryId: selectedCategoryId,
      ),
    );
    if (draft == null) {
      return;
    }

    setState(() => _isProductBusy = true);

    try {
      String? imageUrl = draft.existingImageUrl;
      if (draft.imageBytes != null) {
        imageUrl = await ref
            .read(barActionsServiceProvider)
            .uploadProductImage(
              bytes: draft.imageBytes!,
              fileName: draft.imageFileName ?? 'bar-product.jpg',
            );
      }

      await ref
          .read(barActionsServiceProvider)
          .createProduct(
            request: BarProductCreateRequest(
              categoryId: draft.categoryId,
              name: draft.name,
              price: draft.price,
              imageUrl: imageUrl,
            ),
          );
      if (!mounted) {
        return;
      }

      _setStatus('Product created.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProductBusy = false);
      }
    }
  }

  Future<void> _editProduct(
    BarProductSummary product,
    List<BarCategorySummary> categories,
  ) async {
    if (_isProductBusy) {
      return;
    }

    final draft = await showDialog<_BarProductDraft>(
      context: context,
      builder: (context) => _BarProductEditorDialog(
        categories: categories,
        initialCategoryId: product.categoryId,
        initialName: product.name,
        initialPrice: product.price,
        initialImageUrl: product.image,
        isEditing: true,
      ),
    );
    if (draft == null) {
      return;
    }

    setState(() => _isProductBusy = true);

    try {
      String? imageUrl = draft.existingImageUrl;
      if (draft.imageBytes != null) {
        imageUrl = await ref
            .read(barActionsServiceProvider)
            .uploadProductImage(
              bytes: draft.imageBytes!,
              fileName: draft.imageFileName ?? 'bar-product.jpg',
            );
      }

      await ref
          .read(barActionsServiceProvider)
          .updateProduct(
            productId: product.id,
            request: BarProductUpdateRequest(
              name: draft.name,
              price: draft.price,
              imageUrl: imageUrl,
            ),
          );
      if (!mounted) {
        return;
      }

      _setStatus('Product updated.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProductBusy = false);
      }
    }
  }

  Future<void> _deleteProduct(BarProductSummary product) async {
    if (_isProductBusy) {
      return;
    }

    final shouldDelete = await _confirmAction(
      title: 'Delete product?',
      message:
          'This matches the web flow and archives the product by marking it inactive.',
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() => _isProductBusy = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .deleteProduct(productId: product.id);
      if (!mounted) {
        return;
      }

      _setStatus('Product archived.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProductBusy = false);
      }
    }
  }

  void _addIncomingProduct(BarProductSummary product) {
    setState(() {
      final existing = _incomingDraft[product.id];
      _incomingDraft[product.id] = _IncomingDraftItem(
        productId: product.id,
        name: product.name,
        quantity: existing?.quantity ?? 1,
        purchasePrice: existing?.purchasePrice ?? (product.price ?? 0),
      );
    });
  }

  void _changeIncomingQuantity(_IncomingDraftItem item, int delta) {
    final nextQuantity = item.quantity + delta;
    setState(() {
      if (nextQuantity <= 0) {
        _incomingDraft.remove(item.productId);
      } else {
        _incomingDraft[item.productId] = item.copyWith(quantity: nextQuantity);
      }
    });
  }

  Future<void> _editIncomingPrice(_IncomingDraftItem item) async {
    final nextPrice = await _showMoneyPrompt(
      title: 'Set purchase price',
      initialValue: item.purchasePrice,
    );
    if (nextPrice == null) {
      return;
    }

    setState(() {
      _incomingDraft[item.productId] = item.copyWith(purchasePrice: nextPrice);
    });
  }

  Future<void> _saveIncoming() async {
    if (_isIncomingBusy) {
      return;
    }

    if (_incomingDraft.isEmpty) {
      _setStatus(
        'Add at least one product before saving incoming.',
        isError: true,
      );
      return;
    }

    setState(() => _isIncomingBusy = true);

    try {
      final items = _incomingDraft.values
          .map(
            (item) => BarIncomingItemRequest(
              productId: item.productId,
              quantity: item.quantity,
              purchasePrice: item.purchasePrice,
            ),
          )
          .toList(growable: false);
      await ref.read(barActionsServiceProvider).createIncoming(items: items);
      if (!mounted) {
        return;
      }

      setState(_incomingDraft.clear);
      _setStatus('Incoming invoice saved.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isIncomingBusy = false);
      }
    }
  }

  Future<void> _deleteIncoming(BarIncomingInvoiceSummary invoice) async {
    if (_isIncomingBusy) {
      return;
    }

    final shouldDelete = await _confirmAction(
      title: 'Delete incoming invoice?',
      message:
          'This matches the web flow and rolls stock back by deleting the invoice.',
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() => _isIncomingBusy = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .deleteIncoming(incomingId: invoice.id);
      if (!mounted) {
        return;
      }

      _setStatus('Incoming invoice deleted.', isError: false);
    } catch (error) {
      if (mounted) {
        _setStatus(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isIncomingBusy = false);
      }
    }
  }

  Future<String?> _showTextPrompt({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<num?> _showMoneyPrompt({
    required String title,
    required num initialValue,
  }) async {
    final controller = TextEditingController(text: _formatMoney(initialValue));
    return showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Purchase price'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(num.tryParse(controller.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final categoriesAsync = ref.watch(currentGymBarCategoriesProvider);
    final productsAsync = ref.watch(currentGymBarProductsProvider);
    final incomingAsync = ref.watch(currentGymBarIncomingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.barMenu),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to POS menu',
        ),
        title: const Text('Bar admin'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            maxWidth: 860,
            expandHeight: true,
            child: !_canManageBar(session)
                ? const _BarAdminBlockedCard()
                : categoriesAsync.when(
                    loading: () => const _BarAdminLoadingCard(
                      message: 'Loading bar admin contracts...',
                    ),
                    error: (error, stackTrace) => _BarAdminStatusCard(
                      title: 'Bar admin unavailable',
                      message: error.toString(),
                      isError: true,
                    ),
                    data: (categories) {
                      _ensureCategoryDefaults(categories);

                      if (productsAsync.isLoading || incomingAsync.isLoading) {
                        return const _BarAdminLoadingCard(
                          message: 'Loading products and incoming invoices...',
                        );
                      }

                      if (productsAsync.hasError) {
                        return _BarAdminStatusCard(
                          title: 'Products unavailable',
                          message: productsAsync.error.toString(),
                          isError: true,
                        );
                      }

                      if (incomingAsync.hasError) {
                        return _BarAdminStatusCard(
                          title: 'Incoming unavailable',
                          message: incomingAsync.error.toString(),
                          isError: true,
                        );
                      }

                      final products =
                          productsAsync.value ?? const <BarProductSummary>[];
                      final incoming =
                          incomingAsync.value ??
                          const <BarIncomingInvoiceSummary>[];
                      final filteredProducts =
                          _selectedProductCategoryId == null
                          ? products
                          : products
                                .where(
                                  (product) =>
                                      product.categoryId ==
                                      _selectedProductCategoryId,
                                )
                                .toList(growable: false);
                      final filteredIncomingProducts =
                          _selectedIncomingCategoryId == null
                          ? products
                          : products
                                .where(
                                  (product) =>
                                      product.categoryId ==
                                      _selectedIncomingCategoryId,
                                )
                                .toList(growable: false);

                      return Column(
                        children: [
                          if (_statusMessage != null) ...[
                            _BarAdminStatusCard(
                              title: _statusIsError
                                  ? 'Bar admin action failed'
                                  : 'Bar admin',
                              message: _statusMessage!,
                              isError: _statusIsError,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.gym?.name ?? 'Bar admin',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Owner-only category, product, and incoming stock management using the audited production callables.',
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _BarAdminSectionChip(
                                        label: 'Categories',
                                        selected:
                                            _selectedSection ==
                                            _BarAdminSection.categories,
                                        onTap: () {
                                          setState(() {
                                            _selectedSection =
                                                _BarAdminSection.categories;
                                          });
                                        },
                                      ),
                                      _BarAdminSectionChip(
                                        label: 'Products',
                                        selected:
                                            _selectedSection ==
                                            _BarAdminSection.products,
                                        onTap: () {
                                          setState(() {
                                            _selectedSection =
                                                _BarAdminSection.products;
                                          });
                                        },
                                      ),
                                      _BarAdminSectionChip(
                                        label: 'Incoming',
                                        selected:
                                            _selectedSection ==
                                            _BarAdminSection.incoming,
                                        onTap: () {
                                          setState(() {
                                            _selectedSection =
                                                _BarAdminSection.incoming;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: switch (_selectedSection) {
                              _BarAdminSection.categories => _BarAdminCategoriesTab(
                                controller: _newCategoryController,
                                isBusy: _isCategoryBusy,
                                categories: categories,
                                onCreate: _createCategory,
                                onEdit: _editCategory,
                                onDelete: _deleteCategory,
                              ),
                              _BarAdminSection.products => _BarAdminProductsTab(
                                categories: categories,
                                selectedCategoryId: _selectedProductCategoryId,
                                onSelectCategory: (categoryId) {
                                  setState(() {
                                    _selectedProductCategoryId = categoryId;
                                  });
                                },
                                products: filteredProducts,
                                isBusy: _isProductBusy,
                                onCreate: () => _createProduct(categories),
                                onEdit: (product) =>
                                    _editProduct(product, categories),
                                onDelete: _deleteProduct,
                              ),
                              _BarAdminSection.incoming => _BarAdminIncomingTab(
                                categories: categories,
                                selectedCategoryId:
                                    _selectedIncomingCategoryId,
                                onSelectCategory: (categoryId) {
                                  setState(() {
                                    _selectedIncomingCategoryId = categoryId;
                                  });
                                },
                                products: filteredIncomingProducts,
                                invoiceItems: _incomingDraft.values.toList(
                                  growable: false,
                                ),
                                history: incoming,
                                isBusy: _isIncomingBusy,
                                onAddProduct: _addIncomingProduct,
                                onIncreaseQty: (item) =>
                                    _changeIncomingQuantity(item, 1),
                                onDecreaseQty: (item) =>
                                    _changeIncomingQuantity(item, -1),
                                onEditPrice: _editIncomingPrice,
                                onSave: _saveIncoming,
                                onDeleteInvoice: _deleteIncoming,
                              ),
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

enum _BarAdminSection { categories, products, incoming }

class _BarAdminSectionChip extends StatelessWidget {
  const _BarAdminSectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _IncomingDraftItem {
  const _IncomingDraftItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.purchasePrice,
  });

  final String productId;
  final String name;
  final int quantity;
  final num purchasePrice;

  _IncomingDraftItem copyWith({
    String? productId,
    String? name,
    int? quantity,
    num? purchasePrice,
  }) {
    return _IncomingDraftItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}

class _BarProductDraft {
  const _BarProductDraft({
    required this.categoryId,
    required this.name,
    required this.price,
    this.existingImageUrl,
    this.imageBytes,
    this.imageFileName,
  });

  final String categoryId;
  final String name;
  final num price;
  final String? existingImageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
}

class _BarAdminBlockedCard extends StatelessWidget {
  const _BarAdminBlockedCard();

  @override
  Widget build(BuildContext context) {
    return const _BarAdminStatusCard(
      title: 'Bar admin unavailable',
      message:
          'This route requires an owner account with a resolved gym context.',
      isError: true,
    );
  }
}

class _BarAdminLoadingCard extends StatelessWidget {
  const _BarAdminLoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bar admin', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _BarAdminStatusCard extends StatelessWidget {
  const _BarAdminStatusCard({
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
              message,
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

class _BarAdminCategoriesTab extends StatelessWidget {
  const _BarAdminCategoriesTab({
    required this.controller,
    required this.isBusy,
    required this.categories,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final TextEditingController controller;
  final bool isBusy;
  final List<BarCategorySummary> categories;
  final VoidCallback onCreate;
  final ValueChanged<BarCategorySummary> onEdit;
  final ValueChanged<BarCategorySummary> onDelete;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom + 24;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: isBusy ? null : onCreate,
                    child: Text(isBusy ? 'Saving...' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...categories.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('ID ${category.id}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: isBusy ? null : () => onEdit(category),
                          child: const Text('Edit'),
                        ),
                        FilledButton.tonal(
                          onPressed: isBusy ? null : () => onDelete(category),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAdminProductsTab extends StatelessWidget {
  const _BarAdminProductsTab({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.products,
    required this.isBusy,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BarCategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelectCategory;
  final List<BarProductSummary> products;
  final bool isBusy;
  final VoidCallback onCreate;
  final ValueChanged<BarProductSummary> onEdit;
  final ValueChanged<BarProductSummary> onDelete;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom + 24;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: isBusy ? null : onCreate,
                    child: const Text('New product'),
                  ),
                ),
                if (categories.isEmpty)
                  const Text('Create a category first.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category.name),
                            selected: category.id == selectedCategoryId,
                            onSelected: (_) => onSelectCategory(category.id),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No active products matched the selected category.'),
            ),
          )
        else
          ...products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          product.image?.isNotEmpty == true
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    product.image!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                            ),
                                  ),
                                )
                              : const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.local_bar_outlined),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatMoney(product.price ?? 0)} so\'m • Stock ${product.availableStock}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: isBusy ? null : () => onEdit(product),
                            child: const Text('Edit'),
                          ),
                          FilledButton.tonal(
                            onPressed: isBusy ? null : () => onDelete(product),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAdminIncomingTab extends StatelessWidget {
  const _BarAdminIncomingTab({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.products,
    required this.invoiceItems,
    required this.history,
    required this.isBusy,
    required this.onAddProduct,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onEditPrice,
    required this.onSave,
    required this.onDeleteInvoice,
  });

  final List<BarCategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelectCategory;
  final List<BarProductSummary> products;
  final List<_IncomingDraftItem> invoiceItems;
  final List<BarIncomingInvoiceSummary> history;
  final bool isBusy;
  final ValueChanged<BarProductSummary> onAddProduct;
  final ValueChanged<_IncomingDraftItem> onIncreaseQty;
  final ValueChanged<_IncomingDraftItem> onDecreaseQty;
  final ValueChanged<_IncomingDraftItem> onEditPrice;
  final VoidCallback onSave;
  final ValueChanged<BarIncomingInvoiceSummary> onDeleteInvoice;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom + 24;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create incoming invoice',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const Text('Create a category first.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category.name),
                            selected: category.id == selectedCategoryId,
                            onSelected: (_) => onSelectCategory(category.id),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 12),
                ...products.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatMoney(product.price ?? 0)} so\'m • Stock ${product.availableStock}',
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: isBusy ? null : () => onAddProduct(product),
                              child: const Text('Add'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Draft invoice',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: isBusy ? null : onSave,
                    child: Text(isBusy ? 'Saving...' : 'Save incoming'),
                  ),
                ),
                if (invoiceItems.isEmpty)
                  const Text('No products added yet.')
                else
                  ...invoiceItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty ${item.quantity} • ${_formatMoney(item.purchasePrice)} so\'m',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onDecreaseQty(item),
                                  child: const Text('−'),
                                ),
                                FilledButton.tonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onIncreaseQty(item),
                                  child: const Text('+'),
                                ),
                                FilledButton.tonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onEditPrice(item),
                                  child: const Text('Price'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Text('No incoming invoices were returned for this gym.')
                else
                  ...history.map(
                    (invoice) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber ?? invoice.id,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${invoice.items.length} items • Qty ${invoice.totalQuantity} • ${_formatTime(invoice.createdAt)}',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('${_formatMoney(invoice.total ?? 0)} so\'m'),
                                FilledButton.tonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onDeleteInvoice(invoice),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarProductEditorDialog extends StatefulWidget {
  const _BarProductEditorDialog({
    required this.categories,
    this.initialCategoryId,
    this.initialName,
    this.initialPrice,
    this.initialImageUrl,
    this.isEditing = false,
  });

  final List<BarCategorySummary> categories;
  final String? initialCategoryId;
  final String? initialName;
  final num? initialPrice;
  final String? initialImageUrl;
  final bool isEditing;

  @override
  State<_BarProductEditorDialog> createState() =>
      _BarProductEditorDialogState();
}

class _BarProductEditorDialogState extends State<_BarProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _categoryId;
  Uint8List? _imageBytes;
  String? _imageFileName;

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.initialCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _nameController.text = widget.initialName ?? '';
    _priceController.text = widget.initialPrice == null
        ? ''
        : _formatMoney(widget.initialPrice!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _imageBytes = bytes;
      _imageFileName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit product' : 'Create product'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.isEditing
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (value) => num.tryParse(value?.trim() ?? '') == null
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _pickImage,
                child: Text(
                  _imageBytes != null || widget.initialImageUrl != null
                      ? 'Replace image'
                      : 'Upload image',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                height: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : widget.initialImageUrl?.isNotEmpty == true
                      ? Image.network(
                          widget.initialImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                ),
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        )
                      : const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black26),
                          child: Icon(Icons.local_bar_outlined),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            final categoryId = _categoryId?.trim();
            final price = num.tryParse(_priceController.text.trim());
            if (categoryId == null || categoryId.isEmpty || price == null) {
              return;
            }

            Navigator.of(context).pop(
              _BarProductDraft(
                categoryId: categoryId,
                name: _nameController.text.trim(),
                price: price,
                existingImageUrl: _imageBytes == null
                    ? widget.initialImageUrl
                    : null,
                imageBytes: _imageBytes,
                imageFileName: _imageFileName,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

bool _canManageBar(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null && gymId.isNotEmpty && role == AllClubsRole.owner;
}

String _formatMoney(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
