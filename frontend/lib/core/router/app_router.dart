import 'package:go_router/go_router.dart';

import '../../features/categories/presentation/categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/record/presentation/record_screen.dart';

/// Маршруты приложения.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String record = '/record';
  static const String categories = '/categories';
}

/// Конфигурация навигации.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.record,
        builder: (context, state) => const RecordScreen(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
    ],
  );
}
