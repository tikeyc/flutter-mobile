import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../auth/application/auth_providers.dart';
import 'presentation/widgets/home_bottom_nav.dart';
import 'presentation/widgets/home_drawer.dart';

/// 外壳抽屉作用域：分支页面经它打开挂在外壳 Scaffold 上的全屏抽屉。
class HomeShellDrawer extends InheritedWidget {
  const HomeShellDrawer({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static HomeShellDrawer? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellDrawer>();

  @override
  bool updateShouldNotify(HomeShellDrawer oldWidget) => false;
}

/// 首页外壳：StatefulShellRoute 宿主，承载底部导航与全屏抽屉。
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bottomTabs = ['灵感社区', '模型广场', '需求大厅', '好物商城'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeShellDrawer(
      openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.bg2,
        drawer: const HomeDrawer(),
        body: navigationShell,
        bottomNavigationBar: HomeBottomNav(
          tabs: _bottomTabs,
          selected: navigationShell.currentIndex,
          onTabSelected: (i) => navigationShell.goBranch(
            i,
            // 重复点当前 tab：回到该分支根页面。
            initialLocation: i == navigationShell.currentIndex,
          ),
          // 调试期临时：长按中央按钮退出登录（正式「我的」页完成后移除）。
          onCenterTap: () => ref.read(authProvider.notifier).signOut(),
        ),
      ),
    );
  }
}
