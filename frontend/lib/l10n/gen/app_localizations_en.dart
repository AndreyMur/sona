// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sona';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceThemeSection => 'Theme';

  @override
  String get appearanceThemeHint =>
      'The theme applies to the whole app. \"System\" follows your device setting.';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeSystemDescription => 'Follows the system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeLightDescription => 'Always light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeDarkDescription => 'Always dark';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSections => 'Sections';

  @override
  String get profileData => 'Data';

  @override
  String get profileDataSubtitle => 'Export and delete';

  @override
  String get profileAccounts => 'Accounts';

  @override
  String get profileCategories => 'Categories';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileSecurity => 'Security';

  @override
  String get profileSecurityOn => 'Protection on';

  @override
  String get profileSecurityOff => 'PIN and biometrics';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileAppearanceSubtitle => 'Light, dark, system';

  @override
  String get profileSubscription => 'Subscription';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileNoName => 'No name';

  @override
  String get profileAddEmail => 'Add email';

  @override
  String get profileEditTitle => 'Profile';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileHealthTitle => 'Financial health';

  @override
  String get profileHealthError => 'Could not compute the score';

  @override
  String get profileSignOutTitle => 'Sign out?';

  @override
  String get profileSignOutMessage =>
      'Your data stays on the device, but the app returns to onboarding.';

  @override
  String profileSectionComingSoon(String section) {
    return '\"$section\" is coming in a future update';
  }

  @override
  String a11yThemeOption(String name) {
    return 'Theme: $name';
  }
}
