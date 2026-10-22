import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/demand_hall/demand_hall_page.dart';
import '../features/editor/presentation/editor_page.dart';
import '../features/home/feed_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/home/inspiration_page.dart';
import '../features/mall/mall_page.dart';
import '../features/model_plaza/model_plaza_page.dart';

class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/home';
  static const modelPlaza = '/model-plaza';
  static const demandHall = '/demand-hall';
  static const mall = '/mall';

  /// AI 修图页（底部导航中央按钮进入，第 5 个分支）。
  static const editor = '/editor';

  /// 内容详情（顶层路由，盖住底部导航）。
  static String feedDetail(String bizId) => '${AppRoutes.home}/feed/$bizId';
}

/// 路由守卫：已登录访问 /login 或根路径时去 /home；游客可浏览全部公开页面，
/// 也可停留在 /login（登录入口），仅根路径去 /home。
String? resolveRedirect({required bool loggedIn, required String location}) {
  final atLogin = location == AppRoutes.login;
  final atRoot = location == '/';
  if (loggedIn) {
    return atLogin || atRoot ? AppRoutes.home : null;
  }
  return atRoot ? AppRoutes.home : null;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> sectionANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionANav');

final appRouterProvider = Provider<GoRouter>((ref) {
  // 会话变化时通知 GoRouter 重新执行 redirect。
  final refresh = ValueNotifier<bool>(ref.read(authProvider) != null);
  ref.listen(authProvider, (_, next) => refresh.value = next != null);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      loggedIn: ref.read(authProvider) != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      // 有状态嵌套导航：各分支 Navigator 常驻，切 tab 与分支内跳转均保状态。
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell navigationShell) =>
            HomePage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: sectionANavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const InspirationPage(),
                routes: [
                  GoRoute(
                    // 子页面想要全屏显示(盖住底部导航栏):给该路由设置 parentNavigatorKey: _rootNavigatorKey,
                    // 它会渲染到根 Navigator 上,而不在 shell 分支里;
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'feed/:bizId',
                    builder: (_, state) =>
                        FeedDetailPage(bizId: state.pathParameters['bizId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.modelPlaza,
                builder: (_, _) => const ModelPlazaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.demandHall,
                builder: (_, _) => const DemandHallPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.mall,
                builder: (_, _) => const MallPage(),
              ),
            ],
          ),
          // 第 5 个分支：AI 修图页（底部导航中央按钮，index 4）。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.editor,
                builder: (context, _) => EditorPage(
                  onClose: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
