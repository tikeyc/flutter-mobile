import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/features/auth/application/auth_providers.dart';
import 'package:intuly/features/auth/data/models/session.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/in_memory_session_storage.dart';

void main() {
  late InMemorySessionStorage storage;
  late FakeAuthRepository repo;

  ProviderContainer makeContainer({Session? initial, FakeHttpAdapter? adapter}) {
    final c = ProviderContainer(overrides: [
      initialSessionProvider.overrideWithValue(initial),
      sessionStorageProvider.overrideWithValue(storage),
      if (adapter == null) authRepoProvider.overrideWithValue(repo),
      if (adapter != null) httpClientAdapterProvider.overrideWithValue(adapter),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    storage = InMemorySessionStorage();
    repo = FakeAuthRepository();
  });

  test('初始状态取 initialSessionProvider', () {
    final c = makeContainer(initial: const Session(token: 't0', account: 'a0'));
    expect(c.read(authProvider)?.account, 'a0');
  });

  test('手机号登录成功：写入存储并更新状态', () async {
    final c = makeContainer();
    await c.read(authProvider.notifier).loginWithPhone('13800000000', '1234', 'ls');
    expect(c.read(authProvider)?.token, 'tk-fake');
    expect(c.read(authProvider)?.account, '13800000000');
    expect(storage.value?.token, 'tk-fake');
    expect(repo.loginCalls.single.loginSlide, 'ls');
  });

  test('账号登录失败：抛出异常，状态和存储保持为空', () async {
    repo.loginError = apiError(403);
    final c = makeContainer();
    await expectLater(
      c.read(authProvider.notifier).loginWithPassword('a', 'b', 'ls'),
      throwsA(isA<ApiException>()),
    );
    expect(c.read(authProvider), isNull);
    expect(storage.value, isNull);
  });

  test('signOut 清空存储和状态', () async {
    storage.value = const Session(token: 't', account: 'a');
    final c = makeContainer(initial: storage.value);
    await c.read(authProvider.notifier).signOut();
    expect(c.read(authProvider), isNull);
    expect(storage.value, isNull);
  });

  test('接口返回 401 时自动 signOut', () async {
    final adapter = FakeHttpAdapter()..on('/test', body: {'status': 401});
    storage.value = const Session(token: 't', account: 'a');
    final c = makeContainer(initial: storage.value, adapter: adapter);
    await expectLater(c.read(dioProvider).post<Object?>('/test'), throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests.single.headers['Authorization'], 'Bearer t');
    expect(c.read(authProvider), isNull);
    expect(storage.value, isNull);
  });
}
