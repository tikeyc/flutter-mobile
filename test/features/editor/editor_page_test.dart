import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intuly/core/theme/app_colors.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/presentation/editor_page.dart';
import '../../helpers/test_images.dart' show kPngBytes;

/// 记录调用并返回预设路径的选图服务；nextPath 为 null 模拟用户取消。
class FakeImagePickService extends ImagePickService {
  int galleryCalls = 0;
  int cameraCalls = 0;
  String? nextPath = '/fake/image.png';

  @override
  Future<XFile?> pickFromGallery(BuildContext context) async {
    galleryCalls++;
    return nextPath == null ? null : XFile(nextPath!);
  }

  @override
  Future<XFile?> pickFromCamera(BuildContext context) async {
    cameraCalls++;
    return nextPath == null ? null : XFile(nextPath!);
  }
}

/// 写入一份真实 PNG 到临时文件并返回路径（画布需要真实字节才能解码）。
/// dart:io 异步在 fake async 区不会完成，必须包在 runAsync 里。
Future<String> writeTempPng(WidgetTester tester) async {
  late String path;
  await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('editor_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/photo.png');
    await file.writeAsBytes(kPngBytes);
    path = file.path;
  });
  return path;
}

Future<ProviderContainer> pumpEditor(
  WidgetTester tester, {
  ImagePickService? picker,
  VoidCallback? onClose,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (picker != null) imagePickServiceProvider.overrideWithValue(picker),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: EditorPage(onClose: onClose ?? () {})),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// 等待真实异步（图片解码/PNG 导出）完成的通用模式：
/// runAsync 与 fake 区交替——runAsync 内让真实事件循环喘息（I/O/解码完成），
/// 回到 fake 区再 pump 重建帧；runAsync 内绝不 pump/pumpAndSettle。
Future<void> pumpRealAsync(
  WidgetTester tester,
  bool Function() done,
) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done(), isTrue, reason: '真实异步等待超时');
  await tester.pumpAndSettle();
}

/// 走一遍“选图 → 解码 → 画布上屏”流程；返回选图后的 ProviderContainer。
Future<ProviderContainer> pickImageAndLoad(
  WidgetTester tester, {
  required FakeImagePickService picker,
  String sheetItem = '从相册选择',
}) async {
  final container = await pumpEditor(tester, picker: picker);
  await tester.tap(find.text('点击选择图片'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sheetItem));
  await pumpRealAsync(tester, () => find.byType(DrawingBoard).evaluate().isNotEmpty);
  return container;
}

/// 在画布上画一笔。画板输入层是 Listener，按下即开始绘制，无需停顿。
Future<void> drawStroke(WidgetTester tester, Offset offset) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byType(DrawingBoard)));
  final steps = (offset.distance / 8).ceil();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(offset / steps.toDouble());
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('无图片时显示选择占位', (tester) async {
    await pumpEditor(tester);

    expect(find.text('点击选择图片'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无图片时立即生成不可用', (tester) async {
    await pumpEditor(tester);

    final button =
        tester.widget<GestureDetector>(find.byKey(const Key('editor-generate')));
    expect(button.onTap, isNull);
  });

  testWidgets('点击占位弹出相册/拍照选择面板', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();

    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板选择相册后解码上屏并显示画布', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    final container = await pickImageAndLoad(tester, picker: picker);

    expect(picker.galleryCalls, 1);
    expect(container.read(editorProvider).image?.path, isNotNull);
    expect(find.text('点击选择图片'), findsNothing);
    expect(find.byType(DrawingBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板选择拍照后调用相机选图服务', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    final container = await pickImageAndLoad(
      tester,
      picker: picker,
      sheetItem: '拍照',
    );

    expect(picker.cameraCalls, 1);
    expect(container.read(editorProvider).image?.path, isNotNull);
    expect(find.byType(DrawingBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选图取消（服务返回 null）时状态保持无图', (tester) async {
    final picker = FakeImagePickService()..nextPath = null;
    final container = await pumpEditor(tester, picker: picker);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();

    expect(container.read(editorProvider).image, isNull);
    expect(find.text('点击选择图片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击返回键触发 onClose 返回上一页', (tester) async {
    var closed = false;
    await pumpEditor(tester, onClose: () => closed = true);

    await tester.tap(find.byKey(const Key('editor-back')));

    expect(closed, isTrue);
  });

  testWidgets('关闭按钮删除图片并回到选图占位', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    final container = await pickImageAndLoad(tester, picker: picker);
    expect(container.read(editorProvider).image?.path, isNotNull);

    await tester.tap(find.byKey(const Key('editor-close')));
    await tester.pumpAndSettle();

    expect(container.read(editorProvider).image, isNull);
    expect(find.text('点击选择图片'), findsOneWidget);
    expect(find.byType(DrawingBoard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已选图片后可通过替换按钮换成新图', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    final container = await pickImageAndLoad(tester, picker: picker);

    await tester.tap(find.byKey(const Key('editor-replace-image')));
    await tester.pumpAndSettle();
    final secondPath = await writeTempPng(tester);
    picker.nextPath = secondPath;
    await tester.tap(find.text('从相册选择'));
    // 以新路径 ValueKey 的画布挂载为准：旧图解码期间旧画布仍在，
    // 单凭 DrawingBoard 存在会误判，导致测试结束时解码 I/O 尚未完成。
    await pumpRealAsync(
      tester,
      () => find.byKey(ValueKey(secondPath)).evaluate().isNotEmpty,
    );

    expect(picker.galleryCalls, 2);
    expect(container.read(editorProvider).image?.path, secondPath);
    expect(find.byType(DrawingBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('工具栏选中态随点击切换并高亮', (tester) async {
    final container = await pumpEditor(tester);

    await tester.tap(find.text('橡皮擦'));
    await tester.pumpAndSettle();

    expect(container.read(editorProvider).currentTool, EditorTool.eraser);
    final text = tester.widget<Text>(find.text('橡皮擦'));
    expect(text.style?.color, AppColors.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('涂抹后撤销可用，撤销后回到不可用', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    await pickImageAndLoad(tester, picker: picker);

    GestureDetector undo() => tester.widget(
          find.byKey(const Key('editor-undo')),
        );
    expect(undo().onTap, isNull);

    await drawStroke(tester, const Offset(80, 0));
    expect(undo().onTap, isNotNull);

    await tester.tap(find.byKey(const Key('editor-undo')));
    await tester.pumpAndSettle();
    expect(undo().onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('立即生成导出照片与涂抹的合成图预览', (tester) async {
    final picker = FakeImagePickService()..nextPath = await writeTempPng(tester);
    await pickImageAndLoad(tester, picker: picker);

    await drawStroke(tester, const Offset(60, 40));

    await tester.tap(find.byKey(const Key('editor-generate')));
    await pumpRealAsync(
      tester,
      () => find.text('生成预览').evaluate().isNotEmpty,
    );

    expect(find.text('生成预览'), findsOneWidget);
    expect(find.textContaining('KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
