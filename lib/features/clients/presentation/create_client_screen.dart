import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_route_back_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/client_actions_service.dart';

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);

class CreateClientScreen extends ConsumerStatefulWidget {
  const CreateClientScreen({super.key, this.onSubmit});

  final Future<CreateClientResult> Function({
    required CreateClientRequest request,
  })?
  onSubmit;

  @override
  ConsumerState<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends ConsumerState<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _noteController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _selectedBirthDate;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _gender;
  bool _isSubmitting = false;
  String _loadingLabel = 'Creating client...';
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String label, {
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? hintText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: AppColors.panel,
      alignLabelWithHint: alignLabelWithHint,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: alignLabelWithHint ? 16 : 14,
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    if (_isSubmitting) {
      return;
    }

    final initialDate = _selectedBirthDate ?? DateTime(2000, 1, 1);
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BirthDatePickerSheet(
        initialDate: initialDate,
        firstDate: DateTime(1950, 1, 1),
        lastDate: now,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedBirthDate = picked;
      _birthDateController.text = _formatBirthDateLabel(picked);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Photo selection failed: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _clearImage() {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (_isSubmitting || formState == null || !formState.validate()) {
      return;
    }

    final session = ref.read(bootstrapControllerProvider).session;
    final gymId = session?.gymId?.trim();
    if (gymId == null || gymId.isEmpty) {
      setState(() {
        _errorMessage = 'Missing gym context for createClient.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _loadingLabel = 'Creating client...';
      _errorMessage = null;
    });

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        setState(() => _loadingLabel = 'Uploading photo...');
        imageUrl = await ref
            .read(clientActionsServiceProvider)
            .uploadClientPhoto(
              gymId: gymId,
              bytes: _selectedImageBytes!,
              fileName: _selectedImageName ?? 'client.jpg',
            );
      }

      setState(() => _loadingLabel = 'Creating client...');

      final request = CreateClientRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _gender,
        birthDate: _selectedBirthDate == null
            ? null
            : _formatBirthDateValue(_selectedBirthDate!),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        imageUrl: imageUrl,
      );

      final submitClient =
          widget.onSubmit ??
          ({required CreateClientRequest request}) => ref
              .read(clientActionsServiceProvider)
              .createClient(request: request);

      final result = await submitClient(request: request);
      if (!mounted) {
        return;
      }

      context.go(AppRoutes.clientsWithHighlight(result.clientId));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(
        () => _errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final theme = Theme.of(context);
    final gymName = session?.gym?.name?.trim();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => handleAppRouteBack(
            context,
            fallbackLocation: AppRoutes.clients,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Add client'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 720
                  ? 48.0
                  : 20.0;
              final isWide = constraints.maxWidth >= 360;
              final fieldSpacing = 12.0;
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Stack(
                    children: [
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          20 + keyboardInset,
                        ),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: !_canCreateClient(session)
                              ? _CreateClientUnavailableState(
                                  onBack: () => handleAppRouteBack(
                                    context,
                                    fallbackLocation: AppRoutes.clients,
                                  ),
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'All Clubs',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Add client',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(fontSize: 28),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        gymName == null || gymName.isEmpty
                                            ? 'Create a clean client profile for your club.'
                                            : 'Add a new member to $gymName.',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: _CreateClientPhotoPicker(
                                          imageBytes: _selectedImageBytes,
                                          avatarSize: 84,
                                          onGalleryTap: () => _pickImage(
                                            ImageSource.gallery,
                                          ),
                                          onCameraTap: () => _pickImage(
                                            ImageSource.camera,
                                          ),
                                          onDeleteTap: _clearImage,
                                          enabled: !_isSubmitting,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      if (isWide)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _firstNameController,
                                                enabled: !_isSubmitting,
                                                textCapitalization:
                                                    TextCapitalization.words,
                                                textInputAction:
                                                    TextInputAction.next,
                                                decoration: _fieldDecoration(
                                                  'First name *',
                                                  hintText: 'Alex',
                                                  prefixIcon: const Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 20,
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if ((value ?? '')
                                                      .trim()
                                                      .isEmpty) {
                                                    return 'Required';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            SizedBox(width: fieldSpacing),
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _lastNameController,
                                                enabled: !_isSubmitting,
                                                textCapitalization:
                                                    TextCapitalization.words,
                                                textInputAction:
                                                    TextInputAction.next,
                                                decoration: _fieldDecoration(
                                                  'Last name',
                                                  hintText: 'Johnson',
                                                  prefixIcon: const Icon(
                                                    Icons.badge_outlined,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        TextFormField(
                                          controller: _firstNameController,
                                          enabled: !_isSubmitting,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          textInputAction:
                                              TextInputAction.next,
                                          decoration: _fieldDecoration(
                                            'First name *',
                                            hintText: 'Alex',
                                            prefixIcon: const Icon(
                                              Icons.person_outline_rounded,
                                              size: 20,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').trim().isEmpty) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: fieldSpacing),
                                        TextFormField(
                                          controller: _lastNameController,
                                          enabled: !_isSubmitting,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          textInputAction:
                                              TextInputAction.next,
                                          decoration: _fieldDecoration(
                                            'Last name',
                                            hintText: 'Johnson',
                                            prefixIcon: const Icon(
                                              Icons.badge_outlined,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: fieldSpacing),
                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _phoneController,
                                                enabled: !_isSubmitting,
                                                keyboardType:
                                                    TextInputType.phone,
                                                textInputAction:
                                                    TextInputAction.next,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    9,
                                                  ),
                                                  _PhoneNumberFormatter(),
                                                ],
                                                decoration: _fieldDecoration(
                                                  'Phone number *',
                                                  hintText: '90 123 45 67',
                                                  prefixIcon: const Icon(
                                                    Icons.call_outlined,
                                                    size: 20,
                                                  ),
                                                ),
                                                validator: (value) {
                                                  final digits = (value ?? '')
                                                      .replaceAll(
                                                        RegExp(r'\D'),
                                                        '',
                                                      );
                                                  if (digits.isEmpty) {
                                                    return 'Required';
                                                  }
                                                  if (digits.length < 9) {
                                                    return 'Incomplete';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            SizedBox(width: fieldSpacing),
                                            Expanded(
                                              child: _DatePickerField(
                                                label: 'Birth date',
                                                value:
                                                    _birthDateController.text,
                                                decoration: _fieldDecoration(
                                                  'Birth date',
                                                  prefixIcon: const Icon(
                                                    Icons
                                                        .calendar_month_outlined,
                                                    size: 20,
                                                  ),
                                                ),
                                                enabled: !_isSubmitting,
                                                onTap: _pickBirthDate,
                                                onClear:
                                                    _birthDateController
                                                        .text
                                                        .isEmpty
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _selectedBirthDate =
                                                              null;
                                                          _birthDateController
                                                              .clear();
                                                        });
                                                      },
                                              ),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        TextFormField(
                                          controller: _phoneController,
                                          enabled: !_isSubmitting,
                                          keyboardType: TextInputType.phone,
                                          textInputAction:
                                              TextInputAction.next,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                              9,
                                            ),
                                            _PhoneNumberFormatter(),
                                          ],
                                          decoration: _fieldDecoration(
                                            'Phone number *',
                                            hintText: '90 123 45 67',
                                            prefixIcon: const Icon(
                                              Icons.call_outlined,
                                              size: 20,
                                            ),
                                          ),
                                          validator: (value) {
                                            final digits = (value ?? '')
                                                .replaceAll(
                                                  RegExp(r'\D'),
                                                  '',
                                                );
                                            if (digits.isEmpty) {
                                              return 'Required';
                                            }
                                            if (digits.length < 9) {
                                              return 'Incomplete';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: fieldSpacing),
                                        _DatePickerField(
                                          label: 'Birth date',
                                          value: _birthDateController.text,
                                          decoration: _fieldDecoration(
                                            'Birth date',
                                            prefixIcon: const Icon(
                                              Icons.calendar_month_outlined,
                                              size: 20,
                                            ),
                                          ),
                                          enabled: !_isSubmitting,
                                          onTap: _pickBirthDate,
                                          onClear: _birthDateController
                                                  .text
                                                  .isEmpty
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _selectedBirthDate = null;
                                                    _birthDateController
                                                        .clear();
                                                  });
                                                },
                                        ),
                                      ],
                                      SizedBox(height: fieldSpacing),
                                      Text(
                                        'Gender',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: AppColors.mutedInk,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      _GenderSelector(
                                        value: _gender,
                                        enabled: !_isSubmitting,
                                        onChanged: (value) {
                                          setState(() => _gender = value);
                                        },
                                      ),
                                      SizedBox(height: fieldSpacing),
                                      TextFormField(
                                        controller: _noteController,
                                        enabled: !_isSubmitting,
                                        minLines: 4,
                                        maxLines: 5,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        decoration: _fieldDecoration(
                                          'Note',
                                          hintText:
                                              'Goal, injury notes, membership details...',
                                          alignLabelWithHint: true,
                                        ),
                                      ),
                                      if (_errorMessage != null)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: fieldSpacing,
                                          ),
                                          child: Text(
                                            _errorMessage!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .error,
                                                ),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed:
                                              _isSubmitting ? null : _submit,
                                          icon: const Icon(
                                            Icons.person_add_alt_1_rounded,
                                          ),
                                          label: const Text('Create client'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      if (_isSubmitting)
                        Positioned.fill(
                          child: _CreateClientLoadingOverlay(
                            label: _loadingLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreateClientUnavailableState extends StatelessWidget {
  const _CreateClientUnavailableState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create client unavailable',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'This route is available only for owner or staff accounts with a resolved gym context.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to clients'),
          ),
        ],
      ),
    );
  }
}

class _CreateClientPhotoPicker extends StatelessWidget {
  const _CreateClientPhotoPicker({
    required this.imageBytes,
    required this.avatarSize,
    required this.onGalleryTap,
    required this.onCameraTap,
    required this.onDeleteTap,
    required this.enabled,
  });

  final Uint8List? imageBytes;
  final double avatarSize;
  final VoidCallback onGalleryTap;
  final VoidCallback onCameraTap;
  final VoidCallback onDeleteTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.panel,
                  border: Border.all(color: _alpha(AppColors.border, 0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: AppColors.panelRaised,
                  backgroundImage: imageBytes == null
                      ? null
                      : MemoryImage(imageBytes!),
                  child: imageBytes == null
                      ? Icon(
                          Icons.person_rounded,
                          size: avatarSize * 0.38,
                          color: AppColors.mutedInk,
                        )
                      : null,
                ),
              ),
              if (imageBytes != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _ImageIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: enabled ? onDeleteTap : null,
                    tint: AppColors.danger,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Profile photo',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Optional',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _ImageActionButton(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: enabled ? onGalleryTap : null,
            ),
            _ImageActionButton(
              icon: Icons.photo_camera_outlined,
              label: 'Camera',
              onTap: enabled ? onCameraTap : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageIconButton extends StatelessWidget {
  const _ImageIconButton({
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.ink;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.panel,
        shape: BoxShape.circle,
        border: Border.all(color: _alpha(AppColors.border, 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.canvasStrong.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: AppColors.panel,
      ),
      icon: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderOption(
            label: 'Male',
            icon: Icons.male_rounded,
            selected: value == 'male',
            enabled: enabled,
            onTap: () => onChanged(value == 'male' ? null : 'male'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GenderOption(
            label: 'Female',
            icon: Icons.female_rounded,
            selected: value == 'female',
            enabled: enabled,
            onTap: () => onChanged(value == 'female' ? null : 'female'),
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.decoration,
    required this.enabled,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final InputDecoration decoration;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = value.trim().isEmpty;

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: IgnorePointer(
            child: InputDecorator(
              isEmpty: isEmpty,
              decoration: decoration.copyWith(
                enabled: enabled,
                suffixIcon: isEmpty
                    ? const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                      )
                    : IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
              child: Text(
                isEmpty ? ' ' : value,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? _alpha(AppColors.primary, 0.12)
                : AppColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _alpha(AppColors.primary, 0.34)
                  : _alpha(AppColors.border, 0.9),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.mutedInk,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthDatePickerSheet extends StatefulWidget {
  const _BirthDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  late DateTime _selectedDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _alpha(AppColors.border, 0.86)),
          boxShadow: [
            BoxShadow(
              color: AppColors.canvasStrong.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Birth date', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: 190,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.light),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate,
                    minimumDate: widget.firstDate,
                    maximumDate: widget.lastDate,
                    onDateTimeChanged: (value) {
                      setState(() => _selectedDate = value);
                    },
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

class _CreateClientLoadingOverlay extends StatelessWidget {
  const _CreateClientLoadingOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.canvasStrong.withValues(alpha: 0.08),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _alpha(AppColors.border, 0.9)),
            boxShadow: [
              BoxShadow(
                color: AppColors.canvasStrong.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 12),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

bool _canCreateClient(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;
  return gymId != null &&
      gymId.isNotEmpty &&
      (session.role == AllClubsRole.owner ||
          session.role == AllClubsRole.staff);
}

String _formatBirthDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year.toString().padLeft(4, '0')}';
}

String _formatBirthDateValue(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _PhoneNumberFormatter extends TextInputFormatter {
  const _PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index == 2 || index == 5 || index == 7) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
