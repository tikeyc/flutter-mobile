import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/presentation/widgets/account_login_form.dart';

import '../../../../helpers/auth_test_host.dart';
import '../../../../helpers/fake_auth_repository.dart';

void main() {
  late AuthTestHost host;
  setUp(() => host = AuthTestHost());

  Future<void> pumpForm(WidgetTester tester, {bool agreed = true}) => host.pump(
        tester,
        AgreedHolder(
          initial: agreed,
          builder: (a, on) => AccountLoginForm(agreed: a, onAgreedChanged: on),
        ),
      );

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('account-input')), 'alice');
    await tester.enterText(find.byKey(const Key('password-input')), 'secret');
    await tester.pump();
    await tester.tap(find.text('立即登录'));
    await settle(tester);
  }

  TextField passwordField(WidgetTester tester) => tester.widget<TextField>(find.descendant(
      of: find.byKey(const Key('password-input')), matching: find.byType(TextField)));

  testWidgets('字段为空时点登录不触发滑块', (tester) async {
    await pumpForm(tester);
    await tester.tap(find.text('立即登录'));
    await tester.pump();
    expect(host.verifyUsers, isEmpty);
  });

  testWidgets('登录成功：先滑块再 loginWithPassword', (tester) async {
    await pumpForm(tester);
    await fillAndSubmit(tester);
    expect(host.verifyUsers, ['alice']);
    final call = host.repo.loginCalls.single;
    expect((call.user, call.secret, call.loginSlide), ('alice', 'secret', 'slide-ok'));
    final c = host.container(tester, find.byType(AccountLoginForm));
    expect(c.read(authProvider)?.account, 'alice');
  });

  testWidgets('关闭滑块时不登录', (tester) async {
    host.verifyResult = null;
    await pumpForm(tester);
    await fillAndSubmit(tester);
    expect(host.repo.loginCalls, isEmpty);
  });

  testWidgets('未勾选协议时提示且不弹滑块', (tester) async {
    await pumpForm(tester, agreed: false);
    await fillAndSubmit(tester);
    expect(find.text('请先同意用户协议'), findsOneWidget);
    expect(host.verifyUsers, isEmpty);
  });

  testWidgets('403 显示内联错误，编辑后清除', (tester) async {
    host.repo.loginError = apiError(403, '账号或密码错误');
    await pumpForm(tester);
    await fillAndSubmit(tester);
    expect(find.text('账号或密码错误'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('password-input')), 'secret2');
    await tester.pump();
    expect(find.text('账号或密码错误'), findsNothing);
  });

  testWidgets('眼睛图标切换密码明文', (tester) async {
    await pumpForm(tester);
    expect(passwordField(tester).obscureText, isTrue);
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    expect(passwordField(tester).obscureText, isFalse);
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
  });
}
