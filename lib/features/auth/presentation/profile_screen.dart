import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_billing_config.dart';
import '../../../core/localization/app_currency.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/auth_bootstrap_resolver.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/backend_action_error.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../application/google_play_billing_service.dart';
import '../application/google_play_receipt_sync_service.dart';
import '../application/gym_profile_providers.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../staff/application/create_staff_service.dart';
import '../../staff/application/staff_providers.dart';
import '../../staff/domain/gym_staff_summary.dart';
import '../../staff/presentation/staff_member_card.dart';
import 'profile_gym_editor_dialog.dart';

const String _appVersionLabel = 'v1.0.0+1';
const List<AppCurrency> _profileCurrencies = <AppCurrency>[
  AppCurrency.uzs,
  AppCurrency.usd,
  AppCurrency.eur,
  AppCurrency.kzt,
];
final Uri _aboutWebsiteUri = Uri.parse('https://allclubs.app');
final Uri _subscriptionManageUri = Uri.parse(
  'https://myaccount.google.com/subscriptions',
);
final Uri _subscriptionHistoryUri = Uri.parse('https://payments.google.com/');

enum _ProfilePage { home, settings, staff, subscription, about }

_ProfilePage _pageFromSection(String? section) {
  return switch (section) {
    'settings' => _ProfilePage.settings,
    'staff' => _ProfilePage.staff,
    'subscription' => _ProfilePage.subscription,
    'about' => _ProfilePage.about,
    _ => _ProfilePage.home,
  };
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.section});

  final String? section;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;
  _ProfilePage? _localPageOverride;
  final Set<String> _busyStaffIds = <String>{};
  final Set<String> _removedStaffIds = <String>{};
  final Map<String, bool> _activeOverrides = <String, bool>{};
  final Map<String, String> _fullNameOverrides = <String, String>{};
  final Map<String, String> _phoneOverrides = <String, String>{};

  String _profileLocation(_ProfilePage page) {
    return switch (page) {
      _ProfilePage.home => AppRoutes.profile,
      _ProfilePage.settings => AppRoutes.profileWithSection('settings'),
      _ProfilePage.staff => AppRoutes.profileWithSection('staff'),
      _ProfilePage.subscription => AppRoutes.profileWithSection('subscription'),
      _ProfilePage.about => AppRoutes.profileWithSection('about'),
    };
  }

  _ProfilePage get _currentPage =>
      _localPageOverride ?? _pageFromSection(widget.section);

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _localPageOverride = null;
    }
  }

  void _goToPage(_ProfilePage page) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      _localPageOverride = null;
      router.go(_profileLocation(page));
      return;
    }

    setState(() => _localPageOverride = page);
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await ref.read(firebaseAuthProvider).signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final strings = AppStrings.of(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${strings.signOutFailedPrefix}: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _openGymEditor(ResolvedAuthSession session) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => GymEditorDialog(session: session),
    );

    if (!mounted || updated != true) {
      return;
    }

    ref.invalidate(resolvedAuthSessionStreamProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(ref).gymSaved)));
  }

  Future<void> _openExternalProfilePage(
    Uri uri, {
    required String errorMessage,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted || launched) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(errorMessage)));
  }

  void _showStaffNotice(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : const Color(0xFF21362B),
        ),
      );
  }

  Future<bool?> _confirmStaffAction({
    required String title,
    required String message,
  }) {
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

  Future<void> _editStaffMember(GymStaffSummary member) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final fullNameController = TextEditingController(
      text: member.fullName ?? '',
    );
    final phoneController = TextEditingController(text: member.phone ?? '');

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit staff'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.email ?? member.id,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fullNameController,
                    enabled: !isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() {
                          isSaving = true;
                          dialogError = null;
                        });

                        try {
                          await updateStaffMember(
                            functions: ref.read(firebaseFunctionsProvider),
                            request: UpdateStaffRequest(
                              userId: member.id,
                              fullName: fullNameController.text.trim(),
                              phone: phoneController.text.trim(),
                            ),
                          );

                          if (!context.mounted) {
                            return;
                          }

                          Navigator.of(dialogContext).pop(true);
                        } catch (error) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = error.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    final nextFullName = fullNameController.text.trim();
    final nextPhone = phoneController.text.trim();
    fullNameController.dispose();
    phoneController.dispose();

    if (didSave == true && mounted) {
      ref.invalidate(currentGymStaffStreamProvider);
      _showStaffNotice('Staff updated.', isError: false);
      setState(() {
        _fullNameOverrides[member.id] = nextFullName;
        _phoneOverrides[member.id] = nextPhone;
      });
    }
  }

  Future<void> _setStaffActive(
    GymStaffSummary member, {
    required bool isActive,
  }) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final shouldProceed = await _confirmStaffAction(
      title: isActive ? 'Enable staff?' : 'Disable staff?',
      message: isActive
          ? 'Enable this staff member again?'
          : 'Disable this staff member?',
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _busyStaffIds.add(member.id);
    });

    try {
      await setStaffActiveState(
        functions: ref.read(firebaseFunctionsProvider),
        userId: member.id,
        isActive: isActive,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(activeStaffIdsProvider);
      _showStaffNotice(
        isActive ? 'Staff enabled.' : 'Staff disabled.',
        isError: false,
      );
      setState(() {
        _activeOverrides[member.id] = isActive;
      });
    } catch (error) {
      _showStaffNotice(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyStaffIds.remove(member.id);
        });
      }
    }
  }

  Future<void> _removeStaffMember(GymStaffSummary member) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final shouldProceed = await _confirmStaffAction(
      title: 'Remove staff?',
      message: 'Remove this staff member from the gym?',
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _busyStaffIds.add(member.id);
    });

    try {
      await removeStaffMember(
        functions: ref.read(firebaseFunctionsProvider),
        userId: member.id,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(activeStaffIdsProvider);
      ref.invalidate(currentGymStaffStreamProvider);
      _showStaffNotice('Staff removed.', isError: false);
      setState(() {
        _removedStaffIds.add(member.id);
        _activeOverrides.remove(member.id);
        _fullNameOverrides.remove(member.id);
        _phoneOverrides.remove(member.id);
      });
    } catch (error) {
      _showStaffNotice(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyStaffIds.remove(member.id);
        });
      }
    }
  }

  bool _resolveIsActive(
    GymStaffSummary member,
    AsyncValue<Set<String>>? activeStaffIdsAsync,
  ) {
    final localOverride = _activeOverrides[member.id];
    if (localOverride != null) {
      return localOverride;
    }

    return activeStaffIdsAsync?.maybeWhen(
          data: (activeIds) => activeIds.contains(member.id),
          orElse: () => member.isActiveByDefault,
        ) ??
        member.isActiveByDefault;
  }

  GymStaffSummary _applyLocalOverrides(
    GymStaffSummary member,
    AsyncValue<Set<String>>? activeStaffIdsAsync,
  ) {
    return GymStaffSummary(
      id: member.id,
      fullName: _fullNameOverrides[member.id] ?? member.fullName,
      firstName: member.firstName,
      lastName: member.lastName,
      phone: _phoneOverrides[member.id] ?? member.phone,
      email: member.email,
      imageUrl: member.imageUrl,
      roleValue: member.roleValue,
      isActive: _resolveIsActive(member, activeStaffIdsAsync),
      createdAtEpochMillis: member.createdAtEpochMillis,
    );
  }

  Future<void> _showLanguageSheet(AppLanguage selected) async {
    final strings = AppStrings.of(ref);
    var pending = selected;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _ProfileBottomSheet(
          title: strings.languageTitle,
          child: Column(
            children: [
              for (final option in AppLanguage.values) ...[
                _SelectionTile(
                  label: _languageLabel(option),
                  selected: option == pending,
                  leading: _Flag(option),
                  onTap: () => setModalState(() => pending = option),
                ),
                if (option != AppLanguage.values.last)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref.read(appLanguageProvider.notifier).setLanguage(pending);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCurrencySheet(AppCurrency selected) async {
    final strings = AppStrings.of(ref);
    var pending = selected;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _ProfileBottomSheet(
          title: strings.currencyTitle,
          child: Column(
            children: [
              for (final option in _profileCurrencies) ...[
                _SelectionTile(
                  label: option.shortLabel,
                  selected: option == pending,
                  leading: _CurrencyBadge(currency: option),
                  onTap: () => setModalState(() => pending = option),
                ),
                if (option != _profileCurrencies.last)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref.read(appCurrencyProvider.notifier).setCurrency(pending);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final strings = AppStrings.of(ref);
    final language = ref.watch(appLanguageProvider);
    final currency = ref.watch(appCurrencyProvider);
    final page = _currentPage;

    if (session?.userProfile == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final userProfile = session!.userProfile!;
    final liveGymProfileAsync = ref.watch(currentGymProfileStreamProvider);
    final gymProfile = liveGymProfileAsync.maybeWhen(
      data: (value) => value ?? session.gym,
      orElse: () => session.gym,
    );
    final canManageStaff =
        session.gymId != null &&
        session.gymId!.isNotEmpty &&
        session.role == AllClubsRole.owner;
    final displayName = gymProfile?.name ?? strings.noGymContext;
    final email =
        userProfile.email ??
        session.authUser.email ??
        session.authUser.primaryIdentifier;
    final billingStatus = gymProfile?.billingStatus?.trim();
    final billingNotice = _resolveBillingNotice(gymProfile);
    final subscriptionTitle = _resolveSubscriptionTitle(gymProfile);
    final subscriptionProvider = _resolveSubscriptionProvider(gymProfile);
    final subscriptionDescription = _resolveSubscriptionDescription(gymProfile);
    final manageSubscriptionUri =
        _resolveManageSubscriptionUri(gymProfile) ?? _subscriptionManageUri;
    final purchaseHistoryUri =
        _resolvePurchaseHistoryUri(gymProfile) ?? _subscriptionHistoryUri;
    final manageSubscriptionError = _resolveSubscriptionErrorMessage(
      gymProfile,
      fallback: 'Google Account subscriptions page did not open.',
    );
    final purchaseHistoryError = _resolveHistoryErrorMessage(
      gymProfile,
      fallback: 'Google Payments page did not open.',
    );
    final staffAsync = canManageStaff
        ? ref.watch(currentGymStaffStreamProvider)
        : null;
    final activeStaffIdsAsync = canManageStaff
        ? ref.watch(activeStaffIdsProvider)
        : null;

    final staffMembers =
        staffAsync?.maybeWhen(
          data: (items) => items
              .whereType<GymStaffSummary>()
              .where((member) => !_removedStaffIds.contains(member.id))
              .map(
                (member) => _applyLocalOverrides(member, activeStaffIdsAsync),
              )
              .take(5)
              .toList(growable: false),
          orElse: () => const <GymStaffSummary>[],
        ) ??
        const <GymStaffSummary>[];

    final canCreateStaff =
        (staffAsync?.maybeWhen(
              data: (items) => items
                  .whereType<GymStaffSummary>()
                  .where((member) => !_removedStaffIds.contains(member.id))
                  .length,
              orElse: () => 0,
            ) ??
            0) <
        5;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final key = child.key is ValueKey<String>
            ? (child.key! as ValueKey<String>).value
            : '';
        final begin = key == 'home'
            ? const Offset(-0.04, 0)
            : const Offset(0.06, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: switch (page) {
        _ProfilePage.home => _ProfileHomePage(
          key: const ValueKey<String>('home'),
          gymName: displayName,
          email: email,
          logoUrl: gymProfile?.logoUrl,
          canManageStaff: canManageStaff,
          onOpenSettings: () => _goToPage(_ProfilePage.settings),
          onOpenStaff: canManageStaff
              ? () => _goToPage(_ProfilePage.staff)
              : null,
          onOpenSubscription: () => _goToPage(_ProfilePage.subscription),
          onOpenAbout: () => _goToPage(_ProfilePage.about),
          onSignOut: _isSigningOut ? null : _signOut,
          signOutLabel: _isSigningOut ? strings.signingOut : strings.signOut,
        ),
        _ProfilePage.settings => _ProfileSettingsPage(
          key: const ValueKey<String>('settings'),
          strings: strings,
          language: language,
          currency: currency,
          phone: gymProfile?.phone,
          canEditGym: canManageStaff,
          onBack: () => _goToPage(_ProfilePage.home),
          onEditGym: canManageStaff ? () => _openGymEditor(session) : null,
          onSelectLanguage: () => _showLanguageSheet(language),
          onSelectCurrency: () => _showCurrencySheet(currency),
        ),
        _ProfilePage.staff => _ProfileStaffPage(
          key: const ValueKey<String>('staff'),
          title: 'Staffs',
          onBack: () => _goToPage(_ProfilePage.home),
          canManageStaff: canManageStaff,
          staffMembers: staffMembers,
          isLoading: staffAsync?.isLoading ?? false,
          errorMessage: staffAsync?.hasError == true
              ? staffAsync!.error.toString()
              : null,
          canCreateStaff: canCreateStaff,
          onCreateStaff: () => context.go(AppRoutes.createStaff),
          busyStaffIds: _busyStaffIds,
          onEditStaff: _editStaffMember,
          onToggleStaff: (member, isActive) =>
              _setStaffActive(member, isActive: isActive),
          onRemoveStaff: _removeStaffMember,
          ownerOnlyHint: strings.ownerOnlyHint,
        ),
        _ProfilePage.subscription => _ProfileSubscriptionPage(
          key: const ValueKey<String>('subscription'),
          onBack: () => _goToPage(_ProfilePage.home),
          gymProfile: gymProfile,
          billingStatus: billingStatus,
          billingNotice: billingNotice,
          subscriptionTitle: subscriptionTitle,
          subscriptionProvider: subscriptionProvider,
          subscriptionDescription: subscriptionDescription,
          manageSubscriptionLabel: _resolveManageSubscriptionLabel(gymProfile),
          manageSubscriptionSubtitle: _resolveManageSubscriptionSubtitle(
            gymProfile,
          ),
          purchaseHistoryLabel: _resolvePurchaseHistoryLabel(gymProfile),
          purchaseHistorySubtitle: _resolvePurchaseHistorySubtitle(gymProfile),
          onOpenManageSubscription: () => _openExternalProfilePage(
            manageSubscriptionUri,
            errorMessage: manageSubscriptionError,
          ),
          onOpenPurchaseHistory: () => _openExternalProfilePage(
            purchaseHistoryUri,
            errorMessage: purchaseHistoryError,
          ),
        ),
        _ProfilePage.about => _ProfileAboutPage(
          key: const ValueKey<String>('about'),
          onBack: () => _goToPage(_ProfilePage.home),
          onOpenWebsite: () => _openExternalProfilePage(
            _aboutWebsiteUri,
            errorMessage: 'AllClubs website did not open.',
          ),
        ),
      },
    );
  }
}

class _ProfileHomePage extends StatelessWidget {
  const _ProfileHomePage({
    super.key,
    required this.gymName,
    required this.email,
    required this.logoUrl,
    required this.canManageStaff,
    required this.onOpenSettings,
    required this.onOpenStaff,
    required this.onOpenSubscription,
    required this.onOpenAbout,
    required this.onSignOut,
    required this.signOutLabel,
  });

  final String gymName;
  final String email;
  final String? logoUrl;
  final bool canManageStaff;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenStaff;
  final VoidCallback onOpenSubscription;
  final VoidCallback onOpenAbout;
  final VoidCallback? onSignOut;
  final String signOutLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeroCard(
                    gymName: gymName,
                    email: email,
                    logoUrl: logoUrl,
                  ),
                  const SizedBox(height: 14),
                  _ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    subtitle: 'Language, currency, gym',
                    onTap: onOpenSettings,
                  ),
                  if (canManageStaff) ...[
                    const SizedBox(height: 12),
                    _ProfileMenuTile(
                      icon: Icons.groups_rounded,
                      label: 'Staffs',
                      subtitle: 'Team members and access',
                      onTap: onOpenStaff!,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Subscription',
                    subtitle: 'Open packages and plans',
                    onTap: onOpenSubscription,
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: Icons.info_outline_rounded,
                    label: 'Biz haqimizda',
                    subtitle: 'Brend va platforma haqida',
                    onTap: onOpenAbout,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSignOut,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5A1F2C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: Text(signOutLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'App version $_appVersionLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingsPage extends StatelessWidget {
  const _ProfileSettingsPage({
    super.key,
    required this.strings,
    required this.language,
    required this.currency,
    required this.phone,
    required this.canEditGym,
    required this.onBack,
    required this.onEditGym,
    required this.onSelectLanguage,
    required this.onSelectCurrency,
  });

  final AppStrings strings;
  final AppLanguage language;
  final AppCurrency currency;
  final String? phone;
  final bool canEditGym;
  final VoidCallback onBack;
  final VoidCallback? onEditGym;
  final VoidCallback onSelectLanguage;
  final VoidCallback onSelectCurrency;

  @override
  Widget build(BuildContext context) {
    return _ProfileSubpage(
      title: 'Settings',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileMenuTile(
            icon: Icons.language_rounded,
            label: strings.languageTitle,
            value: _languageLabel(language),
            onTap: onSelectLanguage,
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.payments_outlined,
            label: strings.currencyTitle,
            value: currency.shortLabel,
            onTap: onSelectCurrency,
          ),
          const SizedBox(height: 12),
          _ProfileInfoTile(
            icon: Icons.call_rounded,
            label: strings.phone,
            value: phone == null || phone!.trim().isEmpty
                ? strings.notSet
                : phone!.trim(),
          ),
          if (canEditGym && onEditGym != null) ...[
            const SizedBox(height: 12),
            _ProfileMenuTile(
              icon: Icons.edit_rounded,
              label: strings.editGym,
              subtitle: 'Gym name, logo, city, phone',
              onTap: onEditGym!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStaffPage extends StatelessWidget {
  const _ProfileStaffPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.canManageStaff,
    required this.staffMembers,
    required this.isLoading,
    required this.canCreateStaff,
    required this.busyStaffIds,
    required this.onEditStaff,
    required this.onToggleStaff,
    required this.onRemoveStaff,
    required this.onCreateStaff,
    required this.ownerOnlyHint,
    this.errorMessage,
  });

  final String title;
  final VoidCallback onBack;
  final bool canManageStaff;
  final List<GymStaffSummary> staffMembers;
  final bool isLoading;
  final bool canCreateStaff;
  final Set<String> busyStaffIds;
  final ValueChanged<GymStaffSummary> onEditStaff;
  final void Function(GymStaffSummary member, bool isActive) onToggleStaff;
  final ValueChanged<GymStaffSummary> onRemoveStaff;
  final VoidCallback onCreateStaff;
  final String ownerOnlyHint;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return _ProfileSubpage(
      title: title,
      onBack: onBack,
      child: _StaffsSection(
        canManageStaff: canManageStaff,
        staffMembers: staffMembers,
        isLoading: isLoading,
        errorMessage: errorMessage,
        canCreateStaff: canCreateStaff,
        onCreateStaff: onCreateStaff,
        busyStaffIds: busyStaffIds,
        onEditStaff: onEditStaff,
        onToggleStaff: onToggleStaff,
        onRemoveStaff: onRemoveStaff,
        ownerOnlyHint: ownerOnlyHint,
      ),
    );
  }
}

class _ProfileSubscriptionPage extends ConsumerStatefulWidget {
  const _ProfileSubscriptionPage({
    super.key,
    required this.onBack,
    required this.gymProfile,
    required this.billingStatus,
    required this.billingNotice,
    required this.subscriptionTitle,
    required this.subscriptionProvider,
    required this.subscriptionDescription,
    required this.manageSubscriptionLabel,
    required this.manageSubscriptionSubtitle,
    required this.purchaseHistoryLabel,
    required this.purchaseHistorySubtitle,
    required this.onOpenManageSubscription,
    required this.onOpenPurchaseHistory,
  });

  final VoidCallback onBack;
  final GymProfile? gymProfile;
  final String? billingStatus;
  final String? billingNotice;
  final String subscriptionTitle;
  final String subscriptionProvider;
  final String subscriptionDescription;
  final String manageSubscriptionLabel;
  final String manageSubscriptionSubtitle;
  final String purchaseHistoryLabel;
  final String purchaseHistorySubtitle;
  final VoidCallback onOpenManageSubscription;
  final VoidCallback onOpenPurchaseHistory;

  @override
  ConsumerState<_ProfileSubscriptionPage> createState() =>
      _ProfileSubscriptionPageState();
}

class _ProfileSubscriptionPageState
    extends ConsumerState<_ProfileSubscriptionPage> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _googlePlayProducts = const <ProductDetails>[];
  List<String> _notFoundProductIds = const <String>[];
  bool _isLoadingCatalog = false;
  bool _isStoreAvailable = false;
  bool _isRestoringPurchases = false;
  String? _activePurchaseProductId;
  String? _googlePlayStatusMessage;
  bool _googlePlayStatusIsError = false;

  Set<String> get _configuredProductIds =>
      resolveAndroidSubscriptionProductIds(widget.gymProfile);

  bool get _showsGooglePlayPurchaseSection {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    if (_hasBillingLinks(widget.gymProfile)) {
      return false;
    }

    return _configuredProductIds.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (_showsGooglePlayPurchaseSection) {
      _attachPurchaseStream();
      unawaited(_refreshGooglePlayCatalog());
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileSubscriptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldProductIds = resolveAndroidSubscriptionProductIds(
      oldWidget.gymProfile,
    );
    if (!setEquals(oldProductIds, _configuredProductIds) ||
        _hasBillingLinks(oldWidget.gymProfile) !=
            _hasBillingLinks(widget.gymProfile)) {
      if (_showsGooglePlayPurchaseSection) {
        _attachPurchaseStream();
        unawaited(_refreshGooglePlayCatalog());
      } else {
        _purchaseSubscription?.cancel();
        _purchaseSubscription = null;
        _googlePlayProducts = const <ProductDetails>[];
        _notFoundProductIds = const <String>[];
        _isLoadingCatalog = false;
        _isStoreAvailable = false;
        _isRestoringPurchases = false;
        _activePurchaseProductId = null;
        _googlePlayStatusMessage = null;
        _googlePlayStatusIsError = false;
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _attachPurchaseStream() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = ref
        .read(googlePlayBillingServiceProvider)
        .purchaseStream
        .listen(
          _handlePurchaseUpdates,
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) {
              return;
            }

            setState(() {
              _activePurchaseProductId = null;
              _isRestoringPurchases = false;
              _googlePlayStatusMessage = _describeGooglePlayError(
                error,
                fallback: 'Google Play purchase updates failed.',
              );
              _googlePlayStatusIsError = true;
            });
          },
        );
  }

  Future<void> _refreshGooglePlayCatalog() async {
    if (!_showsGooglePlayPurchaseSection) {
      return;
    }

    setState(() {
      _isLoadingCatalog = true;
      _googlePlayStatusMessage = null;
      _googlePlayStatusIsError = false;
    });

    try {
      final service = ref.read(googlePlayBillingServiceProvider);
      final isAvailable = await service.isAvailable();
      if (!mounted) {
        return;
      }

      if (!isAvailable) {
        setState(() {
          _isLoadingCatalog = false;
          _isStoreAvailable = false;
          _googlePlayProducts = const <ProductDetails>[];
          _notFoundProductIds = const <String>[];
          _googlePlayStatusMessage =
              'Google Play Store is not available on this device.';
          _googlePlayStatusIsError = true;
        });
        return;
      }

      final response = await service.queryProducts(_configuredProductIds);
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCatalog = false;
        _isStoreAvailable = true;
        _googlePlayProducts = response.productDetails;
        _notFoundProductIds = response.notFoundIDs;
        if (response.productDetails.isEmpty) {
          _googlePlayStatusMessage = response.notFoundIDs.isEmpty
              ? 'No Google Play subscription products are available yet.'
              : 'Configured Google Play product IDs were not found.';
          _googlePlayStatusIsError = response.notFoundIDs.isNotEmpty;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCatalog = false;
        _isStoreAvailable = false;
        _googlePlayProducts = const <ProductDetails>[];
        _notFoundProductIds = const <String>[];
        _googlePlayStatusMessage = _describeGooglePlayError(
          error,
          fallback: 'Google Play products could not be loaded.',
        );
        _googlePlayStatusIsError = true;
      });
    }
  }

  Future<void> _restoreGooglePlayPurchases() async {
    if (_isRestoringPurchases) {
      return;
    }

    setState(() {
      _isRestoringPurchases = true;
      _googlePlayStatusMessage = 'Checking purchases in Google Play...';
      _googlePlayStatusIsError = false;
    });

    try {
      await ref.read(googlePlayBillingServiceProvider).restorePurchases();
      if (!mounted) {
        return;
      }

      setState(() {
        _googlePlayStatusMessage =
            'Google Play restore started. Matching purchases will appear here.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringPurchases = false;
        _googlePlayStatusMessage = _describeGooglePlayError(
          error,
          fallback: 'Google Play purchases could not be restored.',
        );
        _googlePlayStatusIsError = true;
      });
    }
  }

  Future<void> _buyGooglePlayProduct(ProductDetails product) async {
    if (_activePurchaseProductId != null) {
      return;
    }

    setState(() {
      _activePurchaseProductId = product.id;
      _googlePlayStatusMessage = null;
      _googlePlayStatusIsError = false;
    });

    try {
      final launched = await ref
          .read(googlePlayBillingServiceProvider)
          .buySubscription(product);
      if (!mounted) {
        return;
      }

      setState(() {
        if (!launched) {
          _activePurchaseProductId = null;
          _googlePlayStatusMessage = 'Google Play purchase sheet did not open.';
          _googlePlayStatusIsError = true;
          return;
        }

        _googlePlayStatusMessage =
            'Continue the subscription purchase in Google Play.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _activePurchaseProductId = null;
        _googlePlayStatusMessage = _describeGooglePlayError(
          error,
          fallback: 'Google Play purchase could not be started.',
        );
        _googlePlayStatusIsError = true;
      });
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (!_configuredProductIds.contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        if (!mounted) {
          return;
        }

        setState(() {
          _googlePlayStatusMessage = 'Google Play purchase is pending.';
          _googlePlayStatusIsError = false;
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _activePurchaseProductId = null;
          _isRestoringPurchases = false;
          final errorMessage = purchase.error!.message.trim();
          _googlePlayStatusMessage = errorMessage.isNotEmpty
              ? errorMessage
              : 'Google Play purchase failed.';
          _googlePlayStatusIsError = true;
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final session = ref.read(bootstrapControllerProvider).session;
        if (purchase.pendingCompletePurchase) {
          try {
            await ref
                .read(googlePlayBillingServiceProvider)
                .completePurchase(purchase);
          } catch (_) {
            // Keep the UI responsive even if the store acknowledgement retries later.
          }
        }

        if (session?.gymId != null &&
            session!.gymId!.trim().isNotEmpty &&
            session.authUser.uid.trim().isNotEmpty) {
          try {
            await ref
                .read(googlePlayReceiptSyncServiceProvider)
                .queuePurchase(
                  gymId: session.gymId!,
                  userId: session.authUser.uid,
                  purchase: purchase,
                );
          } catch (_) {
            // Queueing is best-effort until backend verification is connected.
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _activePurchaseProductId = null;
          _isRestoringPurchases = false;
          _googlePlayStatusMessage =
              'Google Play purchase was received and queued for sync. Server verification is still required before gym access can be updated.';
          _googlePlayStatusIsError = false;
        });
        continue;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _activePurchaseProductId = null;
        _isRestoringPurchases = false;
        _googlePlayStatusMessage = 'Google Play purchase was canceled.';
        _googlePlayStatusIsError = false;
      });
    }
  }

  Widget _buildBillingStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Billing access status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (widget.billingStatus != null &&
              widget.billingStatus!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Status: ${widget.billingStatus}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.billingNotice != null &&
              widget.billingNotice!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.billingNotice!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionOverviewCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _profilePanelDecoration(theme, radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: _profileIconDecoration(),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subscriptionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subscriptionProvider,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.subscriptionDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGooglePlaySection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _profilePanelDecoration(theme, radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: _profileIconDecoration(),
                child: const Icon(
                  Icons.android_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Play purchase',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Native Android subscription flow',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoadingCatalog ? null : _refreshGooglePlayCatalog,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Google Play products',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Use Google Play to buy or restore this gym subscription on Android. Product IDs are read from the gym document or the ALLCLUBS_ANDROID_SUBSCRIPTION_IDS build flag.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (_googlePlayStatusMessage != null &&
              _googlePlayStatusMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _ProfileInlineMessage(
              message: _googlePlayStatusMessage!,
              isError: _googlePlayStatusIsError,
            ),
          ],
          if (_notFoundProductIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Missing product IDs: ${_notFoundProductIds.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _googlePlayProducts.isEmpty
                ? <Widget>[
                    OutlinedButton.icon(
                      onPressed: _isRestoringPurchases
                          ? null
                          : _restoreGooglePlayPurchases,
                      icon: _isRestoringPurchases
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded),
                      label: Text(
                        _isRestoringPurchases
                            ? 'Restoring...'
                            : _isLoadingCatalog
                            ? 'Loading products...'
                            : _isStoreAvailable
                            ? 'Restore purchases'
                            : 'Retry Google Play',
                      ),
                    ),
                  ]
                : _googlePlayProducts
                      .map((product) {
                        final isPurchasing =
                            _activePurchaseProductId == product.id;
                        return _ProfileGooglePlayProductCard(
                          product: product,
                          isBusy: isPurchasing,
                          onBuy: () => _buyGooglePlayProduct(product),
                        );
                      })
                      .toList(growable: false),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isRestoringPurchases
                ? null
                : _restoreGooglePlayPurchases,
            icon: _isRestoringPurchases
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: Text(
              _isRestoringPurchases ? 'Restoring...' : 'Restore purchases',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ProfileSubpage(
      title: 'Subscription',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.billingNotice != null || widget.billingStatus != null) ...[
            _buildBillingStatusCard(theme),
            const SizedBox(height: 12),
          ],
          _buildSubscriptionOverviewCard(theme),
          if (_showsGooglePlayPurchaseSection) ...[
            const SizedBox(height: 12),
            _buildGooglePlaySection(theme),
          ],
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.manage_accounts_outlined,
            label: widget.manageSubscriptionLabel,
            subtitle: widget.manageSubscriptionSubtitle,
            onTap: widget.onOpenManageSubscription,
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.receipt_long_outlined,
            label: widget.purchaseHistoryLabel,
            subtitle: widget.purchaseHistorySubtitle,
            onTap: widget.onOpenPurchaseHistory,
          ),
        ],
      ),
    );
  }
}

class _ProfileInlineMessage extends StatelessWidget {
  const _ProfileInlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isError ? AppColors.danger : AppColors.success;
    final background = isError
        ? AppColors.danger.withValues(alpha: 0.1)
        : AppColors.success.withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ProfileGooglePlayProductCard extends StatelessWidget {
  const _ProfileGooglePlayProductCard({
    required this.product,
    required this.isBusy,
    required this.onBuy,
  });

  final ProductDetails product;
  final bool isBusy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _profilePanelDecoration(theme, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.price,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              product.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onBuy,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(isBusy ? 'Opening...' : 'Buy in Google Play'),
            ),
          ),
        ],
      ),
    );
  }
}

String? _resolveBillingNotice(GymProfile? gym) {
  if (gym == null) {
    return null;
  }

  final explicitReason = gym.readOnlyReason?.trim();
  if (explicitReason != null && explicitReason.isNotEmpty) {
    return explicitReason;
  }

  final normalizedStatus = gym.billingStatus?.trim().toLowerCase();
  final isBlockedStatus =
      normalizedStatus == 'inactive' ||
      normalizedStatus == 'blocked' ||
      normalizedStatus == 'read_only' ||
      normalizedStatus == 'read-only' ||
      normalizedStatus == 'past_due' ||
      normalizedStatus == 'payment_required';

  if (gym.isReadOnly == true || isBlockedStatus) {
    return gymBillingReadOnlyMessage;
  }

  return null;
}

String _resolveSubscriptionTitle(GymProfile? gym) {
  final planName = gym?.billingPlanName?.trim();
  if (planName != null && planName.isNotEmpty) {
    return planName;
  }

  return 'AllClubs app subscription';
}

String _resolveSubscriptionProvider(GymProfile? gym) {
  final provider = gym?.billingProvider?.trim();
  if (provider != null && provider.isNotEmpty) {
    return provider;
  }

  return 'Google Play Billing';
}

String _resolveSubscriptionDescription(GymProfile? gym) {
  final provider = gym?.billingProvider?.trim();
  final customerEmail = gym?.billingCustomerEmail?.trim();
  if (provider != null && provider.isNotEmpty) {
    final buffer = StringBuffer(
      'Billing for this gym is managed in $provider.',
    );
    if (customerEmail != null && customerEmail.isNotEmpty) {
      buffer.write(' Customer email: $customerEmail.');
    }
    if ((gym?.billingPortalUrl?.trim().isNotEmpty ?? false) ||
        (gym?.billingCheckoutUrl?.trim().isNotEmpty ?? false) ||
        (gym?.billingDashboardUrl?.trim().isNotEmpty ?? false)) {
      buffer.write(
        ' Use the links below to manage the subscription or review billing activity.',
      );
    }
    return buffer.toString();
  }

  return 'App subscription renewals, cancellations, and purchase history are managed in Google services.';
}

String _resolveManageSubscriptionLabel(GymProfile? gym) {
  return _hasBillingProvider(gym) ? 'Manage billing' : 'Manage subscription';
}

String _resolveManageSubscriptionSubtitle(GymProfile? gym) {
  final provider = gym?.billingProvider?.trim();
  if (gym?.billingPortalUrl?.trim().isNotEmpty ?? false) {
    return provider == null || provider.isEmpty
        ? 'Open the billing portal'
        : 'Open the $provider billing portal';
  }

  if (gym?.billingCheckoutUrl?.trim().isNotEmpty ?? false) {
    return provider == null || provider.isEmpty
        ? 'Open the billing checkout'
        : 'Open the $provider checkout';
  }

  return 'Renew, pause, or cancel in Google Account';
}

String _resolvePurchaseHistoryLabel(GymProfile? gym) {
  return _hasBillingProvider(gym) ? 'Billing activity' : 'Payment history';
}

String _resolvePurchaseHistorySubtitle(GymProfile? gym) {
  final provider = gym?.billingProvider?.trim();
  if (gym?.billingDashboardUrl?.trim().isNotEmpty ?? false) {
    return provider == null || provider.isEmpty
        ? 'Open the billing dashboard'
        : 'Open the $provider billing dashboard';
  }

  if (gym?.billingPortalUrl?.trim().isNotEmpty ?? false) {
    return provider == null || provider.isEmpty
        ? 'Open billing activity'
        : 'Open billing activity in $provider';
  }

  return 'Open charges and subscription activity';
}

Uri? _resolveManageSubscriptionUri(GymProfile? gym) {
  return _firstValidProfileUri([
    gym?.billingPortalUrl,
    gym?.billingCheckoutUrl,
  ]);
}

Uri? _resolvePurchaseHistoryUri(GymProfile? gym) {
  return _firstValidProfileUri([
    gym?.billingDashboardUrl,
    gym?.billingPortalUrl,
    gym?.billingCheckoutUrl,
  ]);
}

String _resolveSubscriptionErrorMessage(
  GymProfile? gym, {
  required String fallback,
}) {
  final provider = gym?.billingProvider?.trim();
  if (provider != null && provider.isNotEmpty) {
    return '$provider billing page did not open.';
  }

  return fallback;
}

String _resolveHistoryErrorMessage(
  GymProfile? gym, {
  required String fallback,
}) {
  final provider = gym?.billingProvider?.trim();
  if (provider != null && provider.isNotEmpty) {
    return '$provider billing activity page did not open.';
  }

  return fallback;
}

bool _hasBillingProvider(GymProfile? gym) {
  final provider = gym?.billingProvider?.trim();
  return provider != null && provider.isNotEmpty;
}

bool _hasBillingLinks(GymProfile? gym) {
  return (gym?.billingPortalUrl?.trim().isNotEmpty ?? false) ||
      (gym?.billingCheckoutUrl?.trim().isNotEmpty ?? false) ||
      (gym?.billingDashboardUrl?.trim().isNotEmpty ?? false);
}

String _describeGooglePlayError(Object error, {required String fallback}) {
  final normalized = error.toString().replaceFirst('Exception: ', '').trim();
  if (normalized.isEmpty) {
    return fallback;
  }

  return normalized;
}

Uri? _firstValidProfileUri(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final normalized = candidate?.trim();
    if (normalized == null || normalized.isEmpty) {
      continue;
    }

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri;
    }
  }

  return null;
}

class _ProfileAboutPage extends StatelessWidget {
  const _ProfileAboutPage({
    super.key,
    required this.onBack,
    required this.onOpenWebsite,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ProfileSubpage(
      title: 'Biz haqimizda',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AllClubs',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gym boshqaruvi uchun yagona platforma.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: _profilePanelDecoration(theme, radius: 26),
            child: Text(
              'AllClubs ichida clients, sessions, finance, packages va POS oqimlari bitta light minimal mobile tizimda birlashadi.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'allclubs.app',
            onTap: onOpenWebsite,
          ),
          const SizedBox(height: 12),
          _ProfileInfoTile(
            icon: Icons.verified_outlined,
            label: 'App version',
            value: _appVersionLabel,
          ),
        ],
      ),
    );
  }
}

class _ProfileSubpage extends StatelessWidget {
  const _ProfileSubpage({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showInlineHeader = GoRouter.maybeOf(context) == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showInlineHeader) ...[
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.gymName,
    required this.email,
    required this.logoUrl,
  });

  final String gymName;
  final String email;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        children: [
          _LogoPreview(name: gymName, logoUrl: logoUrl, size: 86),
          const SizedBox(height: 14),
          Text(
            gymName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: _profilePanelDecoration(theme),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: _profileIconDecoration(),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: _profilePanelDecoration(theme),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: _profileIconDecoration(),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffsSection extends StatelessWidget {
  const _StaffsSection({
    required this.canManageStaff,
    required this.staffMembers,
    required this.isLoading,
    required this.canCreateStaff,
    required this.busyStaffIds,
    required this.onEditStaff,
    required this.onToggleStaff,
    required this.onRemoveStaff,
    required this.onCreateStaff,
    required this.ownerOnlyHint,
    this.errorMessage,
  });

  final bool canManageStaff;
  final List<GymStaffSummary> staffMembers;
  final bool isLoading;
  final bool canCreateStaff;
  final Set<String> busyStaffIds;
  final ValueChanged<GymStaffSummary> onEditStaff;
  final void Function(GymStaffSummary member, bool isActive) onToggleStaff;
  final ValueChanged<GymStaffSummary> onRemoveStaff;
  final VoidCallback onCreateStaff;
  final String ownerOnlyHint;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!canManageStaff) {
      return Text(
        ownerOnlyHint,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canCreateStaff ? onCreateStaff : null,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Create staff'),
        ),
        const SizedBox(height: 16),
        if (isLoading && staffMembers.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (errorMessage != null)
          Text(
            errorMessage!.replaceFirst('Exception: ', ''),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (staffMembers.isEmpty)
          Text(
            'No staff yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < staffMembers.length; index++) ...[
                StaffMemberCard(
                  member: staffMembers[index],
                  isBusy: busyStaffIds.contains(staffMembers[index].id),
                  onEdit: () => onEditStaff(staffMembers[index]),
                  onToggleActive: (isActive) =>
                      onToggleStaff(staffMembers[index], isActive),
                  onRemove: () => onRemoveStaff(staffMembers[index]),
                ),
                if (index != staffMembers.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _ProfileBottomSheet extends StatelessWidget {
  const _ProfileBottomSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        decoration: _profilePanelDecoration(theme, radius: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.34)
                  : AppColors.border.withValues(alpha: 0.72),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 28, height: 28, child: leading),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.currency});

  final AppCurrency currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        currency.code,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

BoxDecoration _profilePanelDecoration(
  ThemeData theme, {
  double radius = 24,
  Color? color,
}) {
  return BoxDecoration(
    color: color ?? theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
    boxShadow: [
      BoxShadow(
        color: AppColors.canvasStrong.withValues(alpha: 0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration _profileIconDecoration() {
  return BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(16),
  );
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.name, this.logoUrl, this.size = 86});

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasLogo
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(label: name),
              )
            : _AvatarFallback(label: name),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6DA5FF), Color(0xFF8EA7C2)],
        ),
      ),
      child: Center(
        child: Text(
          _initials(label),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.language);

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: switch (language) {
        AppLanguage.uz => Column(
          children: [
            Expanded(flex: 5, child: Container(color: const Color(0xFF1EB5E7))),
            Container(height: 2, color: const Color(0xFFE2525C)),
            Expanded(flex: 5, child: Container(color: Colors.white)),
            Container(height: 2, color: const Color(0xFFE2525C)),
            Expanded(flex: 5, child: Container(color: const Color(0xFF21A35A))),
          ],
        ),
        AppLanguage.ru => Column(
          children: [
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFF2753C7))),
            Expanded(child: Container(color: const Color(0xFFD64152))),
          ],
        ),
        AppLanguage.en => LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: List.generate(
                  7,
                  (index) => Expanded(
                    child: Container(
                      color: index.isEven
                          ? const Color(0xFFD14A57)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: constraints.maxWidth * 0.42,
                  height: constraints.maxHeight * 0.58,
                  color: const Color(0xFF284BAF),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

String _languageLabel(AppLanguage language) {
  return switch (language) {
    AppLanguage.uz => 'O\'zbekcha',
    AppLanguage.ru => 'Русский',
    AppLanguage.en => 'English',
  };
}

String _initials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'A';
  }

  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
