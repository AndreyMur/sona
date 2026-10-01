import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Sona'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @appearanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get appearanceTitle;

  /// No description provided for @appearanceThemeSection.
  ///
  /// In ru, this message translates to:
  /// **'Тема оформления'**
  String get appearanceThemeSection;

  /// No description provided for @appearanceThemeHint.
  ///
  /// In ru, this message translates to:
  /// **'Тема применяется ко всему приложению. «Системная» повторяет настройку устройства.'**
  String get appearanceThemeHint;

  /// No description provided for @themeModeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeModeSystem;

  /// No description provided for @themeModeSystemDescription.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeModeSystemDescription;

  /// No description provided for @themeModeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeModeLight;

  /// No description provided for @themeModeLightDescription.
  ///
  /// In ru, this message translates to:
  /// **'Всегда светлое оформление'**
  String get themeModeLightDescription;

  /// No description provided for @themeModeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeModeDark;

  /// No description provided for @themeModeDarkDescription.
  ///
  /// In ru, this message translates to:
  /// **'Всегда тёмное оформление'**
  String get themeModeDarkDescription;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @profileSections.
  ///
  /// In ru, this message translates to:
  /// **'Разделы'**
  String get profileSections;

  /// No description provided for @profileData.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get profileData;

  /// No description provided for @profileDataSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт и удаление'**
  String get profileDataSubtitle;

  /// No description provided for @profileAccounts.
  ///
  /// In ru, this message translates to:
  /// **'Счета'**
  String get profileAccounts;

  /// No description provided for @profileCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get profileCategories;

  /// No description provided for @profileNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get profileNotifications;

  /// No description provided for @profileSecurity.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get profileSecurity;

  /// No description provided for @profileSecurityOn.
  ///
  /// In ru, this message translates to:
  /// **'Защита включена'**
  String get profileSecurityOn;

  /// No description provided for @profileSecurityOff.
  ///
  /// In ru, this message translates to:
  /// **'PIN и биометрия'**
  String get profileSecurityOff;

  /// No description provided for @profileAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get profileAppearance;

  /// No description provided for @profileAppearanceSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Светлая, тёмная, системная'**
  String get profileAppearanceSubtitle;

  /// No description provided for @profileSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Подписка'**
  String get profileSubscription;

  /// No description provided for @profileSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get profileSignOut;

  /// No description provided for @profileNoName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get profileNoName;

  /// No description provided for @profileAddEmail.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте email'**
  String get profileAddEmail;

  /// No description provided for @profileEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileEditTitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get profileNameLabel;

  /// No description provided for @profileEmailLabel.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profileHealthTitle.
  ///
  /// In ru, this message translates to:
  /// **'Финансовое здоровье'**
  String get profileHealthTitle;

  /// No description provided for @profileHealthError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось рассчитать скоринг'**
  String get profileHealthError;

  /// No description provided for @profileSignOutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из профиля?'**
  String get profileSignOutTitle;

  /// No description provided for @profileSignOutMessage.
  ///
  /// In ru, this message translates to:
  /// **'Данные останутся на устройстве, но приложение вернётся к экрану знакомства.'**
  String get profileSignOutMessage;

  /// No description provided for @profileSectionComingSoon.
  ///
  /// In ru, this message translates to:
  /// **'«{section}» появится в следующих обновлениях'**
  String profileSectionComingSoon(String section);

  /// No description provided for @a11yThemeOption.
  ///
  /// In ru, this message translates to:
  /// **'Тема: {name}'**
  String a11yThemeOption(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
