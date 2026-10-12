import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/features/auth/presentation/widgets/login_error_handler.dart';
import 'package:intuly/features/auth/presentation/widgets/login_widgets.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('AgreementRow 点复选框回调取反值，并显示协议文案', (tester) async {
    bool? changed;
    await tester.pumpWidget(host(AgreementRow(agreed: false, onChanged: (v) => changed = v)));
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    expect(changed, isTrue);
    expect(find.textContaining('《用户服务协议》', findRichText: true), findsOneWidget);
    expect(find.textContaining('《隐私政策》', findRichText: true), findsOneWidget);
  });

  testWidgets('PrimaryLoginButton 禁用时不触发', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        host(PrimaryLoginButton(enabled: false, loading: false, onPressed: () => taps++)));
    await tester.tap(find.text('立即登录'));
    expect(taps, 0);
  });

  testWidgets('PrimaryLoginButton loading 时显示进度且不触发', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        host(PrimaryLoginButton(enabled: true, loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(PrimaryLoginButton));
    expect(taps, 0);
  });

  Future<void> trigger(WidgetTester tester, ApiException e) async {
    await tester.pumpWidget(host(Builder(
      builder: (context) =>
          TextButton(onPressed: () => showLoginError(context, e), child: const Text('go')),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('302 弹"账号已被冻结"对话框并展示服务端消息', (tester) async {
    await trigger(tester, const ApiException(status: 302, message: '冻结至 2026-12-01'));
    expect(find.text('账号已被冻结'), findsOneWidget);
    expect(find.text('冻结至 2026-12-01'), findsOneWidget);
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('301 不展示服务端消息', (tester) async {
    await trigger(tester, const ApiException(status: 301, message: 'internal'));
    expect(find.text('账号已被封禁'), findsOneWidget);
    expect(find.text('internal'), findsNothing);
  });

  testWidgets('普通错误弹 toast', (tester) async {
    await trigger(tester, const ApiException(status: 500, message: '网络错误，请稍后重试'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('网络错误，请稍后重试'), findsOneWidget);
  });
}
