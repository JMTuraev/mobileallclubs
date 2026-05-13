import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/theme/app_theme.dart';
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

const packageGradientLabels = <String, String>{
  'from-indigo-500 to-indigo-700': 'Indigo',
  'from-emerald-500 to-emerald-700': 'Emerald',
  'from-rose-500 to-rose-700': 'Rose',
  'from-sky-500 to-sky-700': 'Sky',
  'from-purple-500 to-purple-700': 'Purple',
  'from-amber-500 to-amber-700': 'Amber',
};

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
        await ref
            .read(packageActionsServiceProvider)
            .updatePackage(
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
        _statusMessage = _isEditMode ? 'Package updated.' : 'Package created.';
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
    final previewColors = _gradientPreviewColors(_gradient);
    final previewName = _nameController.text.trim().isEmpty
        ? 'New package'
        : _nameController.text.trim();
    final previewPrice = _priceController.text.trim().isEmpty
        ? '0'
        : _priceController.text.trim();
    final previewSchedule =
        '${_startTimeController.text.trim().isEmpty ? '00:00' : _startTimeController.text.trim()} - ${_endTimeController.text.trim().isEmpty ? '23:59' : _endTimeController.text.trim()}';

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
                                'Only the owner account can create packages.',
                                style: theme.textTheme.bodyMedium,
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
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          previewColors.first.withValues(
                                            alpha: 0.24,
                                          ),
                                          previewColors.last.withValues(
                                            alpha: 0.12,
                                          ),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: previewColors.last.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 74,
                                          height: 74,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: previewColors,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            totalDays > 0 ? '$totalDays' : '-',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                previewName,
                                                style:
                                                    theme.textTheme.titleLarge,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$previewPrice sum',
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                session?.gym?.name ??
                                                    'Current gym',
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _PreviewChip(
                                                    icon: Icons.repeat_rounded,
                                                    label: '$totalDays visits',
                                                  ),
                                                  _PreviewChip(
                                                    icon: Icons.wc_rounded,
                                                    label: _gender,
                                                  ),
                                                  _PreviewChip(
                                                    icon:
                                                        Icons.schedule_rounded,
                                                    label: previewSchedule,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Main info',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => setState(() {}),
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
                                    onChanged: (_) => setState(() {}),
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
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Visits automatically: $totalDays',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Rules',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _startTimeController,
                                          textInputAction: TextInputAction.next,
                                          onChanged: (_) => setState(() {}),
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
                                          onChanged: (_) => setState(() {}),
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
                                  Text(
                                    'Extra',
                                    style: theme.textTheme.titleMedium,
                                  ),
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
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Gradient',
                                    ),
                                    items: packageGradientOptions
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors:
                                                          _gradientPreviewColors(
                                                            value,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  packageGradientLabels[value] ??
                                                      value,
                                                ),
                                              ],
                                            ),
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
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            (_statusIsError
                                                    ? AppColors.danger
                                                    : AppColors.success)
                                                .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        _statusMessage!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: _statusIsError
                                                  ? AppColors.danger
                                                  : AppColors.success,
                                            ),
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
                                                ? 'Saving...'
                                                : 'Creating...')
                                          : (_isEditMode
                                                ? 'Save'
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

List<Color> _gradientPreviewColors(String? gradient) {
  return switch (gradient) {
    'from-emerald-500 to-emerald-700' => const [
      Color(0xFF58D49D),
      Color(0xFF25895B),
    ],
    'from-rose-500 to-rose-700' => const [Color(0xFFFF637F), Color(0xFFC21F4F)],
    'from-sky-500 to-sky-700' => const [Color(0xFF60C8FF), Color(0xFF2B7BCA)],
    'from-purple-500 to-purple-700' => const [
      Color(0xFFC571FF),
      Color(0xFF7C36E1),
    ],
    'from-amber-500 to-amber-700' => const [
      Color(0xFFFFC451),
      Color(0xFFC27E00),
    ],
    _ => const [Color(0xFF7D74FF), Color(0xFF5149E8)],
  };
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
