import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sam_segmenter.dart';
import 'mask_content.dart';
import 'mask_image.dart';

enum SmartSelectStatus { idle, loading, ready, error }

class SmartSelectState {
  const SmartSelectState({
    this.status = SmartSelectStatus.idle,
    this.preview,
    this.inferring = false,
    this.errorMessage,
  });

  final SmartSelectStatus status;

  /// 原图分辨率的选区预览图；应用后所有权转移给画布图层。
  final ui.Image? preview;
  final bool inferring;
  final String? errorMessage;
}

final samSegmenterProvider = Provider<SamSegmenter>((ref) {
  final segmenter = OnnxSamSegmenter();
  ref.onDispose(segmenter.dispose);
  return segmenter;
});

final smartSelectProvider =
    NotifierProvider<SmartSelectController, SmartSelectState>(
  SmartSelectController.new,
);

/// 智能点选状态机：加载模型 → 点按推理 → 预览 → 应用/取消。
class SmartSelectController extends Notifier<SmartSelectState> {
  ui.Image? _preview;

  /// 当前预览对应的原始 mask，用于判断点按是否落在已选区域内。
  SamMask? _mask;
  int _generation = 0;
  int? _readyWidth;
  int? _readyHeight;

  @override
  SmartSelectState build() {
    ref.onDispose(() {
      _generation++;
      _preview?.dispose();
      _preview = null;
      _mask = null;
    });
    return const SmartSelectState();
  }

  void _emit(
    SmartSelectStatus status, {
    bool inferring = false,
    String? errorMessage,
  }) {
    state = SmartSelectState(
      status: status,
      preview: _preview,
      inferring: inferring,
      errorMessage: errorMessage,
    );
  }

  Future<void> ensureReady({
    required int imageWidth,
    required int imageHeight,
  }) async {
    if (state.status == SmartSelectStatus.loading) return;
    if (state.status == SmartSelectStatus.ready &&
        _readyWidth == imageWidth &&
        _readyHeight == imageHeight) {
      return;
    }

    _emit(SmartSelectStatus.loading);
    try {
      await ref.read(samSegmenterProvider).ensureReady(
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          );
      _readyWidth = imageWidth;
      _readyHeight = imageHeight;
      _emit(SmartSelectStatus.ready);
    } catch (error) {
      _readyWidth = null;
      _readyHeight = null;
      _emit(SmartSelectStatus.error, errorMessage: '$error');
    }
  }

  /// 点按推理；成功返回 true。连续点按只在空闲时生效。
  Future<bool> selectAt(
    Offset normalized, {
    required int imageWidth,
    required int imageHeight,
  }) async {
    if (state.status != SmartSelectStatus.ready ||
        state.inferring ||
        _readyWidth != imageWidth ||
        _readyHeight != imageHeight) {
      return false;
    }

    final generation = ++_generation;
    _emit(SmartSelectStatus.ready, inferring: true);
    try {
      final mask = await ref.read(samSegmenterProvider).segmentAt(
            normX: normalized.dx,
            normY: normalized.dy,
          );
      if (mask == null || generation != _generation) return false;

      final image = await maskToImage(
        mask.values,
        width: mask.width,
        height: mask.height,
      );
      if (generation != _generation) {
        image.dispose();
        return false;
      }

      _preview?.dispose();
      _preview = image;
      _mask = mask;
      _emit(SmartSelectStatus.ready);
      return true;
    } catch (error) {
      if (generation == _generation) {
        _emit(SmartSelectStatus.ready, errorMessage: '选区生成失败：$error');
      }
      return false;
    } finally {
      if (generation == _generation && state.inferring) {
        _emit(state.status, errorMessage: state.errorMessage);
      }
    }
  }

  /// 清空预览并丢弃进行中的推理结果。
  void cancelPreview() {
    _generation++;
    _preview?.dispose();
    _preview = null;
    _mask = null;
    _emit(state.status);
  }

  /// 把预览图转成画布图层，所有权移交给调用方。
  MaskContent? takePreview() {
    final image = _preview;
    if (image == null) return null;
    _generation++;
    _preview = null;
    _mask = null;
    _emit(state.status);
    return MaskContent(image: image);
  }

  /// 当前预览对应的原始 mask；无预览时为 null。
  SamMask? get currentMask => _mask;

  /// 点按是否落在当前预览选区内；再次点按已选区域时保留预览、不重复推理。
  bool isSelected(Offset normalized) {
    final mask = _mask;
    if (mask == null || _preview == null) return false;
    final x = (normalized.dx * mask.width).floor().clamp(0, mask.width - 1);
    final y = (normalized.dy * mask.height).floor().clamp(0, mask.height - 1);
    return mask.values[y * mask.width + x] > 0;
  }
}
