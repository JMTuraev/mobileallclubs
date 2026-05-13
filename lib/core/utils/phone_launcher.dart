import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_language.dart';
import 'phone_utils.dart';

enum PhoneLaunchResult { launched, cancelled, invalid, unavailable }

Future<bool> launchPhoneDialer(String? phone) async {
  final normalizedPhone = normalizeDialablePhone(phone);
  if (normalizedPhone == null) {
    return false;
  }

  return launchUrl(
    Uri(scheme: 'tel', path: normalizedPhone),
    mode: LaunchMode.externalApplication,
  );
}

Future<PhoneLaunchResult> confirmAndLaunchPhoneDialer(
  BuildContext context,
  String? phone,
) async {
  final normalizedPhone = normalizeDialablePhone(phone);
  if (normalizedPhone == null) {
    return PhoneLaunchResult.invalid;
  }

  final language = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appLanguageProvider);
  final title = switch (language) {
    AppLanguage.uz => 'Qo\'ng\'iroq qilish',
    AppLanguage.ru => 'Позвонить',
    AppLanguage.en => 'Call client',
  };
  final message = switch (language) {
    AppLanguage.uz => '$normalizedPhone raqamiga qo\'ng\'iroq qilinsinmi?',
    AppLanguage.ru => 'Позвонить на номер $normalizedPhone?',
    AppLanguage.en => 'Call $normalizedPhone?',
  };
  final cancelLabel = switch (language) {
    AppLanguage.uz => 'Bekor qilish',
    AppLanguage.ru => 'Отмена',
    AppLanguage.en => 'Cancel',
  };
  final confirmLabel = switch (language) {
    AppLanguage.uz => 'Qo\'ng\'iroq qilish',
    AppLanguage.ru => 'Позвонить',
    AppLanguage.en => 'Call',
  };

  final shouldLaunch =
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  if (!shouldLaunch) {
    return PhoneLaunchResult.cancelled;
  }

  final launched = await launchPhoneDialer(normalizedPhone);
  return launched ? PhoneLaunchResult.launched : PhoneLaunchResult.unavailable;
}
