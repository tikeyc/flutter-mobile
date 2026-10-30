import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/editor/application/editor_providers.dart';
import 'package:intuly/features/editor/presentation/widgets/brush_size_bar.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  double size = kDefaultBrushWidth,
  bool isEraser = false,
  ValueChanged<double>? onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: BrushSizeBar(
            size: size,
            isEraser: isEraser,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('滑块显示当前笔宽，范围限制在 4~64', (tester) async {
    await pumpBar(tester, size: 40);
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byKey(const Key('brush-size-slider')));
    expect(slider.value, 40);
    expect(slider.min, kMinStrokeWidth);
    expect(slider.max, kMaxStrokeWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('超出范围的笔宽被收进滑块范围', (tester) async {
    await pumpBar(tester, size: 999);
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byKey(const Key('brush-size-slider')));
    expect(slider.value, kMaxStrokeWidth);
  });

  testWidgets('拖动滑块回调新的笔宽', (tester) async {
    final values = <double>[];
    await pumpBar(tester, onChanged: values.add);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('brush-size-slider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    expect(values, isNotEmpty);
    expect(values.last, greaterThan(kDefaultBrushWidth));
  });

  testWidgets('涂抹用实心圆预览，橡皮擦用空心圆预览', (tester) async {
    await pumpBar(tester);
    await tester.pumpAndSettle();
    BoxDecoration decoration() => tester
        .widget<Container>(find.byKey(const Key('brush-size-preview')))
        .decoration! as BoxDecoration;

    expect(decoration().border, isNull);

    await pumpBar(tester, isEraser: true);
    await tester.pumpAndSettle();

    expect(decoration().border, isNotNull);
  });
}
