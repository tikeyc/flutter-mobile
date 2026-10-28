import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/auto_cutout_providers.dart';
import 'package:intuly/features/editor/data/mask_data.dart';

import '../../../helpers/fake_matting_segmenter.dart';

ProviderContainer makeContainer(FakeMattingSegmenter fake) {
  final container = ProviderContainer(
    overrides: [mattingSegmenterProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

/// 全透明占位图；推理替身只记录引用，不读像素。
Future<ui.Image> makeImage(int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List(width * height * 4),
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cutout 识别主体生成预览，takePreview 转移图片所有权', () async {
    final fake = FakeMattingSegmenter()
      ..nextMask = const MaskData(values: [0, 1, 1, 0], width: 2, height: 2);
    final container = makeContainer(fake);
    final image = await makeImage(4, 4);
    addTearDown(image.dispose);

    await container.read(autoCutoutProvider.notifier).cutout(image);

    final state = container.read(autoCutoutProvider);
    expect(state.status, AutoCutoutStatus.ready);
    expect(state.inferring, isFalse);
    expect(state.preview, isNotNull);
    expect(state.preview!.width, 2);
    expect(state.preview!.height, 2);
    expect(fake.ensureCalls, 1);
    expect(fake.segmentCalls, 1);
    expect(fake.lastImage, same(image));

    final content = container.read(autoCutoutProvider.notifier).takePreview();
    expect(content, isNotNull);
    expect(content!.image.width, 2);
    expect(container.read(autoCutoutProvider).preview, isNull);
    content.dispose();
  });

  test('state.mask 随预览存亡，takePreview 后清空', () async {
    final fake = FakeMattingSegmenter()
      ..nextMask = const MaskData(values: [0, 1, 1, 0], width: 2, height: 2);
    final container = makeContainer(fake);
    final image = await makeImage(4, 4);
    addTearDown(image.dispose);
    final notifier = container.read(autoCutoutProvider.notifier);

    expect(container.read(autoCutoutProvider).mask, isNull);

    await notifier.cutout(image);
    final mask = container.read(autoCutoutProvider).mask;
    expect(mask?.width, 2);
    expect(mask?.values, const [0, 1, 1, 0]);

    final content = notifier.takePreview();
    expect(container.read(autoCutoutProvider).mask, isNull);
    content!.dispose();
  });

  test('模型加载失败进入 error 且不推理', () async {
    final fake = FakeMattingSegmenter()..ensureError = StateError('模型加载失败');
    final container = makeContainer(fake);
    final image = await makeImage(2, 2);
    addTearDown(image.dispose);

    await container.read(autoCutoutProvider.notifier).cutout(image);

    final state = container.read(autoCutoutProvider);
    expect(state.status, AutoCutoutStatus.error);
    expect(state.errorMessage, contains('模型加载失败'));
    expect(state.preview, isNull);
    expect(fake.segmentCalls, 0);
  });

  test('推理无结果时保持 ready 且无预览', () async {
    final fake = FakeMattingSegmenter();
    final container = makeContainer(fake);
    final image = await makeImage(2, 2);
    addTearDown(image.dispose);

    await container.read(autoCutoutProvider.notifier).cutout(image);

    final state = container.read(autoCutoutProvider);
    expect(state.status, AutoCutoutStatus.ready);
    expect(state.preview, isNull);
    expect(state.inferring, isFalse);
  });

  test('cancelPreview 清空并释放预览图', () async {
    final fake = FakeMattingSegmenter()
      ..nextMask = const MaskData(values: [1], width: 1, height: 1);
    final container = makeContainer(fake);
    final image = await makeImage(2, 2);
    addTearDown(image.dispose);

    final notifier = container.read(autoCutoutProvider.notifier);
    await notifier.cutout(image);
    final preview = container.read(autoCutoutProvider).preview!;

    notifier.cancelPreview();

    expect(container.read(autoCutoutProvider).preview, isNull);
    expect(preview.debugDisposed, isTrue);
  });

  test('取消后丢弃在途推理结果', () async {
    final fake = FakeMattingSegmenter()..pending = Completer<MaskData?>();
    final container = makeContainer(fake);
    final image = await makeImage(2, 2);
    addTearDown(image.dispose);

    final notifier = container.read(autoCutoutProvider.notifier);
    final running = notifier.cutout(image);
    await Future<void>.delayed(Duration.zero);
    expect(fake.segmentCalls, 1);

    notifier.cancelPreview();
    fake.pending!.complete(const MaskData(values: [1], width: 1, height: 1));
    await running;

    final state = container.read(autoCutoutProvider);
    expect(state.preview, isNull);
    expect(state.inferring, isFalse);
  });

  test('推理进行中重复调用被忽略', () async {
    final fake = FakeMattingSegmenter()..pending = Completer<MaskData?>();
    final container = makeContainer(fake);
    final image = await makeImage(2, 2);
    addTearDown(image.dispose);

    final notifier = container.read(autoCutoutProvider.notifier);
    final first = notifier.cutout(image);
    await Future<void>.delayed(Duration.zero);

    await notifier.cutout(image);
    expect(fake.segmentCalls, 1);

    fake.pending!.complete(const MaskData(values: [1], width: 1, height: 1));
    await first;

    expect(container.read(autoCutoutProvider).preview, isNotNull);
    expect(container.read(autoCutoutProvider).inferring, isFalse);
  });
}
