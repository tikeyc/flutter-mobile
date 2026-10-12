import 'package:intuly/features/auth/data/models/session.dart';
import 'package:intuly/features/auth/data/session_storage.dart';

/// 测试用内存会话存储。value 公开，便于预置和断言。
class InMemorySessionStorage implements SessionStorage {
  Session? value;
  InMemorySessionStorage([this.value]);

  @override
  Future<Session?> read() async => value;

  @override
  Future<void> write(Session session) async => value = session;

  @override
  Future<void> delete() async => value = null;
}
