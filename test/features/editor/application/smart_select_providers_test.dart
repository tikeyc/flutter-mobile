import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/smart_select_providers.dart';
import 'package:intuly/features/editor/data/mask_data.dart';
import 'package:intuly/features/editor/data/sam_segmenter.dart';

import '../../../helpers/fake_sam_segmenter.dart';

ProviderContainer makeContainer(FakeSamSegmenter fake) {
  final container = ProviderContainer(
    overrides: [samSegmenterProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('归一化点按长边 1024 映射到模型坐标系', () {
    final point = samPointCoords(
      0.5,
      0.25,
      imageWidth: 600,
      imageHeight: 400,
    );

    expect(point.x, closeTo(512, 1e-6));
    expect(point.y, closeTo(400 * 0.25 * 1024 / 600, 1e-6));
  });

  test('ensureReady 成功后进入 ready 并传入图片尺寸', () async {
    final fake = FakeSamSegmenter();
    final container = makeContainer(fake);

    await container
        .read(smartSelectProvider.notifier)
        .ensureReady(imageWidth: 600, imageHeight: 400);

    final state = container.read(smartSelectProvider);
    expect(state.status, SmartSelectStatus.ready);
    expect(state.errorMessage, isNull);
    expect(fake.ensureCalls, 1);
    expect(fake.readyWidth, 600);
    expect(fake.readyHeight, 400);
  });

  test('ensureReady 失败进入 error 并带错误信息', () async {
    final fake = FakeSamSegmenter()..ensureError = StateError('模型加载失败');
    final container = makeContainer(fake);

    await container
        .read(smartSelectProvider.notifier)
        .ensureReady(imageWidth: 600, imageHeight: 400);

    final state = container.read(smartSelectProvider);
    expect(state.status, SmartSelectStatus.error);
    expect(state.errorMessage, contains('模型加载失败'));
  });

  test('selectAt 生成预览，takePreview 转移图片所有权', () async {
    final fake = FakeSamSegmenter()
      ..nextMask = const MaskData(
        values: [1, 0, 0, 1],
        width: 2,
        height: 2,
      );
    final container = makeContainer(fake);
    final notifier = container.read(smartSelectProvider.notifier);
    await notifier.ensureReady(imageWidth: 600, imageHeight: 400);

    await notifier.selectAt(
      const Offset(0.5, 0.5),
      imageWidth: 600,
      imageHeight: 400,
    );

    final preview = container.read(smartSelectProvider).preview;
    expect(preview, isNotNull);
    expect(preview!.width, 2);
    expect(preview.height, 2);
    expect(fake.segmentCalls, 1);

    final content = notifier.takePreview();
    expect(content, isNotNull);
    expect(content!.image, same(preview));
    expect(container.read(smartSelectProvider).preview, isNull);
    expect(preview.debugDisposed, isFalse);

    content.dispose();
  });

  test('cancelPreview 清空并释放预览图', () async {
    final fake = FakeSamSegmenter()
      ..nextMask = const MaskData(values: [1], width: 1, height: 1);
    final container = makeContainer(fake);
    final notifier = container.read(smartSelectProvider.notifier);
    await notifier.ensureReady(imageWidth: 600, imageHeight: 400);
    await notifier.selectAt(
      const Offset(0.5, 0.5),
      imageWidth: 600,
      imageHeight: 400,
    );
    final preview = container.read(smartSelectProvider).preview!;

    notifier.cancelPreview();

    expect(container.read(smartSelectProvider).preview, isNull);
    expect(preview.debugDisposed, isTrue);
  });

  test('isSelected 判断点是否落在当前选区', () async {
    final fake = FakeSamSegmenter()
      ..nextMask = const MaskData(values: [1, 0, 0, 1], width: 2, height: 2);
    final container = makeContainer(fake);
    final notifier = container.read(smartSelectProvider.notifier);
    await notifier.ensureReady(imageWidth: 600, imageHeight: 400);

    expect(notifier.isSelected(const Offset(0.25, 0.25)), isFalse);

    await notifier.selectAt(
      const Offset(0.25, 0.25),
      imageWidth: 600,
      imageHeight: 400,
    );

    expect(notifier.isSelected(const Offset(0.25, 0.25)), isTrue);
    expect(notifier.isSelected(const Offset(0.75, 0.25)), isFalse);
    expect(notifier.isSelected(const Offset(0.75, 0.75)), isTrue);

    notifier.cancelPreview();
    expect(notifier.isSelected(const Offset(0.25, 0.25)), isFalse);
  });

  test('未就绪时 selectAt 不触发推理', () async {
    final fake = FakeSamSegmenter();
    final container = makeContainer(fake);

    await container.read(smartSelectProvider.notifier).selectAt(
          const Offset(0.5, 0.5),
          imageWidth: 600,
          imageHeight: 400,
        );

    expect(fake.segmentCalls, 0);
    expect(container.read(smartSelectProvider).preview, isNull);
  });

  test('推理进行中重复点选被忽略', () async {
    final fake = FakeSamSegmenter()..pending = Completer<MaskData?>();
    final container = makeContainer(fake);
    final notifier = container.read(smartSelectProvider.notifier);
    await notifier.ensureReady(imageWidth: 600, imageHeight: 400);

    final first = notifier.selectAt(
      const Offset(0.4, 0.4),
      imageWidth: 600,
      imageHeight: 400,
    );
    await notifier.selectAt(
      const Offset(0.6, 0.6),
      imageWidth: 600,
      imageHeight: 400,
    );
    expect(fake.segmentCalls, 1);

    fake.pending!.complete(
      const MaskData(values: [1], width: 1, height: 1),
    );
    await first;

    expect(container.read(smartSelectProvider).preview, isNotNull);
    expect(container.read(smartSelectProvider).inferring, isFalse);
  });
}
