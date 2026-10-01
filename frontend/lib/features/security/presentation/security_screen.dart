import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pin_hasher.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/app_settings.dart';
import 'app_lock_controller.dart';

/// Варианты задержки автоблокировки.
const List<({int seconds, String label})> kAutoLockOptions = [
  (seconds: 0, label: 'Сразу при сворачивании'),
  (seconds: 30, label: 'Через 30 секунд'),
  (seconds: 60, label: 'Через 1 минуту'),
  (seconds: 300, label: 'Через 5 минут'),
];

/// Экран безопасности: защита входа, PIN, биометрия и автоблокировка.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final lock = ref.watch(appLockProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final autoLockSeconds =
        settings?.autoLockSeconds ?? kDefaultAutoLockSeconds;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Безопасность')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.lock_outline_rounded,
                    color: sona.onAccentSoft,
                  ),
                  title: Text('Защита входа', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'PIN-код и биометрия при открытии приложения',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: lock.enabled,
                  onChanged: (value) => _toggleLock(context, ref, value),
                ),
                if (lock.enabled) ...[
                  const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
                  ListTile(
                    leading: Icon(
                      Icons.pin_outlined,
                      color: sona.onAccentSoft,
                    ),
                    title: const Text('Изменить PIN'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _changePin(context, ref),
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.fingerprint_rounded,
                      color: sona.onAccentSoft,
                    ),
                    title: const Text('Вход по биометрии'),
                    subtitle: const Text('Face ID / Touch ID / отпечаток'),
                    value: lock.biometricEnabled,
                    onChanged: (value) =>
                        _setBiometric(context, ref, value),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: sona.onAccentSoft,
                    ),
                    title: const Text('Автоблокировка'),
                    subtitle: Text(_autoLockLabel(autoLockSeconds)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _pickAutoLock(context, ref, autoLockSeconds),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.cloud_off_rounded,
                color: sona.onAccentSoft,
              ),
              title: Text(
                'Только ручной ввод',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                'Голосовой ввод отключён, данные не отправляются в облако',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: settings?.manualOnlyMode ?? false,
              onChanged: (value) => ref
                  .read(appSettingsProvider.notifier)
                  .setManualOnlyMode(value),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Данные хранятся локально с шифрованием. PIN и биометрия '
            'защищают доступ к приложению, если телефоном воспользуется '
            'кто-то другой.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (lock.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lock.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _autoLockLabel(int seconds) {
    for (final option in kAutoLockOptions) {
      if (option.seconds == seconds) return option.label;
    }
    return 'Через $seconds секунд';
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final controller = ref.read(appLockProvider.notifier);
    if (value) {
      final pin = await showPinSetupDialog(context);
      if (pin == null) return;
      await controller.enableWithPin(pin);
    } else {
      final confirmed = await _confirm(
        context,
        title: 'Выключить защиту?',
        message: 'PIN и биометрия перестанут запрашиваться при входе.',
        confirmLabel: 'Выключить',
      );
      if (confirmed) await controller.disable();
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final pin = await showPinSetupDialog(context, title: 'Новый PIN');
    if (pin == null) return;
    await ref.read(appLockProvider.notifier).changePin(pin);
  }

  Future<void> _setBiometric(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    await ref.read(appLockProvider.notifier).setBiometric(value);
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in kAutoLockOptions)
              ListTile(
                title: Text(option.label),
                trailing: option.seconds == current
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.seconds),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(appLockProvider.notifier).setAutoLockSeconds(selected);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Диалог установки PIN-кода с подтверждением.
Future<String?> showPinSetupDialog(
  BuildContext context, {
  String title = 'Защита входа',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PinSetupDialog(title: title),
  );
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.title});

  final String title;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pin.text;
    if (!PinHasher.isValid(pin)) {
      setState(() => _error = 'PIN должен состоять из 4 цифр');
      return;
    }
    if (pin != _confirm.text) {
      setState(() => _error = 'PIN-коды не совпадают');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PIN запрашивается при каждом открытии приложения.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _pinField(_pin, 'Новый PIN'),
          const SizedBox(height: AppSpacing.sm),
          _pinField(_confirm, 'Повторите PIN'),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _pinField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      autofocus: label.startsWith('Новый'),
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: PinHasher.pinLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}
