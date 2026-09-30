import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/operation.dart';
import '../../../domain/models/record_state.dart';
import 'record_controller.dart';
import 'widgets/operation_card.dart';
import 'widgets/operation_edit_sheet.dart';
import 'widgets/pulsing_mic_button.dart';
import 'widgets/transcript_card.dart';
import 'widgets/voice_waveform.dart';

/// Ключевой экран приложения: голос → сохранённая операция.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Запись'),
        leading: state.stage == RecordStage.listening
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Закрыть',
                onPressed: () {
                  controller.reset();
                  Navigator.of(context).maybePop();
                },
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildStage(context, state, controller),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(
    BuildContext context,
    RecordState state,
    RecordController controller,
  ) {
    switch (state.stage) {
      case RecordStage.idle:
        return _IdleView(
          key: const ValueKey('idle'),
          onStart: controller.startListening,
        );
      case RecordStage.listening:
        return _ListeningView(
          key: const ValueKey('listening'),
          elapsed: state.elapsed,
          onStop: controller.stopAndProcess,
          onCancel: controller.discard,
        );
      case RecordStage.recognized:
        return _RecognizedView(
          key: const ValueKey('recognized'),
          state: state,
        );
      case RecordStage.parsed:
        return _ParsedView(
          key: const ValueKey('parsed'),
          state: state,
          onConfirm: controller.confirm,
          onEdit: (index, operation) => controller.updateOperation(index, operation),
          onRemove: controller.removeOperation,
          onCancel: controller.discard,
        );
      case RecordStage.saved:
        return _SavedView(
          key: const ValueKey('saved'),
          count: state.savedCount,
          duration: state.processingDuration,
          onDone: controller.reset,
        );
      case RecordStage.error:
        return _ErrorView(
          key: const ValueKey('error'),
          message: state.errorMessage,
          onRetry: controller.reset,
        );
    }
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({super.key, required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Скажите, что потратили',
            style: theme.textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Например: «такси 400» или «продукты 2300 и кофе 450»',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          PulsingMicButton(onPressed: onStart),
        ],
      ),
    );
  }
}

class _ListeningView extends StatelessWidget {
  const _ListeningView({
    super.key,
    required this.elapsed,
    required this.onStop,
    required this.onCancel,
  });

  final Duration elapsed;
  final Future<void> Function() onStop;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        const Spacer(),
        Text(
          'Слушаю…',
          style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.lg),
        VoiceWaveform(height: 96),
        const SizedBox(height: AppSpacing.lg),
        Text(
          SonaFormat.timer(elapsed),
          style: theme.textTheme.displayMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Остановить запись',
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              minimumSize: const Size(88, 88),
              shape: const CircleBorder(),
            ),
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, size: 36),
            label: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: onCancel,
          child: const Text('Отменить'),
        ),
      ],
    );
  }
}

class _RecognizedView extends StatelessWidget {
  const _RecognizedView({super.key, required this.state});

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transcript = state.transcript;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (transcript != null) TranscriptCard(text: transcript),
        const SizedBox(height: AppSpacing.lg),
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(
          transcript == null ? 'Распознаю речь…' : 'Разбираю на операции…',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ParsedView extends StatelessWidget {
  const _ParsedView({
    super.key,
    required this.state,
    required this.onConfirm,
    required this.onEdit,
    required this.onRemove,
    required this.onCancel,
  });

  final RecordState state;
  final Future<void> Function() onConfirm;
  final void Function(int index, ParsedOperation operation) onEdit;
  final void Function(int index) onRemove;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final operations = state.operations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Разобрал', style: theme.textTheme.displayMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          operations.length == 1
              ? 'Проверьте операцию перед сохранением'
              : 'Проверьте ${operations.length} операции перед сохранением',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.fallbackUsed) ...[
          const SizedBox(height: AppSpacing.xs),
          const _FallbackBadge(),
        ],
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView.separated(
            itemCount: operations.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => OperationCard(
              operation: operations[index],
              index: index,
              onEdit: () async {
                final updated = await showOperationEditSheet(
                  context,
                  operation: operations[index],
                );
                if (updated != null) onEdit(index, updated);
              },
              onRemove: () => onRemove(index),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: state.isBusy ? null : onConfirm,
          child: const Text('Подтвердить'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: state.isBusy ? null : onCancel,
          child: const Text('Отменить'),
        ),
      ],
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge();

  @override
  Widget build(BuildContext context) {
    final sona = context.sonaColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sona.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Резервный разбор',
          style: TextStyle(fontSize: 12, color: sona.warning),
        ),
      ),
    );
  }
}

class _SavedView extends StatelessWidget {
  const _SavedView({
    super.key,
    required this.count,
    required this.duration,
    required this.onDone,
  });

  final int count;
  final Duration? duration;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: sona.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 52,
              color: sona.onAccentSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Сохранено', style: theme.textTheme.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == 1 ? '1 операция записана' : '$count операции записано',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (duration != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Обработано за ${(duration!.inMilliseconds / 1000).toStringAsFixed(1)} с',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: onDone, child: const Text('Готово')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: scheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Не получилось',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message ?? 'Попробуйте ещё раз.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: onRetry, child: const Text('Попробовать снова')),
        ],
      ),
    );
  }
}
