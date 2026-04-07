import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/package_actions_service.dart';
import '../domain/gym_package_summary.dart';

const packageGradientOptions = <String>[
  'from-indigo-500 to-indigo-700',
  'from-emerald-500 to-emerald-700',
  'from-rose-500 to-rose-700',
  'from-sky-500 to-sky-700',
  'from-purple-500 to-purple-700',
  'from-amber-500 to-amber-700',
];

const packageGenderOptions = <String>['all', 'male', 'female'];

class CreatePackageScreen extends ConsumerStatefulWidget {
  const CreatePackageScreen({super.key, this.initialPackage});

  final GymPackageSummary? initialPackage;

  @override
  ConsumerState<CreatePackageScreen> createState() =>
      _CreatePackageScreenState();
}

class _CreatePackageScreenState extends ConsumerState<CreatePackageScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late final TextEditingController _bonusDaysController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _maxFreezeDaysController;
  late final TextEditingController _descriptionController;

  late bool _freezeEnabled;
  late String _gender;
  late String _gradient;
  var _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isEditMode => widget.initialPackage != null;

  @override
  void initState() {
    super.initState();
    final package = widget.initialPackage;
    _nameController = TextEditingController(text: package?.name ?? '');
    _priceController = TextEditingController(
      text: package?.price != null ? _formatPackageAmount(package!.price!) : '',
    );
    _durationController = TextEditingController(
      text: (package?.duration ?? 30).toString(),
    );
    _bonusDaysController = TextEditingController(
      text: (package?.bonusDays ?? 0).toString(),
    );
    _startTimeController = TextEditingController(
      text: package?.startTime ?? '00:00',
    );
    _endTimeController = TextEditingController(
      text: package?.endTime ?? '23:59',
    );
    _maxFreezeDaysController = TextEditingController(
      text: (package?.maxFreezeDays ?? 0).toString(),
    );
    _descriptionController = TextEditingController(
      text: package?.description ?? '',
    );
    _freezeEnabled = package?.freezeEnabled ?? false;
    final packageGender = package?.gender;
    _gender = packageGenderOptions.contains(packageGender)
        ? packageGender!
        : packageGenderOptions.first;
    final packageGradient = package?.gradient;
    _gradient = packageGradientOptions.contains(packageGradient)
        ? packageGradient!
        : packageGradientOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _bonusDaysController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _maxFreezeDaysController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int _readInt(TextEditingController controller, {int fallback = 0}) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  num _readNum(TextEditingController controller) {
    return num.tryParse(controller.text.trim()) ?? 0;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    final request = PackageUpsertRequest(
      name: _nameController.text,
      price: _readNum(_priceController),
      duration: _readInt(_durationController, fallback: 0),
      bonusDays: _readInt(_bonusDaysController),
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      freezeEnabled: _freezeEnabled,
      maxFreezeDays: _readInt(_maxFreezeDaysController),
      gender: _gender,
      gradient: _gradient,
      description: _descriptionController.text,
    );

    try {
      if (_isEditMode) {
        await ref.read(packageActionsServiceProvider).updatePackage(
          packageId: widget.initialPackage!.id,
          request: request,
        );
      } else {
        await ref
            .read(packageActionsServiceProvider)
            .createPackage(request: request);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            _isEditMode
            ? 'Package updated successfully. Returning to packages...'
            : 'Package created successfully. Returning to packages...';
        _statusIsError = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        context.go(AppRoutes.packages);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.toString().replaceFirst('Exception: ', '');
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final canCreate = _canCreatePackage(session);
    final theme = Theme.of(context);
    final totalDays =
        _readInt(_durationController, fallback: 0) +
        _readInt(_bonusDaysController);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.packages),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: Text(_isEditMode ? 'Edit package' : 'Create package'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: !canCreate
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create package unavailable',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This route is available only for owner accounts with a resolved gym context.',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => context.go(AppRoutes.packages),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to packages'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.gym?.name ?? 'Current gym',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isEditMode
                                        ? 'Update this package template using the exact working web updatePackage contract.'
                                        : 'Create a package template using the exact working web createPackage contract.',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Package name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Package name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                    ),
                                    validator: (value) {
                                      final parsed = num.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (parsed == null || parsed <= 0) {
                                        return 'Price must be greater than 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _durationController,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'Duration (days)',
                                          ),
                                          onChanged: (_) => setState(() {}),
                                          validator: (value) {
                                            final parsed = int.tryParse(
                                              (value ?? '').trim(),
                                            );
                                            if (parsed == null || parsed <= 0) {
                                              return 'Duration > 0';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _bonusDaysController,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'Bonus days',
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Visit limit is locked to total days: $totalDays',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _startTimeController,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'Start time',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _endTimeController,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'End time',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _freezeEnabled,
                                    onChanged: (value) {
                                      setState(() => _freezeEnabled = value);
                                    },
                                    title: const Text('Freeze enabled'),
                                  ),
                                  if (_freezeEnabled) ...[
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _maxFreezeDaysController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Max freeze days',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    decoration: const InputDecoration(
                                      labelText: 'Gender',
                                    ),
                                    items: packageGenderOptions
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _gender = value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gradient,
                                    decoration: const InputDecoration(
                                      labelText: 'Gradient',
                                    ),
                                    items: packageGradientOptions
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _gradient = value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _descriptionController,
                                    minLines: 2,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Description',
                                    ),
                                  ),
                                  if (_statusMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _statusMessage!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: _statusIsError
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: _isSubmitting ? null : _submit,
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.add_box_rounded),
                                    label: Text(
                                      _isSubmitting
                                          ? (_isEditMode
                                                ? 'Saving package...'
                                                : 'Creating package...')
                                          : (_isEditMode
                                                ? 'Save changes'
                                                : 'Create package'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _canCreatePackage(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  return gymId != null &&
      gymId.isNotEmpty &&
      session?.role == AllClubsRole.owner;
}

String _formatPackageAmount(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}
