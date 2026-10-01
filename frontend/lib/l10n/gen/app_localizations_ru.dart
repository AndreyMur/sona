// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Sona';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceThemeSection => 'Тема оформления';

  @override
  String get appearanceThemeHint =>
      'Тема применяется ко всему приложению. «Системная» повторяет настройку устройства.';

  @override
  String get themeModeSystem => 'Системная';

  @override
  String get themeModeSystemDescription => 'Как в системе';

  @override
  String get themeModeLight => 'Светлая';

  @override
  String get themeModeLightDescription => 'Всегда светлое оформление';

  @override
  String get themeModeDark => 'Тёмная';

  @override
  String get themeModeDarkDescription => 'Всегда тёмное оформление';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileSections => 'Разделы';

  @override
  String get profileData => 'Данные';

  @override
  String get profileDataSubtitle => 'Экспорт и удаление';

  @override
  String get profileAccounts => 'Счета';

  @override
  String get profileCategories => 'Категории';

  @override
  String get profileNotifications => 'Уведомления';

  @override
  String get profileSecurity => 'Безопасность';

  @override
  String get profileSecurityOn => 'Защита включена';

  @override
  String get profileSecurityOff => 'PIN и биометрия';

  @override
  String get profileAppearance => 'Внешний вид';

  @override
  String get profileAppearanceSubtitle => 'Светлая, тёмная, системная';

  @override
  String get profileSubscription => 'Подписка';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileNoName => 'Без имени';

  @override
  String get profileAddEmail => 'Добавьте email';

  @override
  String get profileEditTitle => 'Профиль';

  @override
  String get profileNameLabel => 'Имя';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileHealthTitle => 'Финансовое здоровье';

  @override
  String get profileHealthError => 'Не удалось рассчитать скоринг';

  @override
  String get profileSignOutTitle => 'Выйти из профиля?';

  @override
  String get profileSignOutMessage =>
      'Данные останутся на устройстве, но приложение вернётся к экрану знакомства.';

  @override
  String profileSectionComingSoon(String section) {
    return '«$section» появится в следующих обновлениях';
  }

  @override
  String a11yThemeOption(String name) {
    return 'Тема: $name';
  }
}
