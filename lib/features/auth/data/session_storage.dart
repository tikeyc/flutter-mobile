import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/session.dart';

abstract class SessionStorage {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> delete();
}

class SecureSessionStorage implements SessionStorage {
  static const _key = 'intuly_session';
  final FlutterSecureStorage _storage;

  SecureSessionStorage(this._storage);

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Session.fromJson(json);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _key);
  }
}
