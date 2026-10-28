import 'dart:async';
import 'dart:ui' as ui;

import 'package:intuly/features/editor/data/mask_data.dart';
import 'package:intuly/features/editor/data/matting_segmenter.dart';

/// 可编排的自动抠图推理替身：不加载 ONNX，直接返回预设 mask。
class FakeMattingSegmenter implements MattingSegmenter {
  int ensureCalls = 0;
  int segmentCalls = 0;
  Object? ensureError;
  MaskData? nextMask;
  Completer<MaskData?>? pending;
  ui.Image? lastImage;

  @override
  Future<void> ensureReady() async {
    ensureCalls++;
    if (ensureError != null) throw ensureError!;
  }

  @override
  Future<MaskData?> segment(ui.Image image) {
    segmentCalls++;
    lastImage = image;
    if (pending != null) return pending!.future;
    return Future.value(nextMask);
  }

  @override
  void dispose() {}
}
