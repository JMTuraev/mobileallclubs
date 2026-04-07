import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/client_actions_service.dart';

class CreateClientScreen extends ConsumerStatefulWidget {
  const CreateClientScreen({super.key, this.onSubmit});

  final Future<CreateClientResult> Function(CreateClientRequest request)?
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

  String _gender = 'male';
  DateTime? _selectedBirthDate;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final initialDate = _selectedBirthDate ?? DateTime(2000, 1, 1);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedBirthDate = picked;
      _birthDateController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickImage() async {
    if (_isSubmitting) {
      return;
    }

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
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
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

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
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
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        setState(() {
          _statusMessage = 'Uploading client photo...';
        });

        imageUrl = await ref
            .read(clientActionsServiceProvider)
            .uploadClientPhoto(
              gymId: gymId,
              bytes: _selectedImageBytes!,
              fileName: _selectedImageName ?? 'client.jpg',
            );
      }

      final request = CreateClientRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _gender,
        birthDate: _birthDateController.text.trim().isEmpty
            ? null
            : _birthDateController.text.trim(),
        note: _noteController.text.trim(),
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

      setState(() {
        _statusMessage = 'Client created successfully. Opening profile...';
      });

      // Let focus and inherited dependencies settle before replacing the route.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        context.go(AppRoutes.clientDetail(result.clientId));
      }
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.clients),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Create client'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: !_canCreateClient(session)
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => context.go(AppRoutes.clients),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to clients'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create client',
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Create a new client for ${session?.gym?.name ?? session?.gymId ?? 'the current gym'} using the exact working web createClient contract.',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        backgroundImage:
                                            _selectedImageBytes == null
                                            ? null
                                            : MemoryImage(_selectedImageBytes!),
                                        child: _selectedImageBytes == null
                                            ? const Icon(
                                                Icons.photo_camera_outlined,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedImageName ??
                                                  'No photo selected',
                                              style: theme.textTheme.bodyLarge,
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                FilledButton.tonalIcon(
                                                  onPressed: _isSubmitting
                                                      ? null
                                                      : _pickImage,
                                                  icon: const Icon(
                                                    Icons.photo_library_rounded,
                                                  ),
                                                  label: Text(
                                                    _selectedImageBytes == null
                                                        ? 'Upload photo'
                                                        : 'Replace photo',
                                                  ),
                                                ),
                                                if (_selectedImageBytes != null)
                                                  TextButton(
                                                    onPressed: _isSubmitting
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              _selectedImageBytes =
                                                                  null;
                                                              _selectedImageName =
                                                                  null;
                                                            });
                                                          },
                                                    child: const Text(
                                                      'Remove photo',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _firstNameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'First name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'First name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _lastNameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Last name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Last name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Phone is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    decoration: const InputDecoration(
                                      labelText: 'Gender',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'male',
                                        child: Text('Male'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'female',
                                        child: Text('Female'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }

                                      setState(() => _gender = value);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _birthDateController,
                                    readOnly: true,
                                    onTap: _pickBirthDate,
                                    decoration: InputDecoration(
                                      labelText: 'Birth date',
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedBirthDate = null;
                                            _birthDateController.clear();
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.calendar_month_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _noteController,
                                    minLines: 3,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                      labelText: 'Note',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                    ),
                                  ],
                                  if (_statusMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _statusMessage!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
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
                                        : const Icon(Icons.person_add_alt_1),
                                    label: Text(
                                      _isSubmitting
                                          ? 'Creating client...'
                                          : 'Create client',
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
