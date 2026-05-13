import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../application/gym_profile_service.dart';

class GymEditorDialog extends ConsumerStatefulWidget {
  const GymEditorDialog({super.key, required this.session});

  final ResolvedAuthSession session;

  @override
  ConsumerState<GymEditorDialog> createState() => _GymEditorDialogState();
}

class _GymEditorDialogState extends ConsumerState<GymEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;

  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _removeLogo = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.session.gym?.name ?? '',
    );
    _cityController = TextEditingController(
      text: widget.session.gym?.city ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.session.gym?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (_isSaving) {
      return;
    }

    final strings = AppStrings.of(ref);

    try {
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
        _logoBytes = bytes;
        _logoFileName = file.name;
        _removeLogo = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            '${strings.logoSelectionFailedPrefix}: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _removeLogoAction() {
    if (_isSaving) {
      return;
    }

    setState(() {
      _logoBytes = null;
      _logoFileName = null;
      _removeLogo = true;
    });
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    final strings = AppStrings.of(ref);

    if (_isSaving || formState == null || !formState.validate()) {
      return;
    }

    final gymId = widget.session.gymId?.trim();
    if (gymId == null || gymId.isEmpty) {
      setState(() => _errorMessage = strings.noGymContext);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(gymProfileServiceProvider);
      String? logoUrl;

      if (_logoBytes != null) {
        logoUrl = await service.uploadGymLogo(
          gymId: gymId,
          bytes: _logoBytes!,
          fileName: _logoFileName ?? 'gym-logo.jpg',
        );
      } else if (!_removeLogo) {
        logoUrl = widget.session.gym?.logoUrl;
      }

      await service.updateGymProfile(
        request: UpdateGymProfileRequest(
          gymId: gymId,
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
          phone: _phoneController.text.trim(),
          logoUrl: logoUrl,
          removeLogo: _removeLogo,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            '${strings.gymUpdateFailedPrefix}: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(ref);
    final theme = Theme.of(context);
    final existingLogoUrl = widget.session.gym?.logoUrl;
    final showExistingLogo =
        !_removeLogo &&
        existingLogoUrl != null &&
        existingLogoUrl.trim().isNotEmpty &&
        _logoBytes == null;
    final canRemoveLogo = _logoBytes != null || showExistingLogo;

    return AlertDialog(
      title: Text(strings.editGym),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: strings.gymName),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? strings.gymNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: strings.city),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: strings.phone),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null;
                    }

                    if (!isValidPhoneNumber(trimmed)) {
                      return strings.invalidPhone;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: _logoBytes != null
                            ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                            : showExistingLogo
                            ? Image.network(
                                existingLogoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _LogoFallback(name: _nameController.text),
                              )
                            : _LogoFallback(name: _nameController.text),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.tonal(
                            onPressed: _isSaving ? null : _pickLogo,
                            child: Text(
                              canRemoveLogo
                                  ? strings.replaceLogo
                                  : strings.addLogo,
                            ),
                          ),
                          if (canRemoveLogo) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _isSaving ? null : _removeLogoAction,
                              child: Text(strings.removeLogo),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? strings.save : strings.saveChanges),
        ),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'G';
  }

  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
