import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/app.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/data/models/session.dart';
import 'package:intuly/features/auth/presentation/slide_captcha/slide_captcha_dialog.dart';
import 'package:intuly/router/app_router.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/in_memory_session_storage.dart';

void main() {
  late InMemorySessionStorage storage;
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    storage = InMemorySessionStorage();
    repo = FakeAuthRepository();
  });

  Future<void> pumpApp(WidgetTester tester, {Session? initial}) async {
    storage.value = initial;
    container = ProviderContainer(
      overrides: [
        initialSessionProvider.overrideWithValue(initial),
        sessionStorageProvider.overrideWithValue(storage),
        authRepoProvider.overrideWithValue(repo),
        slideVerifierProvider.overrideWithValue((_, _) async => 'slide-ok'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const IntulyApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('无会话时游客进入首页浏览', (tester) async {
    await pumpApp(tester);
    expect(find.text('话题'), findsOneWidget);
    expect(find.text('灵感社区'), findsOneWidget);
  });

  testWidgets('游客可打开登录页', (tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(find.text('登录/注册'), findsOneWidget);
  });

  testWidgets('有会话时进入首页，退出后保持游客浏览', (tester) async {
    await pumpApp(tester,
        initial: const Session(token: 'abcdefghijklmnop', account: 'alice'));
    expect(find.text('话题'), findsOneWidget);
    expect(find.text('灵感社区'), findsOneWidget);

    // 点击底部导航中央头像按钮退出登录。
    await tester.tap(find.byKey(const Key('home-center-button')));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    // 游客态仍停留在首页浏览。
    expect(find.text('话题'), findsOneWidget);
  });

  testWidgets('账号登录成功后自动跳到首页', (tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();

    await tester.tap(find.text('账号登录'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('account-input')), 'bob');
    await tester.enterText(find.byKey(const Key('password-input')), 'pw');
    await tester.tap(find.byKey(const Key('agreement-checkbox')).hitTestable());
    await tester.pump();
    await tester.tap(find.text('立即登录').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('话题'), findsOneWidget);
    expect(storage.value?.account, 'bob');
  });
}
