import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

/// 智能点选生成的选区图层：按画布尺寸绘制半透明 mask 图，
/// 进入 DrawingController 历史后支持撤销/重做，也会被橡皮擦清除。
class MaskContent extends PaintContent {
  MaskContent({required this.image}) {
    paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = true;
  }

  final ui.Image image;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      paint,
    );
  }

  @override
  void drawing(Offset nowPoint) {}

  @override
  void startDraw(Offset startPoint) {}

  @override
  MaskContent copy() => this;

  @override
  Map<String, dynamic> toContentJson() => <String, dynamic>{
        'width': image.width,
        'height': image.height,
      };

  /// 图片由本图层独占，历史被清空或控制器销毁时调用。
  void dispose() => image.dispose();
}
