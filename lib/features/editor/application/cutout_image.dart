import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

import '../data/mask_data.dart';
import 'mask_image.dart';

/// 选中像素的外接框（mask 坐标）；没有任何选中像素时返回 null。
ui.Rect? maskBounds(MaskData mask) {
  var left = mask.width;
  var top = mask.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < mask.height; y++) {
    final row = y * mask.width;
    for (var x = 0; x < mask.width; x++) {
      if (mask.values[row + x] <= 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < 0) return null;
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}

/// 多个选区的并集；同一张图的 mask 尺寸一致，否则视为调用错误。
MaskData unionMasks(List<MaskData> masks) {
  if (masks.isEmpty) {
    throw ArgumentError.value(masks, 'masks', '至少需要一个 mask');
  }
  final first = masks.first;
  if (masks.length == 1) return first;
  final values = <num>[...first.values];
  for (final other in masks.skip(1)) {
    if (other.width != first.width || other.height != first.height) {
      throw ArgumentError.value(other, 'masks', '所有 mask 尺寸需一致');
    }
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] > 0) values[i] = 1;
    }
  }
  return MaskData(values: values, width: first.width, height: first.height);
}

/// 把笔迹并入选区：涂抹覆盖处保留，橡皮擦覆盖处挖掉。
///
/// 返回与 [mask] 同尺寸的新 mask；笔迹按 [boardSize] 映射到 mask 坐标。
Future<MaskData> strokesRegion({
  required MaskData mask,
  required Size boardSize,
  required List<PaintContent> strokes,
}) async {
  final recorder = ui.PictureRecorder();
  final area = ui.Rect.fromLTWH(
    0,
    0,
    mask.width.toDouble(),
    mask.height.toDouble(),
  );
  final canvas = Canvas(recorder, area);
  // 先铺选区，笔迹再叠加：橡皮擦的 clear 能同时擦掉选区与之前的笔迹。
  final base = await maskToAlphaImage(
    mask.values,
    width: mask.width,
    height: mask.height,
  );
  canvas.drawImage(base, Offset.zero, Paint());
  base.dispose();
  canvas.scale(mask.width / boardSize.width, mask.height / boardSize.height);
  for (final stroke in strokes) {
    stroke.draw(canvas, boardSize, false);
  }
  final picture = recorder.endRecording();
  final region = await picture.toImage(mask.width, mask.height);
  picture.dispose();
  try {
    final data = await region.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = data!.buffer.asUint8List();
    return MaskData(
      values: List<num>.generate(
        mask.width * mask.height,
        (i) => rgba[i * 4 + 3] > 0 ? 1 : 0,
      ),
      width: mask.width,
      height: mask.height,
    );
  } finally {
    region.dispose();
  }
}

/// 生成透明背景的主体 PNG：按外接框紧贴裁剪，[scale] 为每个 mask 像素的
/// 输出像素数。[strokes] 是画布逻辑坐标下的笔迹：涂抹区域并入主体（导出
/// 该处原图，不叠加笔迹颜色），橡皮擦区域从主体中挖掉。无选中像素时返回
/// null。
Future<Uint8List?> cutoutPng({
  required ui.Image image,
  required MaskData mask,
  required double scale,
  Size? boardSize,
  List<PaintContent> strokes = const [],
}) async {
  assert(strokes.isEmpty || boardSize != null, '有笔迹时必须提供画布尺寸');
  final region = strokes.isEmpty
      ? mask
      : await strokesRegion(
          mask: mask,
          boardSize: boardSize!,
          strokes: strokes,
        );
  final bounds = maskBounds(region);
  if (bounds == null) return null;

  final imageRect = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final pixelsPerMaskX = image.width / region.width;
  final pixelsPerMaskY = image.height / region.height;
  final src = ui.Rect.fromLTRB(
    bounds.left * pixelsPerMaskX,
    bounds.top * pixelsPerMaskY,
    bounds.right * pixelsPerMaskX,
    bounds.bottom * pixelsPerMaskY,
  ).intersect(imageRect);
  if (src.isEmpty) return null;

  final width = math.max(1, (bounds.width * scale).round());
  final height = math.max(1, (bounds.height * scale).round());
  final dst = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  final alpha = await maskToAlphaImage(
    region.values,
    width: region.width,
    height: region.height,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, dst);
  canvas.drawImageRect(
    image,
    src,
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
  // 遮罩层用 dstIn 合成：只保留主体，其余透明。
  // 1:1 输出时关闭插值，避免选中边缘被平白淡化成半透明。
  canvas.drawImageRect(
    alpha,
    bounds,
    dst,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..filterQuality = scale == 1 ? FilterQuality.none : FilterQuality.high,
  );
  final picture = recorder.endRecording();
  alpha.dispose();
  final output = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    output.dispose();
  }
}
