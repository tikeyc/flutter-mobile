import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'mask_data.dart';

const String kMattingModelAsset = 'assets/onnx/model/u2netp.onnx';

/// 传入 ORT 的模型地址；Web 端资源 URL 为 `assets/<资源键>`（同 SAM）。
String mattingModelPath({required bool isWeb}) =>
    isWeb ? 'assets/$kMattingModelAsset' : kMattingModelAsset;

/// u2netp 的固定输入边长。
const int kMattingInputSide = 320;

/// 上采样 mask 的长边上限：像素级阈值运算在主线程执行，限制规模避免卡顿。
const int kMattingMaskMaxSide = 1024;

/// ImageNet 归一化参数（u2netp 训练时使用）。
const List<double> _mean = [0.485, 0.456, 0.406];
const List<double> _std = [0.229, 0.224, 0.225];

/// 自动抠图（前景分割）接口；抽出来便于测试替换。
abstract class MattingSegmenter {
  Future<void> ensureReady();

  /// 识别主体，返回按原始图片尺寸（长边受限）的 mask。
  Future<MaskData?> segment(ui.Image image);

  void dispose();
}

/// 把 mask 输出尺寸限制在 [kMattingMaskMaxSide] 内（等比）。
({int width, int height}) mattingMaskSize(int width, int height) {
  final longest = math.max(width, height);
  if (longest <= kMattingMaskMaxSide) {
    return (width: math.max(1, width), height: math.max(1, height));
  }
  final scale = kMattingMaskMaxSide / longest;
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}

/// RGBA 像素 → NCHW float32（ImageNet mean/std 归一化）。
Float32List rgbaToNchw(Uint8List rgba) {
  const side = kMattingInputSide;
  const pixels = side * side;
  if (rgba.length != pixels * 4) {
    throw ArgumentError.value(
      rgba.length,
      'rgba',
      '长度应为 ${pixels * 4}（$side×$side RGBA）',
    );
  }

  final floats = Float32List(pixels * 3);
  for (var i = 0; i < pixels; i++) {
    final offset = i * 4;
    floats[i] = (rgba[offset] / 255 - _mean[0]) / _std[0];
    floats[pixels + i] = (rgba[offset + 1] / 255 - _mean[1]) / _std[1];
    floats[2 * pixels + i] = (rgba[offset + 2] / 255 - _mean[2]) / _std[2];
  }
  return floats;
}

/// 模型输出概率 → 目标尺寸的二值 mask。
///
/// 先按最大值归一化（与 rembg 对 u2netp 的处理一致），再双线性上采样，
/// 最后以 [threshold] 判定，保证边缘比直接取最近邻更平滑。
MaskData maskFromProbabilities(
  Float32List probabilities, {
  required int sourceSide,
  required int width,
  required int height,
  double threshold = 0.5,
}) {
  if (probabilities.length != sourceSide * sourceSide) {
    throw ArgumentError.value(
      probabilities.length,
      'probabilities',
      '长度应为 ${sourceSide * sourceSide}（$sourceSide×$sourceSide）',
    );
  }

  var max = 0.0;
  for (final value in probabilities) {
    if (value > max) max = value;
  }
  final scale = max > 0 ? 1 / max : 0.0;

  final x1s = Int32List(width);
  final x2s = Int32List(width);
  final xWeights = Float32List(width);
  for (var x = 0; x < width; x++) {
    final srcX = (x + 0.5) * sourceSide / width - 0.5;
    var left = srcX.floor();
    var weight = srcX - left;
    if (left < 0) {
      left = 0;
      weight = 0;
    } else if (left >= sourceSide - 1) {
      left = sourceSide - 1;
      weight = 0;
    }
    x1s[x] = left;
    x2s[x] = math.min(left + 1, sourceSide - 1);
    xWeights[x] = weight.toDouble();
  }

  final values = Float32List(width * height);
  for (var y = 0; y < height; y++) {
    final srcY = (y + 0.5) * sourceSide / height - 0.5;
    var top = srcY.floor();
    var yWeight = srcY - top;
    if (top < 0) {
      top = 0;
      yWeight = 0;
    } else if (top >= sourceSide - 1) {
      top = sourceSide - 1;
      yWeight = 0;
    }
    final bottom = math.min(top + 1, sourceSide - 1);
    final topRow = top * sourceSide;
    final bottomRow = bottom * sourceSide;

    for (var x = 0; x < width; x++) {
      final left = x1s[x];
      final right = x2s[x];
      final wx = xWeights[x];
      final probability =
          probabilities[topRow + left] * (1 - wx) * (1 - yWeight) +
              probabilities[topRow + right] * wx * (1 - yWeight) +
              probabilities[bottomRow + left] * (1 - wx) * yWeight +
              probabilities[bottomRow + right] * wx * yWeight;
      values[y * width + x] = probability * scale > threshold ? 1.0 : 0.0;
    }
  }

  return MaskData(values: values, width: width, height: height);
}

/// 基于 flutter_onnxruntime 的 u2netp 前景分割。
class OnnxMattingSegmenter implements MattingSegmenter {
  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _session;
  Future<void>? _initializing;
  bool _running = false;

  @override
  Future<void> ensureReady() {
    if (_session != null) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _session = kIsWeb
          ? await _ort.createSession(mattingModelPath(isWeb: true))
          : await _ort.createSessionFromAsset(mattingModelPath(isWeb: false));
    } catch (_) {
      await _release();
      rethrow;
    } finally {
      _initializing = null;
    }
  }

  @override
  Future<MaskData?> segment(ui.Image image) async {
    await ensureReady();
    final session = _session;
    if (session == null || _running) return null;

    _running = true;
    ui.Image? resized;
    OrtValue? input;
    OrtValue? output;
    try {
      resized = await _toModelInput(image);
      final byteData = await resized.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      final rgba = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      input = await OrtValue.fromList(rgbaToNchw(rgba), const [
        1,
        3,
        kMattingInputSide,
        kMattingInputSide,
      ]);

      final outputs = await session.run({_inputName: input});
      final outputName = session.outputNames.isEmpty
          ? _fallbackOutputName
          : session.outputNames.first;
      output = outputs[outputName];
      if (output == null) return null;

      final flattened = await output.asFlattenedList();
      const pixels = kMattingInputSide * kMattingInputSide;
      if (flattened.length < pixels) return null;
      final probabilities = Float32List(pixels);
      for (var i = 0; i < pixels; i++) {
        probabilities[i] = (flattened[i] as num).toDouble();
      }

      final size = mattingMaskSize(image.width, image.height);
      return maskFromProbabilities(
        probabilities,
        sourceSide: kMattingInputSide,
        width: size.width,
        height: size.height,
      );
    } finally {
      await output?.dispose();
      await input?.dispose();
      resized?.dispose();
      _running = false;
    }
  }

  /// u2netp 的输入张量名。
  static const String _inputName = 'input.1';

  /// 输出名拿不到时的兜底：u2net 的主输出固定叫 d0。
  static const String _fallbackOutputName = 'd0';

  Future<ui.Image> _toModelInput(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(
        0,
        0,
        kMattingInputSide.toDouble(),
        kMattingInputSide.toDouble(),
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    return recorder.endRecording().toImage(
          kMattingInputSide,
          kMattingInputSide,
        );
  }

  Future<void> _release() async {
    _initializing = null;
    final session = _session;
    _session = null;
    await session?.close();
  }

  @override
  void dispose() {
    unawaited(_release());
  }
}
