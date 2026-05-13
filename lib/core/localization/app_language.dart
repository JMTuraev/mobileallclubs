import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { uz, ru, en }

extension AppLanguagePresentation on AppLanguage {
  Locale get locale {
    return switch (this) {
      AppLanguage.uz => const Locale('uz'),
      AppLanguage.ru => const Locale('ru'),
      AppLanguage.en => const Locale('en'),
    };
  }

  String get shortCode {
    return switch (this) {
      AppLanguage.uz => 'uz',
      AppLanguage.ru => 'ru',
      AppLanguage.en => 'en',
    };
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.en;

  void setLanguage(AppLanguage language) {
    state = language;
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  static AppStrings of(WidgetRef ref) {
    return AppStrings(ref.watch(appLanguageProvider));
  }

  String get appTitle => 'AllClubs Mobile';

  String get backAgainToExit {
    return switch (language) {
      AppLanguage.uz => 'Dasturdan chiqish uchun yana bosing.',
      AppLanguage.ru => 'Нажмите еще раз, чтобы выйти из приложения.',
      AppLanguage.en => 'Back again to exit the app.',
    };
  }

  String get pos => 'POS';

  String get stats {
    return switch (language) {
      AppLanguage.uz => 'Stat',
      AppLanguage.ru => 'Стат',
      AppLanguage.en => 'Stats',
    };
  }

  String get profile {
    return switch (language) {
      AppLanguage.uz => 'Profil',
      AppLanguage.ru => 'Профиль',
      AppLanguage.en => 'Profile',
    };
  }

  String get clients {
    return switch (language) {
      AppLanguage.uz => 'Mijozlar',
      AppLanguage.ru => 'Клиенты',
      AppLanguage.en => 'Clients',
    };
  }

  String get sessions {
    return switch (language) {
      AppLanguage.uz => 'Seanslar',
      AppLanguage.ru => 'Сеансы',
      AppLanguage.en => 'Sessions',
    };
  }

  String get finance {
    return switch (language) {
      AppLanguage.uz => 'Moliya',
      AppLanguage.ru => 'Финансы',
      AppLanguage.en => 'Finance',
    };
  }

  String get packages {
    return switch (language) {
      AppLanguage.uz => 'Paketlar',
      AppLanguage.ru => 'Пакеты',
      AppLanguage.en => 'Packages',
    };
  }

  String get profileHeadline {
    return switch (language) {
      AppLanguage.uz => 'Profil',
      AppLanguage.ru => 'Профиль',
      AppLanguage.en => 'Profile',
    };
  }

  String get profileSubtitle {
    return switch (language) {
      AppLanguage.uz => 'Zal, jamoa, til va akkaunt boshqaruvi bir joyda.',
      AppLanguage.ru =>
        'Управляйте залом, командой, языком и аккаунтом в одном месте.',
      AppLanguage.en =>
        'Manage your gym, team, language, and account from one place.',
    };
  }

  String get teamSectionTitle {
    return switch (language) {
      AppLanguage.uz => 'Staff boshqaruvi',
      AppLanguage.ru => 'Управление staff',
      AppLanguage.en => 'Staff management',
    };
  }

  String get teamSectionSubtitle {
    return switch (language) {
      AppLanguage.uz =>
        'Staff yaratish, tahrirlash, o‘chirish va takliflarni shu yerdan boshqarasiz.',
      AppLanguage.ru =>
        'Отсюда можно создавать staff, редактировать участников, удалять их и управлять приглашениями.',
      AppLanguage.en =>
        'Create staff, edit members, remove them, and manage invites from here.',
    };
  }

  String get manageStaff {
    return switch (language) {
      AppLanguage.uz => 'Staff ro‘yxati',
      AppLanguage.ru => 'Список staff',
      AppLanguage.en => 'Manage staff',
    };
  }

  String get createStaff {
    return switch (language) {
      AppLanguage.uz => 'Staff yaratish',
      AppLanguage.ru => 'Создать staff',
      AppLanguage.en => 'Create staff',
    };
  }

  String get staffInvites {
    return switch (language) {
      AppLanguage.uz => 'Takliflar',
      AppLanguage.ru => 'Приглашения',
      AppLanguage.en => 'Staff invites',
    };
  }

  String get ownerOnlyHint {
    return switch (language) {
      AppLanguage.uz => 'Bu bo‘lim faqat owner akkaunti uchun faol.',
      AppLanguage.ru => 'Этот раздел доступен только для owner аккаунта.',
      AppLanguage.en => 'This section is available only for the owner account.',
    };
  }

  String get gymSectionTitle {
    return switch (language) {
      AppLanguage.uz => 'Zal ma’lumotlari',
      AppLanguage.ru => 'Данные зала',
      AppLanguage.en => 'Gym settings',
    };
  }

  String get gymSectionSubtitle {
    return switch (language) {
      AppLanguage.uz =>
        'Zal nomi, shahar, telefon va logoni shu yerdan yangilang.',
      AppLanguage.ru =>
        'Обновляйте название зала, город, телефон и логотип отсюда.',
      AppLanguage.en => 'Keep the gym name, city, phone, and logo up to date.',
    };
  }

  String get editGym {
    return switch (language) {
      AppLanguage.uz => 'Zalni tahrirlash',
      AppLanguage.ru => 'Редактировать зал',
      AppLanguage.en => 'Edit gym info',
    };
  }

  String get gymName {
    return switch (language) {
      AppLanguage.uz => 'Zal nomi',
      AppLanguage.ru => 'Название зала',
      AppLanguage.en => 'Gym name',
    };
  }

  String get city {
    return switch (language) {
      AppLanguage.uz => 'Shahar',
      AppLanguage.ru => 'Город',
      AppLanguage.en => 'City',
    };
  }

  String get phone {
    return switch (language) {
      AppLanguage.uz => 'Telefon',
      AppLanguage.ru => 'Телефон',
      AppLanguage.en => 'Phone',
    };
  }

  String get email {
    return switch (language) {
      AppLanguage.uz => 'Email',
      AppLanguage.ru => 'Email',
      AppLanguage.en => 'Email',
    };
  }

  String get staff {
    return switch (language) {
      AppLanguage.uz => 'Staff',
      AppLanguage.ru => 'Staff',
      AppLanguage.en => 'Staff',
    };
  }

  String get active {
    return switch (language) {
      AppLanguage.uz => 'Faol',
      AppLanguage.ru => 'Активные',
      AppLanguage.en => 'Active',
    };
  }

  String get pendingInvites {
    return switch (language) {
      AppLanguage.uz => 'Kutilayotgan takliflar',
      AppLanguage.ru => 'Ожидающие приглашения',
      AppLanguage.en => 'Pending invites',
    };
  }

  String get languageTitle {
    return switch (language) {
      AppLanguage.uz => 'Til',
      AppLanguage.ru => 'Язык',
      AppLanguage.en => 'Language',
    };
  }

  String get languageSubtitle {
    return switch (language) {
      AppLanguage.uz => 'Ilova tilini tanlang.',
      AppLanguage.ru => 'Выберите язык приложения.',
      AppLanguage.en => 'Choose the app language.',
    };
  }

  String get currencyTitle {
    return switch (language) {
      AppLanguage.uz => 'Valyuta',
      AppLanguage.ru => 'Валюта',
      AppLanguage.en => 'Currency',
    };
  }

  String get currencySubtitle {
    return switch (language) {
      AppLanguage.uz => 'Narxlar va to‘lovlar shu birlikda ko‘rinadi.',
      AppLanguage.ru => 'Цены и платежи будут показаны в этой валюте.',
      AppLanguage.en => 'Prices and payments will be shown in this currency.',
    };
  }

  String get subscriptionTitle {
    return switch (language) {
      AppLanguage.uz => 'Subscription',
      AppLanguage.ru => 'Подписка',
      AppLanguage.en => 'Subscription',
    };
  }

  String get subscriptionDescription {
    return switch (language) {
      AppLanguage.uz =>
        'Paketlar va subscription boshqaruvini packages bo‘limidan ochasiz.',
      AppLanguage.ru =>
        'Управление пакетами и подписками открывается из раздела packages.',
      AppLanguage.en =>
        'Open package and subscription management from the packages section.',
    };
  }

  String get openPackages {
    return switch (language) {
      AppLanguage.uz => 'Packages ni ochish',
      AppLanguage.ru => 'Открыть packages',
      AppLanguage.en => 'Open packages',
    };
  }

  String get addLogo {
    return switch (language) {
      AppLanguage.uz => 'Logo qo‘shish',
      AppLanguage.ru => 'Добавить логотип',
      AppLanguage.en => 'Add logo',
    };
  }

  String get replaceLogo {
    return switch (language) {
      AppLanguage.uz => 'Logoni almashtirish',
      AppLanguage.ru => 'Заменить логотип',
      AppLanguage.en => 'Replace logo',
    };
  }

  String get removeLogo {
    return switch (language) {
      AppLanguage.uz => 'Logoni olib tashlash',
      AppLanguage.ru => 'Убрать логотип',
      AppLanguage.en => 'Remove logo',
    };
  }

  String get cancel {
    return switch (language) {
      AppLanguage.uz => 'Bekor qilish',
      AppLanguage.ru => 'Отмена',
      AppLanguage.en => 'Cancel',
    };
  }

  String get save {
    return switch (language) {
      AppLanguage.uz => 'Saqlash',
      AppLanguage.ru => 'Сохранить',
      AppLanguage.en => 'Save',
    };
  }

  String get saveChanges {
    return switch (language) {
      AppLanguage.uz => 'O‘zgarishlarni saqlash',
      AppLanguage.ru => 'Сохранить изменения',
      AppLanguage.en => 'Save changes',
    };
  }

  String get gymSaved {
    return switch (language) {
      AppLanguage.uz => 'Zal ma’lumotlari yangilandi.',
      AppLanguage.ru => 'Данные зала обновлены.',
      AppLanguage.en => 'Gym information updated.',
    };
  }

  String get signOut {
    return switch (language) {
      AppLanguage.uz => 'Chiqish',
      AppLanguage.ru => 'Выйти',
      AppLanguage.en => 'Sign out',
    };
  }

  String get signingOut {
    return switch (language) {
      AppLanguage.uz => 'Chiqilmoqda...',
      AppLanguage.ru => 'Выход...',
      AppLanguage.en => 'Signing out...',
    };
  }

  String get developerDiagnostics {
    return switch (language) {
      AppLanguage.uz => 'Debug diagnostika',
      AppLanguage.ru => 'Диагностика',
      AppLanguage.en => 'Developer diagnostics',
    };
  }

  String get brandingSubtitle {
    return switch (language) {
      AppLanguage.uz => 'AllClubs platformasi',
      AppLanguage.ru => 'Платформа AllClubs',
      AppLanguage.en => 'Powered by AllClubs',
    };
  }

  String get poweredByAllClubs {
    return switch (language) {
      AppLanguage.uz => 'Powered by AllClubs',
      AppLanguage.ru => 'Powered by AllClubs',
      AppLanguage.en => 'Powered by AllClubs',
    };
  }

  String get standardPlan {
    return switch (language) {
      AppLanguage.uz => 'Standard',
      AppLanguage.ru => 'Standard',
      AppLanguage.en => 'Standard',
    };
  }

  String get notSet {
    return switch (language) {
      AppLanguage.uz => 'Kiritilmagan',
      AppLanguage.ru => 'Не указано',
      AppLanguage.en => 'Not set',
    };
  }

  String get noGymContext {
    return switch (language) {
      AppLanguage.uz => 'Zal tanlanmagan',
      AppLanguage.ru => 'Зал не выбран',
      AppLanguage.en => 'No gym selected',
    };
  }

  String get gymNameRequired {
    return switch (language) {
      AppLanguage.uz => 'Zal nomi majburiy.',
      AppLanguage.ru => 'Название зала обязательно.',
      AppLanguage.en => 'Gym name is required.',
    };
  }

  String get invalidPhone {
    return switch (language) {
      AppLanguage.uz => 'Telefon raqami noto‘g‘ri.',
      AppLanguage.ru => 'Некорректный номер телефона.',
      AppLanguage.en => 'Invalid phone number.',
    };
  }

  String get logoSelectionFailedPrefix {
    return switch (language) {
      AppLanguage.uz => 'Logo tanlashda xato',
      AppLanguage.ru => 'Не удалось выбрать логотип',
      AppLanguage.en => 'Logo selection failed',
    };
  }

  String get signOutFailedPrefix {
    return switch (language) {
      AppLanguage.uz => 'Chiqishda xato',
      AppLanguage.ru => 'Ошибка при выходе',
      AppLanguage.en => 'Sign-out failed',
    };
  }

  String get gymUpdateFailedPrefix {
    return switch (language) {
      AppLanguage.uz => 'Yangilashda xato',
      AppLanguage.ru => 'Ошибка обновления',
      AppLanguage.en => 'Update failed',
    };
  }

  String get roleOwner {
    return switch (language) {
      AppLanguage.uz => 'Owner',
      AppLanguage.ru => 'Owner',
      AppLanguage.en => 'Owner',
    };
  }

  String get roleStaff {
    return switch (language) {
      AppLanguage.uz => 'Staff',
      AppLanguage.ru => 'Staff',
      AppLanguage.en => 'Staff',
    };
  }

  String get roleSuperAdmin {
    return switch (language) {
      AppLanguage.uz => 'Super admin',
      AppLanguage.ru => 'Супер админ',
      AppLanguage.en => 'Super admin',
    };
  }

  String get roleUnknown {
    return switch (language) {
      AppLanguage.uz => 'Noma’lum',
      AppLanguage.ru => 'Неизвестно',
      AppLanguage.en => 'Unknown',
    };
  }
}
