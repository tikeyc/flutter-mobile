import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_client.dart';
import '../data/auth_repository.dart';
import '../data/models/session.dart';
import '../data/session_storage.dart';

/// 启动时读到的会话。main() 读取存储后 override，避免启动闪屏。
final initialSessionProvider = Provider<Session?>((ref) => null);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(const FlutterSecureStorage()),
);

/// 测试注入 FakeHttpAdapter；生产为 null（用 Dio 默认适配器）。
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// 回调里惰性 read authProvider，构建期不 watch，避免循环依赖。
final dioProvider = Provider<Dio>((ref) {
  return createDio(
    readToken: () => ref.read(authProvider)?.token,
    onUnauthorized: () {
      if (ref.read(authProvider) != null) {
        unawaited(ref.read(authProvider.notifier).signOut());
      }
    },
    adapter: ref.watch(httpClientAdapterProvider),
  );
});

final authRepoProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(ref.watch(dioProvider)),
);

final authProvider = NotifierProvider<AuthNotifier, Session?>(AuthNotifier.new);

/// 当前会话；null 表示未登录。
class AuthNotifier extends Notifier<Session?> {
  @override
  Session? build() => ref.read(initialSessionProvider);

  Future<void> loginWithPhone(String phone, String code, String loginSlide) async {
    final token = await ref
        .read(authRepoProvider)
        .loginWithPhone(phone: phone, code: code, loginSlide: loginSlide);
    await _save(Session(token: token, account: phone));
  }

  Future<void> loginWithPassword(String account, String password, String loginSlide) async {
    final token = await ref
        .read(authRepoProvider)
        .loginWithPassword(account: account, password: password, loginSlide: loginSlide);
    await _save(Session(token: token, account: account));
  }

  Future<void> signOut() async {
    state = null;
    await ref.read(sessionStorageProvider).delete();
  }

  Future<void> _save(Session session) async {
    await ref.read(sessionStorageProvider).write(session);
    state = session;
  }
}
