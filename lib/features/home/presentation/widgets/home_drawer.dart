import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/router/app_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// 首页左侧抽屉菜单。
/// 占位内容：头像区 + 菜单项，后续按设计稿替换真实入口与数据。
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  static const List<(IconData, String)> _items = [
    (Icons.person_outline, '我的主页'),
    (Icons.notifications_none, '消息通知'),
    (Icons.settings_outlined, '设置'),
    (Icons.logout, '退出登录'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bg1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const Divider(height: 1, thickness: 1, color: AppColors.border4),
            for (final (icon, label) in _items)
              Consumer(
                builder: (context, ref, child) {
                  return ListTile(
                    leading: Icon(icon, size: 22, color: AppColors.text2),
                    title: Text(label, style: AppTextStyles.body14),
                    onTap: () => {
                      if (label == '退出登录')
                        {
                          if (ref.read(authProvider) != null)
                            {ref.read(authProvider.notifier).signOut()}
                          else
                            {GoRouter.of(context).push(AppRoutes.login)},
                        }
                      else
                        {Navigator.of(context).pop()},
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 顶部头像区（占位）。
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.border4,
            child: Icon(Icons.person, size: 28, color: AppColors.text4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('用户昵称', style: AppTextStyles.title16),
                const SizedBox(height: 2),
                Text(
                  '查看并编辑个人资料',
                  style: AppTextStyles.body12.copyWith(color: AppColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
