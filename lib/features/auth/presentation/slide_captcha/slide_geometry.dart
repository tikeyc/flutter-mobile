import 'dart:math' as math;

import '../../data/models/slide_challenge.dart';

/// 原图像素 ↔ 渲染逻辑像素的换算。与 Web 端 custom.vue 一致：
/// scale = 渲染宽 / 原图宽；moveWidth = round(拖动距离 / scale)。
class SlideGeometry {
  static const double knobSize = 44;

  final double renderWidth;
  final double scale;
  final double renderHeight;
  final double pieceWidth;
  final double pieceHeight;
  final double pieceTop;

  SlideGeometry(SlideChallenge c, this.renderWidth)
      : scale = renderWidth / c.width,
        renderHeight = c.height * (renderWidth / c.width),
        pieceWidth = c.pieceWidth * (renderWidth / c.width),
        pieceHeight = c.pieceHeight * (renderWidth / c.width),
        pieceTop = c.pieceTop * (renderWidth / c.width);

  /// 拼图块和把手都不越界的最大拖动距离。
  double get maxOffset => math.max(0, renderWidth - math.max(pieceWidth, knobSize));

  double clamp(double offset) => offset.clamp(0, maxOffset).toDouble();

  int moveWidthFor(double offset) => (offset / scale).round();
}
