import 'dart:async';

import 'package:intuly/features/editor/data/mask_data.dart';
import 'package:intuly/features/editor/data/sam_segmenter.dart';

/// 可编排的 SAM 推理替身：不加载 ONNX，直接返回预设 mask。
class FakeSamSegmenter implements SamSegmenter {
  int ensureCalls = 0;
  int segmentCalls = 0;
  int? readyWidth;
  int? readyHeight;
  Object? ensureError;
  MaskData? nextMask;
  Completer<MaskData?>? pending;

  @override
  Future<void> ensureReady({
    required int imageWidth,
    required int imageHeight,
  }) async {
    ensureCalls++;
    if (ensureError != null) throw ensureError!;
    readyWidth = imageWidth;
    readyHeight = imageHeight;
  }

  @override
  Future<MaskData?> segmentAt({
    required double normX,
    required double normY,
  }) {
    segmentCalls++;
    if (pending != null) return pending!.future;
    return Future.value(nextMask);
  }

  @override
  void dispose() {}
}
