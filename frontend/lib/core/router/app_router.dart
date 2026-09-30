import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/app_settings.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/loading_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/record/presentation/record_screen.dart';

/// Маршруты приложения.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String record = '/record';
  static const String categories = '/categories';
  static const String onboarding = '/onboarding';

  /// Служебный экран: показывается, пока настройки ещё загружаются.
  static const String loading = '/loading';
}

/// Навигация: гейт онбординга и переключение после его прохождения.
final routerProvider = Provider<GoRouter>((ref) {
  final completed = ValueNotifier<bool?>(null);
  void sync(AsyncValue<AppSettings> value) {
    if (value.hasValue) completed.value = value.value!.onboardingCompleted;
  }

  sync(ref.read(appSettingsProvider));
  ref.listen(appSettingsProvider, (_, next) => sync(next));
  ref.onDispose(completed.dispose);

  return buildRouter(
    onboardingCompleted: () => completed.value,
    refreshListenable: completed,
  );
});

/// Конфигурация навигации.
///
/// Пока онбординг не пройден, все маршруты ведут на `/onboarding`;
/// после прохождения — обратно на главную.
GoRouter buildRouter({
  required bool? Function() onboardingCompleted,
  Listenable? refreshListenable,
}) {
  String? redirectGate(GoRouterState state) {
    final completed = onboardingCompleted();
    final location = state.matchedLocation;

    if (completed == null) {
      return location == AppRoutes.loading ? null : AppRoutes.loading;
    }
    if (location == AppRoutes.loading) {
      return completed ? AppRoutes.home : AppRoutes.onboarding;
    }
    final atOnboarding = location == AppRoutes.onboarding;
    if (!completed && !atOnboarding) return AppRoutes.onboarding;
    if (completed && atOnboarding) return AppRoutes.home;
    return null;
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: (context, state) => redirectGate(state),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.record,
        builder: (context, state) => RecordScreen(
          startWithText: state.uri.queryParameters['mode'] == 'text',
        ),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
    ],
  );
}
