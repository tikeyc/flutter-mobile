import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_providers.dart';

/// 涂抹/橡皮擦的笔宽浮层：粗细预览圆点 + 滑块，风格同选区的状态条。
class BrushSizeBar extends StatelessWidget {
  const BrushSizeBar({
    super.key,
    required this.size,
    required this.onChanged,
    this.isEraser = false,
  });

  /// 当前笔宽（画布逻辑像素）。
  final double size;
  final ValueChanged<double> onChanged;

  /// 橡皮擦用空心圆、涂抹用实心圆做预览。
  final bool isEraser;

  @override
  Widget build(BuildContext context) {
    final clamped = size.clamp(kMinStrokeWidth, kMaxStrokeWidth);
    final ratio =
        (clamped - kMinStrokeWidth) / (kMaxStrokeWidth - kMinStrokeWidth);
    // 预览圆点直径 6~30，不必按笔宽等比例（最大笔宽在实际画布上更大）。
    final dotSize = 6 + ratio * 24;
    return Container(
      width: 232,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Container(
                key: const Key('brush-size-preview'),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEraser
                      ? null
                      : Colors.white.withValues(alpha: 0.6),
                  border:
                      isEraser ? Border.all(color: Colors.white, width: 1.5) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppColors.textWhite,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: AppColors.textWhite,
                overlayColor: Colors.white.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                key: const Key('brush-size-slider'),
                value: clamped,
                min: kMinStrokeWidth,
                max: kMaxStrokeWidth,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
