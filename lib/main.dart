import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/observers/provider_logger_observer.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SecureSessionStorage(const FlutterSecureStorage());
  // 启动前读出会话，路由首帧就能决定去登录页还是首页，避免闪屏。
  // read() 内部已兜底：存储损坏时返回 null，按未登录处理。
  final session = await storage.read();
  runApp(ProviderScope(
    observers: [ProviderLoggerObserver()],
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      initialSessionProvider.overrideWithValue(session),
    ],
    child: const IntulyApp(),
  ));
}
