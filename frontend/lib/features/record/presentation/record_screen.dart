import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/operation.dart';
import '../../../domain/models/record_state.dart';
import '../../../domain/models/shortcut.dart';
import 'record_controller.dart';
import 'widgets/operation_card.dart';
import 'widgets/operation_edit_sheet.dart';
import 'widgets/pulsing_mic_button.dart';
import 'widgets/transcript_card.dart';
import 'widgets/voice_waveform.dart';

/// Ключевой экран приложения: голос → сохранённая операция.
///
/// [startWithText] открывает экран сразу в режиме ручного ввода,
/// [autoListen] начинает запись без тапа по микрофону — быстрый запуск
/// по deep link: тап по иконке → микрофон уже слушает.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({
    super.key,
    this.startWithText = false,
    this.autoListen = false,
  });

  final bool startWithText;
  final bool autoListen;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoListen || widget.startWithText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = ref.read(recordControllerProvider.notifier);
        if (widget.autoListen) {
          controller.startListening();
        } else {
          controller.startTextInput();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);
    final manualOnly =
        ref.watch(appSettingsProvider).value?.manualOnlyMode ?? false;

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
            child: _buildStage(context, state, controller, manualOnly),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(
    BuildContext context,
    RecordState state,
    RecordController controller,
    bool manualOnly,
  ) {
    switch (state.stage) {
      case RecordStage.idle:
        return _IdleView(
          key: const ValueKey('idle'),
          manualOnly: manualOnly,
          onStart: controller.startListening,
          onWrite: controller.startTextInput,
        );
      case RecordStage.textInput:
        return _TextInputView(
          key: const ValueKey('textInput'),
          manualOnly: manualOnly,
          onSubmit: controller.submitText,
          onCancel: controller.cancelTextInput,
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
          onRefine: controller.refineWithAi,
        );
      case RecordStage.shortcut:
        return _ShortcutView(
          key: const ValueKey('shortcut'),
          result: state.shortcut,
          onDone: controller.reset,
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
          onWrite: controller.startTextInput,
          onUpgrade: state.quotaExceeded
              ? () => context.push(AppRoutes.subscription)
              : null,
        );
    }
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    super.key,
    required this.manualOnly,
    required this.onStart,
    required this.onWrite,
  });

  final bool manualOnly;
  final Future<void> Function() onStart;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            manualOnly ? 'Введите операцию' : 'Скажите, что потратили',
            style: theme.textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            manualOnly
                ? 'Режим «Только ручной ввод»: данные не покидают устройство'
                : 'Например: «такси 400» или «продукты 2300 и кофе 450»',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (!manualOnly) ...[
            PulsingMicButton(onPressed: onStart),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: sona.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 40,
                color: sona.onAccentSoft,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          OutlinedButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.keyboard_rounded, size: 20),
            label: const Text('Написать'),
          ),
        ],
      ),
    );
  }
}

class _TextInputView extends StatefulWidget {
  const _TextInputView({
    super.key,
    required this.manualOnly,
    required this.onSubmit,
    required this.onCancel,
  });

  final bool manualOnly;
  final Future<void> Function(String text) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_TextInputView> createState() => _TextInputViewState();
}

class _TextInputViewState extends State<_TextInputView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Напишите операцию', style: theme.textTheme.displayMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          widget.manualOnly
              ? 'Разбор выполняется локально, без отправки в облако'
              : 'AI разберёт текст так же, как голосовую фразу',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'Например: кофе 450',
            labelText: 'Операция',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _submit,
          child: const Text('Разобрать'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: widget.onCancel,
          child: const Text('Назад'),
        ),
      ],
    );
  }
}

class _ShortcutView extends StatelessWidget {
  const _ShortcutView({super.key, required this.result, required this.onDone});

  final ShortcutResult? result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final shortcut = result;

    if (shortcut == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCancel = shortcut.kind == VoiceShortcutKind.cancel;
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
              isCancel ? Icons.undo_rounded : Icons.account_balance_wallet_rounded,
              size: 48,
              color: sona.onAccentSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(shortcut.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            shortcut.value,
            style: theme.textTheme.displayLarge,
            textAlign: TextAlign.center,
          ),
          if (shortcut.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              shortcut.subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: onDone, child: const Text('Готово')),
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
    required this.onRefine,
  });

  final RecordState state;
  final Future<void> Function() onConfirm;
  final void Function(int index, ParsedOperation operation) onEdit;
  final void Function(int index) onRemove;
  final Future<void> Function() onCancel;
  final Future<void> Function() onRefine;

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
        if (state.localOnly) ...[
          const SizedBox(height: AppSpacing.xs),
          const _LocalBadge(),
        ] else if (state.offline) ...[
          const SizedBox(height: AppSpacing.xs),
          const _OfflineBadge(),
        ] else if (state.fallbackUsed) ...[
          const SizedBox(height: AppSpacing.xs),
          const _FallbackBadge(),
        ],
        if (state.offline && state.canRefineOnline) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : onRefine,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Уточнить через AI'),
          ),
        ],
        if (state.refineError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.refineError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
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

class _LocalBadge extends StatelessWidget {
  const _LocalBadge();

  @override
  Widget build(BuildContext context) {
    final sona = context.sonaColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sona.accentSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: sona.onAccentSoft),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'Локальный разбор',
              style: TextStyle(fontSize: 12, color: sona.onAccentSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final sona = context.sonaColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sona.accentSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 14, color: sona.onAccentSoft),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'Офлайн-разбор',
              style: TextStyle(fontSize: 12, color: sona.onAccentSoft),
            ),
          ],
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
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onWrite,
    this.onUpgrade,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onWrite;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            onUpgrade != null
                ? Icons.workspace_premium_outlined
                : Icons.error_outline_rounded,
            size: 64,
            color: onUpgrade != null ? scheme.primary : scheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            onUpgrade != null ? 'Лимит бесплатных операций' : 'Не получилось',
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
          if (onUpgrade != null) ...[
            FilledButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.workspace_premium_outlined, size: 20),
              label: const Text('Оформить Sona Pro'),
            ),
          ] else ...[
            FilledButton(
              onPressed: onRetry,
              child: const Text('Попробовать снова'),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.keyboard_rounded, size: 20),
            label: const Text('Ввести текстом'),
          ),
        ],
      ),
    );
  }
}
