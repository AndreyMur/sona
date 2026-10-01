import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pin_hasher.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import 'app_lock_controller.dart';

/// Экран разблокировки приложения: PIN-код и вход по биометрии.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  bool _biometricTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    if (!mounted || _biometricTried) return;
    final state = ref.read(appLockProvider);
    if (!state.biometricEnabled) return;
    _biometricTried = true;
    await ref.read(appLockProvider.notifier).unlockWithBiometrics();
  }

  void _append(String digit) {
    if (_entered.length >= PinHasher.pinLength) return;
    ref.read(appLockProvider.notifier).clearError();
    setState(() => _entered += digit);
    if (_entered.length == PinHasher.pinLength) {
      _submit();
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    ref.read(appLockProvider.notifier).clearError();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    final pin = _entered;
    final ok = await ref.read(appLockProvider.notifier).unlockWithPin(pin);
    if (!mounted) return;
    if (!ok) setState(() => _entered = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final state = ref.watch(appLockProvider);

    return GradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: sona.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 44,
                  color: sona.onAccentSoft,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Введите PIN', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sona защищена от посторонних',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PinDots(filled: _entered.length, error: state.error != null),
              SizedBox(
                height: AppSpacing.lg,
                child: state.error == null
                    ? null
                    : Center(
                        child: Text(
                          state.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              _PinPad(onDigit: _append, onBackspace: _backspace),
              const SizedBox(height: AppSpacing.md),
              if (state.biometricEnabled)
                TextButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => ref
                            .read(appLockProvider.notifier)
                            .unlockWithBiometrics(),
                  icon: const Icon(Icons.fingerprint_rounded, size: 22),
                  label: const Text('Войти по биометрии'),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Индикатор введённых цифр PIN.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < PinHasher.pinLength; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// Цифровая клавиатура PIN-кода.
class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row)
                _PinKey(
                  label: key,
                  onTap: key.isEmpty
                      ? null
                      : key == 'back'
                      ? onBackspace
                      : () => onDigit(key),
                ),
            ],
          ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (label.isEmpty) {
      return const SizedBox(width: 80, height: 68);
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: SizedBox(
        width: 72,
        height: 60,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Center(
              child: label == 'back'
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 24,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : Text(label, style: theme.textTheme.headlineSmall),
            ),
          ),
        ),
      ),
    );
  }
}
