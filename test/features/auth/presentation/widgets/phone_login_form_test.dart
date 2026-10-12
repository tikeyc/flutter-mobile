import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/presentation/widgets/phone_login_form.dart';

import '../../../../helpers/auth_test_host.dart';
import '../../../../helpers/fake_auth_repository.dart';

void main() {
  late AuthTestHost host;
  setUp(() => host = AuthTestHost());

  Future<void> pumpForm(WidgetTester tester, {bool agreed = true}) => host.pump(
        tester,
        AgreedHolder(
          initial: agreed,
          builder: (a, on) => PhoneLoginForm(agreed: a, onAgreedChanged: on),
        ),
      );

  Future<void> sendCode(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('phone-input')), '13800000000');
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await settle(tester);
  }

  Future<void> enterCodeAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('code-input')), '1234');
    await tester.pump();
    await tester.tap(find.text('立即登录'));
    await settle(tester);
  }

  testWidgets('手机号不合法时不弹滑块', (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.byKey(const Key('phone-input')), '123');
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(host.verifyUsers, isEmpty);
  });

  testWidgets('获取验证码：滑块 → sendSms → 60s 倒计时', (tester) async {
    await pumpForm(tester);
    await sendCode(tester);
    expect(host.verifyUsers, ['13800000000']);
    expect(host.repo.smsCalls.single.loginSlide, 'slide-ok');
    expect(find.text('60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s'), findsOneWidget);
  });

  testWidgets('关闭滑块时不发短信', (tester) async {
    host.verifyResult = null;
    await pumpForm(tester);
    await sendCode(tester);
    expect(host.repo.smsCalls, isEmpty);
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('完整登录：用 sendSms 返回的 loginSlide', (tester) async {
    await pumpForm(tester);
    await sendCode(tester);
    await enterCodeAndSubmit(tester);
    final call = host.repo.loginCalls.single;
    expect((call.user, call.secret, call.loginSlide), ('13800000000', '1234', 'slide-ok'));
    final c = host.container(tester, find.byType(PhoneLoginForm));
    expect(c.read(authProvider)?.account, '13800000000');
    expect(host.storage.value?.token, 'tk-fake');
  });

  testWidgets('未勾选协议时提示', (tester) async {
    await pumpForm(tester, agreed: false);
    await sendCode(tester);
    await enterCodeAndSubmit(tester);
    expect(find.text('请先同意用户协议'), findsOneWidget);
    expect(host.repo.loginCalls, isEmpty);
  });

  testWidgets('未发码就登录时提示', (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.byKey(const Key('phone-input')), '13800000000');
    await enterCodeAndSubmit(tester);
    expect(find.text('请先获取验证码'), findsOneWidget);
    expect(host.repo.loginCalls, isEmpty);
  });

  testWidgets('302 弹"账号已被冻结"对话框', (tester) async {
    host.repo.loginError = apiError(302, '冻结至 2026-12-01');
    await pumpForm(tester);
    await sendCode(tester);
    await enterCodeAndSubmit(tester);
    expect(find.text('账号已被冻结'), findsOneWidget);
  });
}
