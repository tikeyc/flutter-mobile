import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/home_page.dart';

class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/home';
}

/// 路由守卫：未登录只能在 /login；已登录访问 /login 或根路径时去 /home。
String? resolveRedirect({required bool loggedIn, required String location}) {
  final atLogin = location == AppRoutes.login;
  if (!loggedIn) return atLogin ? null : AppRoutes.login;
  if (atLogin || location == '/') return AppRoutes.home;
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // 会话变化时通知 GoRouter 重新执行 redirect。
  final refresh = ValueNotifier<bool>(ref.read(authProvider) != null);
  ref.listen(authProvider, (_, next) => refresh.value = next != null);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      loggedIn: ref.read(authProvider) != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
