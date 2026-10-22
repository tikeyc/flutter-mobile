import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// 首页底部导航：灵感社区·模型广场·[中央头像按钮]·需求大厅·好物商城。
/// 白底 + 向上阴影，中央按钮上凸 8px；tab 为纯文字。
/// 中央按钮进入 AI 修图页（路由第 5 分支，激活时外壳隐藏本导航）。
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.tabs,
    required this.selected,
    this.onTabSelected,
    this.onCenterTap,
    this.onCenterLongPress,
  });

  /// 顺序：左1、左2、右2、右1（中间头像按钮不计入 index）。
  final List<String> tabs;
  final int selected;
  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onCenterTap;
  final VoidCallback? onCenterLongPress;

  static const double contentHeight = 56;

  @override
  Widget build(BuildContext context) {
    assert(tabs.length == 4, '底部导航固定 4 个文字 tab + 中央按钮');
    return Container(
      // 内容保持 56 高，背景与阴影经 padding 延伸到系统手势条后面。
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: contentHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                _tab(tabs[0], 0),
                _tab(tabs[1], 1),
                const Expanded(child: SizedBox()),
                _tab(tabs[2], 2),
                _tab(tabs[3], 3),
              ],
            ),
            Positioned(top: -8, child: _centerButton()),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int index) {
    final active = index == selected;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTabSelected == null ? null : () => onTabSelected!(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                height: 20 / 16,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.text2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 中央 64px 圆形头像按钮（当前无用户头像数据，用占位）。
  Widget _centerButton() {
    return GestureDetector(
      key: const Key('home-center-button'),
      onTap: onCenterTap,
      onLongPress: onCenterLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: AppColors.bg1,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: CircleAvatar(
          backgroundColor: AppColors.border4,
          // child: Icon(Icons.person, size: 28, color: AppColors.text3),
          child: Image.asset('assets/images/logo/great-sage-ai-logo.png'),
        ),
      ),
    );
  }
}
