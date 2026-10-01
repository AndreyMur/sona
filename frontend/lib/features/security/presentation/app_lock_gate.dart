import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models/app_settings.dart';
import 'app_lock_controller.dart';
import 'lock_screen.dart';

/// Оборачивает приложение и показывает экран блокировки поверх содержимого.
///
/// Отслеживает жизненный цикл: при уходе в фон приложение запирается сразу
/// (если автоблокировка выставлена в 0 секунд) либо после заданной задержки
/// при возврате.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int get _autoLockSeconds =>
      ref.read(appSettingsProvider).value?.autoLockSeconds ??
      kDefaultAutoLockSeconds;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider);
    if (!lock.enabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      if (_autoLockSeconds == kLockImmediatelySeconds) {
        ref.read(appLockProvider.notifier).lock();
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final backgrounded = DateTime.now().difference(pausedAt).inSeconds;
      if (backgrounded >= _autoLockSeconds) {
        ref.read(appLockProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider.select((state) => state.locked));
    return Stack(
      children: [
        widget.child,
        if (locked) const LockScreen(),
      ],
    );
  }
}
