import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';

/// 首页顶部导航栏：菜单 | 搜索 | 话题·活动·灵感·热门 Tab | 发布 | 更多。
/// 设计稿 375 宽下 Tab 容器居中、图标贴左右边距 12。
class HomeNavBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeNavBar({
    super.key,
    required this.tabs,
    required this.selected,
    this.onMenu,
    this.onTabSelected,
    this.onSearch,
    this.onMore,
    this.onPublish,
  });

  final List<String> tabs;
  final int selected;
  final VoidCallback? onMenu;
  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onSearch;
  final VoidCallback? onMore;
  final VoidCallback? onPublish;

  static const double height = 44;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg1,
      // Scaffold 只预留状态栏高度，内容需自行下移避开状态栏。
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            const SizedBox(width: 12),
            _menuButton(onTap: onMenu),
            const SizedBox(width: 6),
            _icon(AppIcons.search, onTap: onSearch),
            Expanded(child: Center(child: _tabs())),
            _icon(AppIcons.publish, onTap: onPublish),
            const SizedBox(width: 6),
            _icon(AppIcons.menuMore, onTap: onMore),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  /// 左上角汉堡按钮，点击打开抽屉。尺寸与 [_icon] 保持一致。
  Widget _menuButton({VoidCallback? onTap}) => IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        iconSize: 24,
        onPressed: onTap,
        icon: const SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(Icons.menu, size: 20, color: AppColors.text1),
          ),
        ),
      );

  Widget _icon(String asset, {VoidCallback? onTap}) => IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        iconSize: 24,
        onPressed: onTap,
        icon: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: SvgPicture.asset(asset, width: 18, height: 18)),
        ),
      );

  Widget _tabs() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabItem(
              label: tabs[i],
              selected: i == selected,
              onTap: onTabSelected == null ? null : () => onTabSelected!(i),
            ),
        ],
      );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : AppColors.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(minHeight: HomeNavBar.height),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  height: 20 / 18,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
            if (selected)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(175),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
