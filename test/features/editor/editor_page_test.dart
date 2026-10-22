import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/theme/app_colors.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/presentation/editor_page.dart';

/// 记录调用并返回预设路径的选图服务；nextPath 为 null 模拟用户取消。
class FakeImagePickService extends ImagePickService {
  int galleryCalls = 0;
  int cameraCalls = 0;
  String? nextPath = '/fake/image.png';

  @override
  Future<String?> pickFromGallery(BuildContext context) async {
    galleryCalls++;
    return nextPath;
  }

  @override
  Future<String?> pickFromCamera(BuildContext context) async {
    cameraCalls++;
    return nextPath;
  }
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

void main() {
  testWidgets('无图片时显示选择占位', (tester) async {
    await pumpEditor(tester);

    expect(find.text('点击选择图片'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击占位弹出相册/拍照选择面板', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();

    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板选择相册后调用选图服务并写入状态', (tester) async {
    final picker = FakeImagePickService()..nextPath = '/fake/gallery.png';
    final container = await pumpEditor(tester, picker: picker);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(container.read(editorProvider).imagePath, '/fake/gallery.png');
    // 面板已关闭，图片上屏后占位消失。
    expect(find.text('从相册选择'), findsNothing);
    expect(find.text('点击选择图片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板选择拍照后调用相机选图服务', (tester) async {
    final picker = FakeImagePickService()..nextPath = '/fake/camera.png';
    final container = await pumpEditor(tester, picker: picker);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(container.read(editorProvider).imagePath, '/fake/camera.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('选图取消（服务返回 null）时状态保持无图', (tester) async {
    final picker = FakeImagePickService()..nextPath = null;
    final container = await pumpEditor(tester, picker: picker);

    await tester.tap(find.text('点击选择图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();

    expect(container.read(editorProvider).imagePath, isNull);
    expect(find.text('点击选择图片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击右上角关闭按钮触发 onClose 回调', (tester) async {
    var closed = false;
    await pumpEditor(tester, onClose: () => closed = true);

    await tester.tap(find.byKey(const Key('editor-close')));

    expect(closed, isTrue);
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
}
