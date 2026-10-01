import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/backup.dart';
import '../../../domain/models/app_settings.dart';

/// Состояние операций с данными пользователя.
@immutable
class DataManagementState {
  const DataManagementState({
    this.busy = false,
    this.lastExportPath,
    this.error,
  });

  /// Выполняется ли операция экспорта/удаления.
  final bool busy;

  /// Путь к последней сохранённой резервной копии.
  final String? lastExportPath;

  /// Текст последней ошибки.
  final String? error;
}

/// Экспорт и полное удаление данных пользователя.
class DataManagementController extends Notifier<DataManagementState> {
  @override
  DataManagementState build() => const DataManagementState();

  /// Собирает все данные и сохраняет резервную копию в файл.
  Future<bool> exportData() async {
    state = const DataManagementState(busy: true);
    try {
      final operations = await ref.read(operationRepositoryProvider).all();
      final categories = await ref.read(categoryRepositoryProvider).all();
      final rules = await ref.read(categorizationRepositoryProvider).all();
      final settings =
          ref.read(appSettingsProvider).value ?? const AppSettings();
      final now = DateTime.now();
      final json = buildBackupJson(
        operations: operations,
        categories: categories,
        rules: rules,
        settings: settings,
        exportedAt: now,
      );
      final path = await ref
          .read(dataExportStoreProvider)
          .write(backupFileName(now), json);
      state = DataManagementState(lastExportPath: path);
      return true;
    } catch (_) {
      state = const DataManagementState(
        error: 'Не удалось экспортировать данные',
      );
      return false;
    }
  }

  /// Полностью удаляет операции, правила и сбрасывает настройки.
  Future<bool> deleteAllData() async {
    state = const DataManagementState(busy: true);
    try {
      await ref.read(operationRepositoryProvider).deleteAll();
      await ref.read(categorizationRepositoryProvider).deleteAll();
      await ref.read(categoryRepositoryProvider).resetToDefaults();
      await ref.read(appSettingsProvider.notifier).resetToDefaults();
      state = const DataManagementState();
      return true;
    } catch (_) {
      state = const DataManagementState(error: 'Не удалось удалить данные');
      return false;
    }
  }
}

/// Провайдер операций с данными пользователя.
final dataManagementProvider =
    NotifierProvider<DataManagementController, DataManagementState>(
      DataManagementController.new,
    );
