import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'npy_asset.dart';

const String kSamModelAsset =
    'assets/onnx/model/sam_onnx_quantized_example.onnx';
const String kDemoImageAsset = 'assets/onnx/IntelligenSelection.png';
const String kDemoEmbeddingAsset = 'assets/onnx/IntelligenSelection.npy';

/// 传入 ORT 的模型地址。
///
/// web 端 ort 直接以 URL 拉取模型，Flutter 资源在 web 上的 URL 是
/// `assets/<资源键>`（相对 base href），与原生端的资源键不同。
String samModelPath({required bool isWeb}) =>
    isWeb ? 'assets/$kSamModelAsset' : kSamModelAsset;

const int _embeddingSize = 256 * 64 * 64;
const int _maskInputSide = 256;

/// SAM 输出的原始 mask（float logits，>0 为选中）。
class SamMask {
  const SamMask({
    required this.values,
    required this.width,
    required this.height,
  });

  final List<num> values;
  final int width;
  final int height;
}

/// 归一化点按坐标 → SAM 长边 1024 坐标系（与 Web 端一致）。
({double x, double y}) samPointCoords(
  double normX,
  double normY, {
  required int imageWidth,
  required int imageHeight,
}) {
  final scale = 1024 / math.max(imageWidth, imageHeight);
  return (
    x: normX.clamp(0.0, 1.0).toDouble() * imageWidth * scale,
    y: normY.clamp(0.0, 1.0).toDouble() * imageHeight * scale,
  );
}

/// 点选推理接口；抽出来便于测试替换。
abstract class SamSegmenter {
  Future<void> ensureReady({
    required int imageWidth,
    required int imageHeight,
  });

  /// 以归一化坐标推理，返回原图尺寸的 mask。
  Future<SamMask?> segmentAt({required double normX, required double normY});

  void dispose();
}

/// 基于 flutter_onnxruntime 的 SAM decoder。
///
/// embedding 是示例图的预计算结果（端上没有 encoder），因此只对内置示例图有效。
class OnnxSamSegmenter implements SamSegmenter {
  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _session;
  OrtValue? _embedding;
  OrtValue? _maskInput;
  OrtValue? _hasMaskInput;
  OrtValue? _origImSize;
  int? _imageWidth;
  int? _imageHeight;
  bool _running = false;

  @override
  Future<void> ensureReady({
    required int imageWidth,
    required int imageHeight,
  }) async {
    if (_session != null &&
        _imageWidth == imageWidth &&
        _imageHeight == imageHeight) {
      return;
    }
    await _release();

    try {
      final npy = await loadNpyFloat32Asset(kDemoEmbeddingAsset);
      final shape = npy.shape;
      if (shape.length != 4 ||
          shape[0] != 1 ||
          shape[1] != 256 ||
          shape[2] != 64 ||
          shape[3] != 64 ||
          npy.data.length != _embeddingSize) {
        throw StateError('embedding 形状异常: $shape');
      }

      _session = kIsWeb
          ? await _ort.createSession(samModelPath(isWeb: true))
          : await _ort.createSessionFromAsset(samModelPath(isWeb: false));
      _embedding = await OrtValue.fromList(npy.data, shape);
      _maskInput = await OrtValue.fromList(
        Float32List(_maskInputSide * _maskInputSide),
        [1, 1, _maskInputSide, _maskInputSide],
      );
      _hasMaskInput = await OrtValue.fromList(
        Float32List.fromList([0]),
        [1],
      );
      _origImSize = await OrtValue.fromList(
        Float32List.fromList([imageHeight.toDouble(), imageWidth.toDouble()]),
        [2],
      );
      _imageWidth = imageWidth;
      _imageHeight = imageHeight;
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  @override
  Future<SamMask?> segmentAt({
    required double normX,
    required double normY,
  }) async {
    final session = _session;
    final embedding = _embedding;
    final maskInput = _maskInput;
    final hasMaskInput = _hasMaskInput;
    final origImSize = _origImSize;
    final imageWidth = _imageWidth;
    final imageHeight = _imageHeight;
    if (session == null ||
        embedding == null ||
        maskInput == null ||
        hasMaskInput == null ||
        origImSize == null ||
        imageWidth == null ||
        imageHeight == null ||
        _running) {
      return null;
    }

    _running = true;
    OrtValue? pointCoords;
    OrtValue? pointLabels;
    OrtValue? masks;
    try {
      final point = samPointCoords(
        normX,
        normY,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      pointCoords = await OrtValue.fromList(
        Float32List.fromList([point.x, point.y]),
        [1, 1, 2],
      );
      pointLabels = await OrtValue.fromList(
        Float32List.fromList([1]),
        [1, 1],
      );

      final outputs = await session.run({
        'image_embeddings': embedding,
        'point_coords': pointCoords,
        'point_labels': pointLabels,
        'orig_im_size': origImSize,
        'mask_input': maskInput,
        'has_mask_input': hasMaskInput,
      });

      masks = outputs['masks'];
      if (masks == null || masks.shape.length != 4) return null;
      final values = await masks.asFlattenedList();
      final shape = masks.shape;
      return SamMask(
        values: values.cast<num>(),
        width: shape[3],
        height: shape[2],
      );
    } finally {
      await masks?.dispose();
      await pointCoords?.dispose();
      await pointLabels?.dispose();
      _running = false;
    }
  }

  Future<void> _release() async {
    final session = _session;
    final values = [_embedding, _maskInput, _hasMaskInput, _origImSize];
    _session = null;
    _embedding = null;
    _maskInput = null;
    _hasMaskInput = null;
    _origImSize = null;
    _imageWidth = null;
    _imageHeight = null;

    for (final value in values) {
      await value?.dispose();
    }
    await session?.close();
  }

  @override
  void dispose() {
    unawaited(_release());
  }
}
