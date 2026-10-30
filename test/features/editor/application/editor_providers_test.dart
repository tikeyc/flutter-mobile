import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intuly/features/editor/application/editor_providers.dart';

void main() {
  test('初始状态无图片，默认工具为涂抹', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(editorProvider);

    expect(state.image, isNull);
    expect(state.currentTool, EditorTool.brush);
  });

  test('setImage 更新图片，不影响当前工具', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(editorProvider.notifier).setImage(XFile('/tmp/a.png'));

    final state = container.read(editorProvider);
    expect(state.image?.path, '/tmp/a.png');
    expect(state.currentTool, EditorTool.brush);
  });

  test('selectTool 切换当前工具，不影响图片', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editorProvider.notifier).setImage(XFile('/tmp/a.png'));

    container.read(editorProvider.notifier).selectTool(EditorTool.eraser);

    final state = container.read(editorProvider);
    expect(state.currentTool, EditorTool.eraser);
    expect(state.image?.path, '/tmp/a.png');
  });

  test('涂抹与橡皮擦的粗细默认值互不影响', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(editorProvider.notifier);
    expect(container.read(editorProvider).brushSize, kDefaultBrushWidth);
    expect(container.read(editorProvider).eraserSize, kDefaultEraserWidth);

    notifier.setBrushSize(48);

    final state = container.read(editorProvider);
    expect(state.brushSize, 48);
    expect(state.eraserSize, kDefaultEraserWidth);
  });

  test('粗细设置限制在允许范围内', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(editorProvider.notifier);

    notifier.setBrushSize(1);
    expect(container.read(editorProvider).brushSize, kMinStrokeWidth);

    notifier.setEraserSize(999);
    expect(container.read(editorProvider).eraserSize, kMaxStrokeWidth);
  });

  test('切图与删图都保留粗细设置', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(editorProvider.notifier);

    notifier
      ..setBrushSize(40)
      ..setEraserSize(56)
      ..setImage(XFile('/tmp/a.png'));

    expect(container.read(editorProvider).brushSize, 40);
    expect(container.read(editorProvider).eraserSize, 56);

    notifier.clearImage();

    expect(container.read(editorProvider).brushSize, 40);
    expect(container.read(editorProvider).eraserSize, 56);
  });
}
