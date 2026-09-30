import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/budget_alerts.dart';
import 'package:sona/core/utils/budget_math.dart';

void main() {
  group('идентификаторы уведомлений', () {
    test('классы id лежат в разных интервалах', () {
      final ids = {
        BudgetAlerts.idThreshold(50),
        BudgetAlerts.idThreshold(80),
        BudgetAlerts.idThreshold(100),
        BudgetAlerts.idOverBudget,
        BudgetAlerts.idAnomaly,
        BudgetAlerts.idWeeklyReport,
        BudgetAlerts.idDailyReminder,
      };
      expect(ids.length, 7);
    });

    test('id лимита стабилен для одного ключа', () {
      expect(
        BudgetAlerts.idForCategory('Продукты'),
        BudgetAlerts.idForCategory('Продукты'),
      );
    });
  });

  group('тексты уведомлений', () {
    test('порог и превышение содержат суммы', () {
      expect(BudgetAlerts.thresholdTitle(80), 'Использовано 80% бюджета');
      expect(
        BudgetAlerts.thresholdBody(25000, 30000, '₽'),
        'Потрачено 25 000 ₽ из 30 000 ₽.',
      );
      expect(
        BudgetAlerts.overBudgetBody(31000, 30000, '₽'),
        'Расходы 31 000 ₽ превысили бюджет 30 000 ₽.',
      );
    });

    test('аномалия объясняет, во сколько раз выше среднего', () {
      expect(
        BudgetAlerts.anomalyBody(3000, 1000, '₽'),
        'Сегодня 3 000 ₽ — примерно вдвое больше обычного (~1 000 ₽ в день).',
      );
    });

    test('еженедельный отчёт содержит доходы и расходы', () {
      expect(
        BudgetAlerts.weeklyReportBody(12000, 4300, '₽'),
        'Доходы: 12 000 ₽ · Расходы: 4 300 ₽.',
      );
    });

    test('лимиты категорий называют ключ', () {
      expect(
        BudgetAlerts.categoryThresholdTitle('Продукты', 50),
        '«Продукты»: использовано 50% лимита',
      );
      expect(
        BudgetAlerts.categoryOverTitle('Продукты::Супермаркет'),
        'Лимит «Продукты::Супермаркет» превышен',
      );
    });
  });

  group('маркеры и извлечение уведомлённых порогов', () {
    test('общие пороги извлекаются по месяцу', () {
      final markers = {
        BudgetAlerts.markerThreshold('2026-09', 50),
        BudgetAlerts.markerThreshold('2026-09', 80),
        BudgetAlerts.markerThreshold('2026-10', 50),
      };
      expect(BudgetAlerts.notifiedThresholds(markers, '2026-09'), [50, 80]);
      expect(BudgetAlerts.notifiedThresholds(markers, '2026-10'), [50]);
      expect(BudgetAlerts.notifiedThresholds(markers, '2026-11'), isEmpty);
    });

    test('пороги лимитов извлекаются по ключу', () {
      final markers = {
        BudgetAlerts.markerCategoryThreshold('2026-09', 'Продукты', 50),
        BudgetAlerts.markerCategoryThreshold(
          '2026-09',
          'Продукты::Супермаркет',
          80,
        ),
      };
      expect(
        BudgetAlerts.categoryNotifiedThresholds(
          markers,
          '2026-09',
          'Продукты',
        ),
        [50],
      );
      expect(
        BudgetAlerts.categoryNotifiedThresholds(
          markers,
          '2026-09',
          'Продукты::Супермаркет',
        ),
        [80],
      );
    });

    test('прочие маркеры строятся детерминированно', () {
      expect(BudgetAlerts.markerOver('2026-09'), 'over:2026-09');
      expect(BudgetAlerts.markerAnomaly('2026-09-30'), 'anomaly:2026-09-30');
      expect(BudgetAlerts.markerWeekly('2026-09-28'), 'weekly:2026-09-28');
    });

    test('не видимые пороги по маркерам совпадают с математикой', () {
      const markers = ['thr:2026-09:50'];
      final reached = BudgetMath.reachedThresholds(25000, 30000, [50, 80, 100]);
      expect(
        BudgetMath.unseenThresholds(
          reached,
          BudgetAlerts.notifiedThresholds(markers, '2026-09'),
        ),
        [80],
      );
    });

    test('ключ месяца согласован с monthKey', () {
      expect(
        BudgetAlerts.notifiedThresholds(
          {BudgetAlerts.markerThreshold(BudgetMath.monthKey(DateTime(2026, 9, 30)), 50)},
          '2026-09',
        ),
        [50],
      );
    });
  });
}
