import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/domain/models/theme_mode.dart';
import 'package:sona/features/settings/presentation/appearance_screen.dart';
import 'package:sona/l10n/l10n.dart';

import '../support/fakes.dart';

void main() {
  Future<FakeAppSettingsStore> pumpAppearance(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final store = FakeAppSettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider).materialThemeMode;
            return MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              locale: const Locale('ru'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const AppearanceScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('показывает три режима темы с пояснениями', (tester) async {
    await pumpAppearance(tester);

    expect(find.text('Внешний вид'), findsOneWidget);
    expect(find.text('Системная'), findsOneWidget);
    expect(find.text('Светлая'), findsOneWidget);
    expect(find.text('Тёмная'), findsOneWidget);
    expect(find.text('Как в системе'), findsOneWidget);
  });

  testWidgets('выбор темы сохраняется в настройках', (tester) async {
    final store = await pumpAppearance(tester);

    expect(store.settings.themeMode, SonaThemeMode.system);

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();

    expect(store.settings.themeMode, SonaThemeMode.dark);
  });

  testWidgets('выбор темы применяется к MaterialApp', (tester) async {
    await pumpAppearance(tester);

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('отмечает выбранный режим отметкой', (tester) async {
    await pumpAppearance(tester);

    await tester.tap(find.text('Светлая'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
