import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/theme/app_colors.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/presentation/widgets/editor_toolbar.dart';

Future<void> pumpToolbar(
  WidgetTester tester, {
  EditorTool selected = EditorTool.brush,
  ValueChanged<EditorTool>? onToolSelected,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorToolbar(
          selectedTool: selected,
          onToolSelected: onToolSelected ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('渲染四个工具与撤销/重做/重置按钮', (tester) async {
    await pumpToolbar(tester);
    await tester.pumpAndSettle();

    for (final label in ['涂抹', '智能点选', '自动抠图', '橡皮擦']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选中的工具以主色高亮，其余为灰色', (tester) async {
    await pumpToolbar(tester, selected: EditorTool.eraser);
    await tester.pumpAndSettle();

    Text textOf(String label) => tester.widget<Text>(find.text(label));

    expect(textOf('橡皮擦').style?.color, AppColors.primary);
    expect(textOf('涂抹').style?.color, AppColors.text2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击工具触发 onToolSelected 回调', (tester) async {
    final picked = <EditorTool>[];
    await pumpToolbar(tester, onToolSelected: picked.add);
    await tester.pumpAndSettle();

    await tester.tap(find.text('智能点选'));

    expect(picked, [EditorTool.smartSelect]);
  });
}
