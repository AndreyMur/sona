import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/l10n/l10n.dart';

void main() {
  test('поддерживается русская локаль', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('ru')));
  });

  test('русская локализация содержит ожидаемые строки', () async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(ru.appTitle, 'Sona');
    expect(ru.profileTitle, 'Профиль');
    expect(ru.appearanceTitle, 'Внешний вид');
    expect(ru.themeModeDark, 'Тёмная');
    expect(ru.commonCancel, 'Отмена');
  });

  test('подстановка параметра в строку', () async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(ru.profileSectionComingSoon('Счета'), contains('Счета'));
  });

  testWidgets('context.l10n отдаёт строки для ru', (tester) async {
    late String title;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            title = context.l10n.profileTitle;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(title, 'Профиль');
  });
}
