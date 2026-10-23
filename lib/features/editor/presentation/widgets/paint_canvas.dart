import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_providers.dart';

/// 涂抹画笔：主色、60% 不透明度，笔迹下的图片仍可见。
const double kBrushWidth = 24;
const double kBrushOpacity = 0.6;

/// 橡皮擦宽度。
const double kEraserWidth = 32;

/// 按图片宽高比将尺寸限制在 maxSize 内（BoxFit.contain）。
Size containImageSize(ui.Image image, Size maxSize) {
  if (maxSize.isEmpty) return Size.zero;
  final scale = math.min(
    maxSize.width / image.width,
    maxSize.height / image.height,
  );
  return Size(image.width * scale, image.height * scale);
}

/// flutter_drawing_board 画布：以图片为背景，上方叠加绘制层。
///
/// 涂抹/橡皮擦的绘制内容与画笔参数由 [tool] 决定，切换工具即重设
/// 画笔；包内 Painter 输入层基于 Listener，按下即开始绘制，无手势
/// 识别延迟，快速连画/快速擦除均即时生效。画板禁用平移与缩放，
/// 手势坐标即画布逻辑坐标。
class PaintCanvas extends StatefulWidget {
  const PaintCanvas({
    super.key,
    required this.controller,
    required this.image,
    required this.size,
    this.tool = EditorTool.brush,
  });

  final DrawingController controller;
  final ui.Image image;
  final Size size;
  final EditorTool tool;

  @override
  State<PaintCanvas> createState() => _PaintCanvasState();
}

class _PaintCanvasState extends State<PaintCanvas> {
  @override
  void initState() {
    super.initState();
    _applyTool(widget.tool);
  }

  @override
  void didUpdateWidget(covariant PaintCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool) _applyTool(widget.tool);
  }

  void _applyTool(EditorTool tool) {
    switch (tool) {
      // 用单 path 贝塞尔线条（SimpleLine）：整条笔迹一次 drawPath 绘制，
      // 透明度均匀为 60%；SmoothLine 分段绘制圆头相互重叠，会叠加成近不透明。
      case EditorTool.brush:
        widget.controller
          ..setPaintContent(SimpleLine(useBezierCurve: true))
          ..setStyle(
            color: AppColors.primary.withValues(alpha: kBrushOpacity),
            strokeWidth: kBrushWidth,
            isAntiAlias: true,
          );
      case EditorTool.eraser:
        widget.controller
          ..setPaintContent(Eraser())
          ..setStyle(
            strokeWidth: kEraserWidth,
            isAntiAlias: true,
          );
      case EditorTool.smartSelect:
      case EditorTool.autoCutout:
        // 占位工具：不改画笔配置，画布输入由 IgnorePointer 禁用。
        break;
    }
  }

  bool get _inputEnabled =>
      widget.tool == EditorTool.brush || widget.tool == EditorTool.eraser;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_inputEnabled,
      child: DrawingBoard(
        controller: widget.controller,
        boardPanEnabled: false,
        boardScaleEnabled: false,
        background: SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: RawImage(image: widget.image, fit: BoxFit.fill),
        ),
      ),
    );
  }
}
