import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/data/models/slide_challenge.dart';
import 'package:intuly/features/auth/presentation/slide_captcha/slide_captcha_dialog.dart';

import '../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  String? result;
  var closed = false;

  setUp(() {
    repo = FakeAuthRepository();
    result = null;
    closed = false;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSlideCaptcha(context, '13800000000');
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> dragKnob(WidgetTester tester, double dx) async {
    await tester.drag(find.byKey(const Key('slide-knob')), Offset(dx, 0));
    await tester.pump(); // 触发 onHorizontalDragEnd → checkSlide
    await tester.pump(); // 等 checkSlide 的 Future 完成
  }

  testWidgets('加载成功显示提示语，并用 loginUser 拉取滑块', (tester) async {
    await open(tester);
    expect(find.text('请拖动滑块完成拼图'), findsOneWidget);
    expect(repo.fetchUsers, ['13800000000']);
  });

  testWidgets('拖动后提交换算后的 moveWidth，通过则返回 loginSlide', (tester) async {
    await open(tester);
    await dragKnob(tester, 100);
    await tester.pumpAndSettle();
    // 渲染宽 297、原图 594 → scale 0.5；手势 slop 会吃掉少量位移
    expect(repo.checkedMoveWidths.single, closeTo(200, 40));
    expect(closed, isTrue);
    expect(result, 'slide-ok');
  });

  testWidgets('未通过：显示"未对准，请重试"，1 秒后复位，弹窗不关闭', (tester) async {
    repo.checkResults.add(const SlideCheckResult(passed: false, errorCount: 1));
    await open(tester);
    await dragKnob(tester, 100);
    expect(find.text('未对准，请重试'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('请拖动滑块完成拼图'), findsOneWidget);
    expect(closed, isFalse);
    expect(repo.fetchCount, 1);
  });

  testWidgets('errorCnt >= 3：1 秒后重新拉取滑块', (tester) async {
    repo.checkResults.add(const SlideCheckResult(passed: false, errorCount: 3));
    await open(tester);
    await dragKnob(tester, 100);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.fetchCount, 2);
    expect(find.text('请拖动滑块完成拼图'), findsOneWidget);
  });

  testWidgets('加载失败显示错误和"重试"，重试成功后恢复', (tester) async {
    repo.fetchError = apiError(500, '获取滑块失败，请重试');
    await open(tester);
    expect(find.text('获取滑块失败，请重试'), findsOneWidget);
    repo.fetchError = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('请拖动滑块完成拼图'), findsOneWidget);
  });

  testWidgets('点击蒙层关闭，返回 null', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
