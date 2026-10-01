import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/performance/app_performance.dart';

void main() {
  group('AppPerformanceBudget', () {
    test('бюджеты соответствуют ТЗ', () {
      expect(AppPerformanceBudget.startup, const Duration(milliseconds: 1500));
      expect(AppPerformanceBudget.maxAppSizeBytes, 60 * 1024 * 1024);
    });
  });

  group('StartupMetrics', () {
    tearDown(StartupMetrics.reset);

    test('запуск в пределах бюджета', () {
      expect(
        StartupMetrics.isWithinBudget(const Duration(milliseconds: 1499)),
        isTrue,
      );
    });

    test('превышение бюджета фиксируется', () {
      expect(
        StartupMetrics.isWithinBudget(const Duration(milliseconds: 1501)),
        isFalse,
      );
    });

    test('до первого кадра бюджет не нарушен', () {
      StartupMetrics.reset();
      expect(StartupMetrics.firstFrame, isNull);
      expect(StartupMetrics.withinBudget, isTrue);
    });

    test('фиксирует первый кадр после старта', () async {
      StartupMetrics.reset();
      StartupMetrics.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      StartupMetrics.markFirstFrame();
      expect(StartupMetrics.firstFrame, isNotNull);
      expect(StartupMetrics.withinBudget, isTrue);
    });
  });
}
