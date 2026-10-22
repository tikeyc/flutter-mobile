import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';

void main() {
  test('初始状态无图片，默认工具为涂抹', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(editorProvider);

    expect(state.imagePath, isNull);
    expect(state.currentTool, EditorTool.brush);
  });

  test('setImage 更新图片路径，不影响当前工具', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(editorProvider.notifier).setImage('/tmp/a.png');

    final state = container.read(editorProvider);
    expect(state.imagePath, '/tmp/a.png');
    expect(state.currentTool, EditorTool.brush);
  });

  test('selectTool 切换当前工具，不影响图片', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editorProvider.notifier).setImage('/tmp/a.png');

    container.read(editorProvider.notifier).selectTool(EditorTool.eraser);

    final state = container.read(editorProvider);
    expect(state.currentTool, EditorTool.eraser);
    expect(state.imagePath, '/tmp/a.png');
  });
}
