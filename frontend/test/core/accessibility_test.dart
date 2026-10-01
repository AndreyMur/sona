import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/core/widgets/sona_waveform.dart';
import 'package:sona/features/budget/presentation/widgets/donut_chart.dart';
import 'package:sona/features/record/presentation/widgets/pulsing_mic_button.dart';
import 'package:sona/features/settings/presentation/appearance_screen.dart';
import 'package:sona/l10n/l10n.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('волновая анимация озвучивается для скринридера', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SonaWaveform(semanticLabel: 'Идёт запись')),
      ),
    );

    final semantics = tester.getSemantics(find.byType(SonaWaveform));
    expect(semantics.label, contains('Идёт запись'));

    handle.dispose();
  });

  testWidgets('кнопка микрофона помечена как кнопка с подписью', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PulsingMicButton(
            label: 'Сказать — записать операцию',
            onPressed: () {},
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PulsingMicButton));
    expect(semantics.label, contains('Сказать'));
    expect(semantics.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('пончик-диаграмма описывает срезы', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DonutChart(
            slices: [
              DonutSlice(label: 'Продукты', value: 75, color: Colors.green),
              DonutSlice(label: 'Транспорт', value: 25, color: Colors.blue),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(DonutChart));
    expect(semantics.label, contains('Продукты 75%'));
    expect(semantics.label, contains('Транспорт 25%'));

    handle.dispose();
  });

  testWidgets('экран выдерживает увеличенный системный шрифт', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(FakeAppSettingsStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
