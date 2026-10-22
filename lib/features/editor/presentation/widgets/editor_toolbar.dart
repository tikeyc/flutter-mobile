import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_providers.dart';

/// 编辑器底部工具栏：涂抹/智能点选/自动抠图/橡皮擦 + 撤销/重做/重置。
/// 白底 + 向上阴影，风格同首页底部导航。
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    this.onUndo,
    this.onRedo,
    this.onReset,
  });

  final EditorTool selectedTool;
  final ValueChanged<EditorTool> onToolSelected;

  /// 撤销/重做/重置为预留回调，后续由 flutter_fabric 涂鸦历史栈接管。
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onReset;

  static const double contentHeight = 56;

  /// 顺序即展示顺序：(工具, 图标, 文案)。
  static const List<({EditorTool tool, IconData icon, String label})> _tools = [
    (tool: EditorTool.brush, icon: Icons.edit, label: '涂抹'),
    (tool: EditorTool.smartSelect, icon: Icons.auto_fix_high, label: '智能点选'),
    (tool: EditorTool.autoCutout, icon: Icons.crop, label: '自动抠图'),
    (tool: EditorTool.eraser, icon: Icons.cleaning_services, label: '橡皮擦'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Row(
          children: [
            for (final item in _tools)
              Expanded(child: _toolItem(item.tool, item.icon, item.label)),
            Expanded(child: _actionButton(Icons.undo, onUndo)),
            Expanded(child: _actionButton(Icons.redo, onRedo)),
            Expanded(child: _actionButton(Icons.refresh, onReset)),
          ],
        ),
      ),
    );
  }

  Widget _toolItem(EditorTool tool, IconData icon, String label) {
    final active = tool == selectedTool;
    final color = active ? AppColors.primary : AppColors.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToolSelected(tool),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: color,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(icon, size: 22, color: AppColors.text2),
    );
  }
}
