import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/presentation/login_page.dart';
import 'package:intuly/features/auth/presentation/widgets/login_widgets.dart';

import '../../../helpers/auth_test_host.dart';

void main() {
  late AuthTestHost host;
  setUp(() => host = AuthTestHost());

  Future<void> pumpPage(WidgetTester tester) =>
      host.pump(tester, const LoginPage(), scroll: false);

  testWidgets('默认显示手机号登录', (tester) async {
    await pumpPage(tester);
    expect(find.text('登录/注册'), findsOneWidget);
    expect(find.text('未注册手机号将自动注册'), findsOneWidget);
    expect(find.text('请输入账号'), findsNothing);
  });

  testWidgets('切到账号登录', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('账号登录'));
    await tester.pump();
    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('未注册手机号将自动注册'), findsNothing);
  });

  testWidgets('协议勾选状态跨 Tab 保持', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.text('账号登录'));
    await tester.pump();
    expect(tester.widget<AgreementRow>(find.byType(AgreementRow)).agreed, isTrue);
  });

  testWidgets('作为根页面时不显示关闭按钮', (tester) async {
    await pumpPage(tester);
    expect(find.byTooltip('关闭'), findsNothing);
  });
}
