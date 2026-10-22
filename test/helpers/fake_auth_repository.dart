import 'package:dio/dio.dart' show CancelToken;
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/features/auth/data/auth_repository.dart';
import 'package:intuly/features/auth/data/models/slide_challenge.dart';

import 'test_images.dart';

/// 测试用假仓库：记录调用，可预设结果和错误。
class FakeAuthRepository implements AuthRepository {
  int fetchCount = 0;
  final List<String> fetchUsers = [];
  final List<int> checkedMoveWidths = [];
  final List<({String phone, String loginSlide})> smsCalls = [];
  final List<({String user, String secret, String loginSlide})> loginCalls = [];

  /// 依次消费的滑块校验结果；为空时默认通过。
  final List<SlideCheckResult> checkResults = [];
  Object? fetchError;
  Object? loginError;
  String token = 'tk-fake';

  @override
  Future<SlideChallenge> fetchSlide(String loginUser, {CancelToken? cancelToken}) async {
    fetchCount++;
    fetchUsers.add(loginUser);
    if (fetchError != null) throw fetchError!;
    return SlideChallenge.fromJson(slideJson());
  }

  @override
  Future<SlideCheckResult> checkSlide({
    required String loginUser,
    required String captchaId,
    required int moveWidth,
    CancelToken? cancelToken,
  }) async {
    checkedMoveWidths.add(moveWidth);
    return checkResults.isEmpty
        ? const SlideCheckResult(passed: true, loginSlide: 'slide-ok')
        : checkResults.removeAt(0);
  }

  @override
  Future<String> sendSms({required String phone, required String loginSlide}) async {
    smsCalls.add((phone: phone, loginSlide: loginSlide));
    return loginSlide;
  }

  @override
  Future<String> loginWithPhone({
    required String phone,
    required String code,
    required String loginSlide,
  }) =>
      _login(phone, code, loginSlide);

  @override
  Future<String> loginWithPassword({
    required String account,
    required String password,
    required String loginSlide,
  }) =>
      _login(account, password, loginSlide);

  Future<String> _login(String user, String secret, String loginSlide) async {
    loginCalls.add((user: user, secret: secret, loginSlide: loginSlide));
    if (loginError != null) throw loginError!;
    return token;
  }
}

ApiException apiError(int status, [String message = 'err']) =>
    ApiException(status: status, message: message);
