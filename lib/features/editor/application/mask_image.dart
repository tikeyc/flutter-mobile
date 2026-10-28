import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 与 Web 端一致的选区颜色：rgba(0, 200, 100, 115)。
const int kMaskRed = 0;
const int kMaskGreen = 200;
const int kMaskBlue = 100;
const int kMaskAlpha = 115;

/// 把 SAM 输出 mask 转成 RGBA 像素，`> 0` 视为选中。
Uint8List maskToRgba(
  List<num> mask, {
  required int width,
  required int height,
}) {
  final expected = width * height;
  if (mask.length != expected) {
    throw ArgumentError.value(
      mask.length,
      'mask',
      '长度应为 $expected（$width×$height）',
    );
  }

  final rgba = Uint8List(expected * 4);
  for (var i = 0; i < expected; i++) {
    if (mask[i] > 0) {
      final offset = i * 4;
      rgba[offset] = kMaskRed;
      rgba[offset + 1] = kMaskGreen;
      rgba[offset + 2] = kMaskBlue;
      rgba[offset + 3] = kMaskAlpha;
    }
  }
  return rgba;
}

/// 把 mask 转成白色 + alpha 的裁剪遮罩像素：选中 alpha 255，其余全透明。
Uint8List maskToAlphaRgba(
  List<num> mask, {
  required int width,
  required int height,
}) {
  final expected = width * height;
  if (mask.length != expected) {
    throw ArgumentError.value(
      mask.length,
      'mask',
      '长度应为 $expected（$width×$height）',
    );
  }

  final rgba = Uint8List(expected * 4);
  for (var i = 0; i < expected; i++) {
    if (mask[i] <= 0) continue;
    final offset = i * 4;
    rgba[offset] = 255;
    rgba[offset + 1] = 255;
    rgba[offset + 2] = 255;
    rgba[offset + 3] = 255;
  }
  return rgba;
}

/// 把 mask 转成可配合 [ui.BlendMode.dstIn] 裁剪主体的 alpha 遮罩图。
Future<ui.Image> maskToAlphaImage(
  List<num> mask, {
  required int width,
  required int height,
}) {
  final rgba = maskToAlphaRgba(mask, width: width, height: height);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// 把 mask 转成可直接绘制/导出的半透明绿色图片。
///
/// [ui.PixelFormat.rgba8888] 要求预乘 alpha，因此这里把直通色预乘后再解码。
Future<ui.Image> maskToImage(
  List<num> mask, {
  required int width,
  required int height,
}) {
  final rgba = maskToRgba(mask, width: width, height: height);
  for (var i = 0; i < rgba.length; i += 4) {
    final alpha = rgba[i + 3];
    if (alpha == 0) continue;
    rgba[i] = rgba[i] * alpha ~/ 255;
    rgba[i + 1] = rgba[i + 1] * alpha ~/ 255;
    rgba[i + 2] = rgba[i + 2] * alpha ~/ 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
