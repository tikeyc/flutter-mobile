import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/app.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/data/models/session.dart';
import 'package:intuly/features/auth/presentation/slide_captcha/slide_captcha_dialog.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/in_memory_session_storage.dart';

void main() {
  late InMemorySessionStorage storage;
  late FakeAuthRepository repo;

  setUp(() {
    storage = InMemorySessionStorage();
    repo = FakeAuthRepository();
  });

  Future<void> pumpApp(WidgetTester tester, {Session? initial}) async {
    storage.value = initial;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialSessionProvider.overrideWithValue(initial),
        sessionStorageProvider.overrideWithValue(storage),
        authRepoProvider.overrideWithValue(repo),
        slideVerifierProvider.overrideWithValue((_, _) async => 'slide-ok'),
      ],
      child: const IntulyApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('无会话时进入登录页', (tester) async {
    await pumpApp(tester);
    expect(find.text('登录/注册'), findsOneWidget);
  });

  testWidgets('有会话时进入首页，退出后回到登录页', (tester) async {
    await pumpApp(tester, initial: const Session(token: 'abcdefghijklmnop', account: 'alice'));
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Token: abcdefghij…'), findsOneWidget);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('登录/注册'), findsOneWidget);
    expect(storage.value, isNull);
  });

  testWidgets('账号登录成功后自动跳到首页', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('账号登录'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('account-input')), 'bob');
    await tester.enterText(find.byKey(const Key('password-input')), 'pw');
    await tester.tap(find.byKey(const Key('agreement-checkbox')).hitTestable());
    await tester.pump();
    await tester.tap(find.text('立即登录').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    expect(storage.value?.account, 'bob');
  });
}
