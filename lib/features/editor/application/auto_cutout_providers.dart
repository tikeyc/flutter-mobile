import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mask_data.dart';
import '../data/matting_segmenter.dart';
import 'mask_content.dart';
import 'mask_image.dart';

enum AutoCutoutStatus { idle, loading, ready, error }

class AutoCutoutState {
  const AutoCutoutState({
    this.status = AutoCutoutStatus.idle,
    this.preview,
    this.mask,
    this.inferring = false,
    this.errorMessage,
  });

  final AutoCutoutStatus status;

  /// 原图分辨率的选区预览图；应用后所有权转移给画布图层。
  final ui.Image? preview;

  /// 预览对应的原始 mask，生成时用于导出透明主体。
  final MaskData? mask;
  final bool inferring;
  final String? errorMessage;
}

final mattingSegmenterProvider = Provider<MattingSegmenter>((ref) {
  final segmenter = OnnxMattingSegmenter();
  ref.onDispose(segmenter.dispose);
  return segmenter;
});

final autoCutoutProvider =
    NotifierProvider<AutoCutoutController, AutoCutoutState>(
  AutoCutoutController.new,
);

/// 自动抠图状态机：加载模型 → 推理主体 → 预览 → 应用/取消。
class AutoCutoutController extends Notifier<AutoCutoutState> {
  ui.Image? _preview;
  MaskData? _mask;
  int _generation = 0;

  @override
  AutoCutoutState build() {
    ref.onDispose(() {
      _generation++;
      _preview?.dispose();
      _preview = null;
      _mask = null;
    });
    return const AutoCutoutState();
  }

  void _emit(
    AutoCutoutStatus status, {
    bool inferring = false,
    String? errorMessage,
  }) {
    state = AutoCutoutState(
      status: status,
      preview: _preview,
      mask: _mask,
      inferring: inferring,
      errorMessage: errorMessage,
    );
  }

  /// 识别图片主体并生成预览；进行中重复调用会被忽略。
  Future<void> cutout(ui.Image image) async {
    if (state.inferring || state.status == AutoCutoutStatus.loading) return;

    final generation = ++_generation;
    _preview?.dispose();
    _preview = null;
    _emit(AutoCutoutStatus.loading);

    try {
      final segmenter = ref.read(mattingSegmenterProvider);
      await segmenter.ensureReady();
      if (generation != _generation) return;

      _emit(AutoCutoutStatus.ready, inferring: true);
      final mask = await segmenter.segment(image);
      if (mask == null || generation != _generation) return;

      final preview = await maskToImage(
        mask.values,
        width: mask.width,
        height: mask.height,
      );
      if (generation != _generation) {
        preview.dispose();
        return;
      }

      _preview = preview;
      _mask = mask;
      _emit(AutoCutoutStatus.ready);
    } catch (error) {
      if (generation == _generation) {
        _emit(AutoCutoutStatus.error, errorMessage: '$error');
      }
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
}
